import Foundation
import WorkoutDomain

/// SQLite v1/v2-compatible adapter. Every mutation, audit entry and receipt commits atomically.
public final class SqliteProgramLogRepository: ProgramLogRepository, Sendable {
  private let db: SQLiteDatabase
  public init(path: String) throws {
    db = try SQLiteDatabase(path: path)
    do {
      try db.execute("PRAGMA synchronous = FULL")
      guard try db.rows("PRAGMA foreign_keys").first?["foreign_keys"]?.int == 1 else {
        throw LoggingException("foreign_keys_required")
      }
      try db.transaction {
        guard let version = try db.rows("PRAGMA user_version").first?["user_version"]?.int,
          (0...2).contains(version)
        else {
          throw LoggingException("unsupported_schema")
        }
        if version == 0 {
          try Self.createDeletions(db)
          try db.execute(
            "CREATE TABLE logs(profile TEXT NOT NULL,id TEXT NOT NULL,revision INTEGER NOT NULL,completed INTEGER NOT NULL,payload TEXT NOT NULL,prescription TEXT NOT NULL,PRIMARY KEY(profile,id))"
          )
          try db.execute("CREATE UNIQUE INDEX one_program_draft ON logs(profile) WHERE completed=0")
          try db.execute(
            "CREATE TABLE receipts(profile TEXT NOT NULL,action TEXT NOT NULL,payload TEXT NOT NULL,PRIMARY KEY(profile,action))"
          )
          try db.execute(
            "CREATE TABLE revisions(profile TEXT NOT NULL,id TEXT NOT NULL,revision INTEGER NOT NULL,payload TEXT NOT NULL,PRIMARY KEY(profile,id,revision),FOREIGN KEY(profile,id) REFERENCES logs(profile,id))"
          )
        } else if version == 1 {
          try Self.createDeletions(db)
        }
        try db.execute("PRAGMA user_version = 2")
      }
    } catch {
      try? db.close()
      throw error
    }
  }
  private static func createDeletions(_ db: SQLiteDatabase) throws {
    try db.execute(
      "CREATE TABLE deletions(profile TEXT NOT NULL,id TEXT NOT NULL,action TEXT NOT NULL,revision INTEGER NOT NULL,PRIMARY KEY(profile,id),UNIQUE(profile,action))"
    )
  }
  public func load(_ profile: String) throws -> [ProgramLog] {
    try validateStorageId(profile)
    let rows = try db.rows("SELECT * FROM logs WHERE profile=?", [.text(profile)])
    return try rows.map { row in
      guard let payload = row["payload"]?.string else { throw LoggingException("invalid_session") }
      let log = try ProgramLog(jsonString: payload)
      guard log.profile == profile else { throw LoggingException("profile_mismatch") }
      guard row["id"]?.string == log.id, row["revision"]?.int == log.revision,
        row["completed"]?.int == (log.completed ? 1 : 0)
      else { throw LoggingException("invalid_session") }
      guard
        row["prescription"]?.string.map({ ManualJSON.bytesEqual($0, log.prescriptionJSON()) })
          == true
      else { throw LoggingException("unsupported_prescription") }
      return log
    }.sorted { a, b in
      a.startedTimestamp.microsecondsSince1970 == b.startedTimestamp.microsecondsSince1970
        ? a.id > b.id
        : a.startedTimestamp.microsecondsSince1970 > b.startedTimestamp.microsecondsSince1970
    }
  }
  public func write(_ log: ProgramLog, expectedRevision: Int, actionId: String) throws {
    try validateStorageId(actionId)
    try log.validate()
    let payload = log.encodedJSON()
    let receipt = ManualJSON.object([
      ("expected", String(expectedRevision)), ("payload", ManualJSON.string(payload)),
    ])
    try db.transaction {
      let deleted = try db.rows(
        "SELECT * FROM deletions WHERE profile=? AND (id=? OR action=?)",
        [.text(log.profile), .text(log.id), .text(actionId)])
      guard deleted.isEmpty else { throw LoggingException("deleted_workout") }
      let receipts = try db.rows(
        "SELECT * FROM receipts WHERE profile=? AND action=?",
        [.text(log.profile), .text(actionId)])
      if let saved = receipts.first {
        guard saved["payload"]?.string.map({ ManualJSON.bytesEqual($0, receipt) }) == true else {
          throw LoggingException("action_conflict")
        }
        return
      }
      let rows = try db.rows(
        "SELECT * FROM logs WHERE profile=? AND id=?", [.text(log.profile), .text(log.id)])
      if let row = rows.first {
        guard let oldPayload = row["payload"]?.string else {
          throw LoggingException("invalid_session")
        }
        let old = try ProgramLog(jsonString: oldPayload)
        guard old.profile == log.profile, old.id == log.id,
          row["revision"]?.int == old.revision, row["completed"]?.int == (old.completed ? 1 : 0),
          row["prescription"]?.string.map({ ManualJSON.bytesEqual($0, old.prescriptionJSON()) })
            == true
        else { throw LoggingException("invalid_session") }
        guard expectedRevision >= 0, expectedRevision < Int.max,
          old.revision == expectedRevision, log.revision == expectedRevision + 1,
          old.programId == log.programId, old.programVersion == log.programVersion,
          old.startedTimestamp == log.startedTimestamp
        else { throw LoggingException("stale_or_invalid_revision") }
        var expected: ProgramLog?
        if !old.completed && log.completed && log.sets.count == old.sets.count,
          let timestamp = log.completedTimestamp
        {
          expected = try old.finish(timestamp: timestamp, endEarly: log.endedEarly)
        } else {
          let changed = log.sets.filter { !old.sets.contains($0) }
          if changed.count == 1 { expected = try old.record(changed[0]) }
          if changed.isEmpty, let last = log.sets.last { expected = try old.record(last) }
        }
        guard expected.map({ ManualJSON.bytesEqual($0.encodedJSON(), payload) }) == true else {
          throw LoggingException("invalid_transition")
        }
        try db.execute(
          "INSERT INTO revisions(profile,id,revision,payload) VALUES(?,?,?,?)",
          [
            .text(log.profile), .text(log.id), .integer(Int64(old.revision)), .text(oldPayload),
          ])
        try db.execute(
          "UPDATE logs SET revision=?,completed=?,payload=? WHERE profile=? AND id=?",
          [
            .integer(Int64(log.revision)), .integer(log.completed ? 1 : 0), .text(payload),
            .text(log.profile), .text(log.id),
          ])
      } else {
        guard expectedRevision == -1, log.revision == 0, log.sets.isEmpty, !log.completed else {
          throw LoggingException("invalid_start")
        }
        try db.execute(
          "INSERT INTO logs(profile,id,revision,completed,payload,prescription) VALUES(?,?,0,0,?,?)",
          [
            .text(log.profile), .text(log.id), .text(payload), .text(log.prescriptionJSON()),
          ])
      }
      try db.execute(
        "INSERT INTO receipts(profile,action,payload) VALUES(?,?,?)",
        [.text(log.profile), .text(actionId), .text(receipt)])
    }
  }
  public func delete(_ profile: String, id: String, expectedRevision: Int, actionId: String) throws
  {
    try validateStorageId(profile)
    try validateStorageId(id)
    try validateStorageId(actionId)
    guard expectedRevision >= 0 else { throw LoggingException("invalid_revision") }
    try db.transaction {
      let deleted = try db.rows(
        "SELECT * FROM deletions WHERE profile=? AND (id=? OR action=?)",
        [.text(profile), .text(id), .text(actionId)])
      if !deleted.isEmpty {
        guard deleted.count == 1, deleted[0]["id"]?.string == id,
          deleted[0]["action"]?.string == actionId,
          deleted[0]["revision"]?.int == expectedRevision
        else { throw LoggingException("action_conflict") }
        return
      }
      let receipts = try db.rows("SELECT * FROM receipts WHERE profile=?", [.text(profile)])
      guard !receipts.contains(where: { $0["action"]?.string == actionId }) else {
        throw LoggingException("action_conflict")
      }
      let rows = try db.rows(
        "SELECT * FROM logs WHERE profile=? AND id=?", [.text(profile), .text(id)])
      guard rows.count == 1, rows[0]["revision"]?.int == expectedRevision else {
        throw LoggingException("stale_or_missing_workout")
      }
      // Decode inside the transaction: a malformed receipt must roll back all removal.
      for receipt in receipts {
        guard let text = receipt["payload"]?.string, let action = receipt["action"]?.string else {
          throw LoggingException("invalid_receipt")
        }
        let request = try ManualJSON.decode(text)
        let log = try ManualJSON.decode(ManualJSON.text(request, "payload"))
        guard (try ManualJSON.text(log, "profile")) == profile else {
          throw LoggingException("invalid_receipt")
        }
        if try ManualJSON.text(log, "id") == id {
          try db.execute(
            "DELETE FROM receipts WHERE profile=? AND action=?", [.text(profile), .text(action)])
        }
      }
      try db.execute("DELETE FROM revisions WHERE profile=? AND id=?", [.text(profile), .text(id)])
      try db.execute("DELETE FROM logs WHERE profile=? AND id=?", [.text(profile), .text(id)])
      try db.execute(
        "INSERT INTO deletions(profile,id,action,revision) VALUES(?,?,?,?)",
        [
          .text(profile), .text(id), .text(actionId), .integer(Int64(expectedRevision)),
        ])
    }
  }
  public func close() throws { try db.close() }
}
