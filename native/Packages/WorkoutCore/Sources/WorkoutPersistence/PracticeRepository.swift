import Foundation
import WorkoutDomain

public final class SqlitePracticeRepository: PracticeRepository {
  private let db: SQLiteDatabase
  public init(path: String) throws {
    db = try SQLiteDatabase(path: path)
    try db.execute("PRAGMA foreign_keys=ON")
    try db.execute("PRAGMA synchronous=FULL")
    guard try db.rows("PRAGMA foreign_keys").first?["foreign_keys"]?.int == 1 else {
      throw LoggingException(code: "foreign_keys_required")
    }
    let version = try db.rows("PRAGMA user_version").first?["user_version"]?.int ?? -1
    guard version == 0 || version == 1 else { throw LoggingException(code: "unsupported_schema") }
    if version == 0 {
      try db.transaction {
        try db.execute("CREATE TABLE profiles (id TEXT PRIMARY KEY NOT NULL)")
        try db.execute(
          "CREATE TABLE sessions (id TEXT NOT NULL, profile_id TEXT NOT NULL, started_at TEXT NOT NULL, completed_at TEXT, revision INTEGER NOT NULL DEFAULT 0 CHECK(revision >= 0), practice INTEGER NOT NULL DEFAULT 1 CHECK(practice = 1), PRIMARY KEY(profile_id, id), FOREIGN KEY(profile_id) REFERENCES profiles(id))"
        )
        try db.execute(
          "CREATE UNIQUE INDEX one_draft ON sessions(profile_id) WHERE completed_at IS NULL")
        try db.execute(
          "CREATE TABLE session_exercises (profile_id TEXT NOT NULL, session_id TEXT NOT NULL, exercise_id TEXT NOT NULL, ordinal INTEGER NOT NULL, target_json TEXT, PRIMARY KEY(profile_id, session_id, exercise_id), FOREIGN KEY(profile_id, session_id) REFERENCES sessions(profile_id, id))"
        )
        try db.execute(
          "CREATE TABLE set_records (profile_id TEXT NOT NULL, session_id TEXT NOT NULL, id TEXT NOT NULL, exercise_id TEXT NOT NULL, set_index INTEGER NOT NULL CHECK(set_index > 0), payload TEXT NOT NULL, PRIMARY KEY(profile_id, session_id, id), UNIQUE(profile_id, session_id, exercise_id, set_index), FOREIGN KEY(profile_id, session_id, exercise_id) REFERENCES session_exercises(profile_id, session_id, exercise_id))"
        )
        try db.execute(
          "CREATE TABLE set_revisions (profile_id TEXT NOT NULL, session_id TEXT NOT NULL, set_id TEXT NOT NULL, revision INTEGER NOT NULL, prior_payload TEXT NOT NULL, changed_at TEXT NOT NULL, PRIMARY KEY(profile_id, session_id, set_id, revision), FOREIGN KEY(profile_id, session_id, set_id) REFERENCES set_records(profile_id, session_id, id))"
        )
        try db.execute(
          "CREATE TABLE actions (profile_id TEXT NOT NULL, id TEXT NOT NULL, session_id TEXT NOT NULL, payload TEXT NOT NULL, resulting_revision INTEGER NOT NULL, PRIMARY KEY(profile_id, id), FOREIGN KEY(profile_id, session_id) REFERENCES sessions(profile_id, id))"
        )
        try db.execute("PRAGMA user_version=1")
      }
    }
  }
  private func validate(_ profileId: String, _ sessionId: String, _ actionId: String, _ at: Date)
    throws
  {
    for id in [profileId, sessionId, actionId] { try validateStorageId(id) }
    guard ManualTimestamp(at).isValid else { throw LoggingException(code: "invalid_action_time") }
  }
  private func replayed(_ profile: String, _ action: String, _ payload: String) throws -> Bool {
    guard
      let row = try db.rows(
        "SELECT payload FROM actions WHERE profile_id=? AND id=?", [.text(profile), .text(action)]
      ).first
    else { return false }
    guard row["payload"]?.string.map({ ManualJSON.bytesEqual($0, payload) }) == true else {
      throw LoggingException(code: "action_conflict")
    }
    return true
  }
  private func session(_ profile: String, _ session: String) throws -> [String: SQLValue] {
    guard
      let row = try db.rows(
        "SELECT * FROM sessions WHERE profile_id=? AND id=?", [.text(profile), .text(session)]
      ).first
    else { throw LoggingException(code: "session_not_found") }
    return row
  }
  private func receipt(
    _ profile: String, _ session: String, _ action: String, _ payload: String, _ revision: Int
  ) throws {
    try db.execute(
      "INSERT INTO actions(profile_id,session_id,id,payload,resulting_revision) VALUES(?,?,?,?,?)",
      [.text(profile), .text(session), .text(action), .text(payload), .integer(Int64(revision))])
  }
  public func start(profileId: String, sessionId: String, actionId: String, at: Date) throws {
    try validate(profileId, sessionId, actionId, at)
    let payload = ManualJSON.array([
      ManualJSON.string("start"), ManualJSON.string(sessionId),
      ManualJSON.string(dartISOString(at)),
    ])
    try db.transaction {
      if try replayed(profileId, actionId, payload) { return }
      try db.execute("INSERT OR IGNORE INTO profiles(id) VALUES(?)", [.text(profileId)])
      try db.execute(
        "INSERT INTO sessions(id,profile_id,started_at) VALUES(?,?,?)",
        [.text(sessionId), .text(profileId), .text(dartISOString(at))])
      for (ordinal, id) in ["practice_press", "practice_row"].enumerated() {
        try db.execute(
          "INSERT INTO session_exercises(profile_id,session_id,exercise_id,ordinal) VALUES(?,?,?,?)",
          [.text(profileId), .text(sessionId), .text(id), .integer(Int64(ordinal))])
      }
      try receipt(profileId, sessionId, actionId, payload, 0)
    }
  }
  public func saveSet(
    profileId: String, sessionId: String, actionId: String, expectedRevision: Int,
    record: PracticeSet, correction: Bool, at: Date
  ) throws {
    try validate(profileId, sessionId, actionId, at)
    guard expectedRevision >= 0 && expectedRevision < Int.max else {
      throw LoggingException(code: "invalid_revision")
    }
    let payload = ManualJSON.array([
      ManualJSON.string("set"), ManualJSON.string(sessionId), String(expectedRevision),
      record.canonicalJSON, correction ? "true" : "false", ManualJSON.string(dartISOString(at)),
    ])
    try db.transaction {
      if try replayed(profileId, actionId, payload) { return }
      let current = try session(profileId, sessionId)
      guard current["revision"]?.int == expectedRevision else {
        throw LoggingException(code: "stale_revision")
      }
      guard let started = current["started_at"]?.string, try at >= dartDate(started) else {
        throw LoggingException(code: "invalid_action_time")
      }
      if current["completed_at"]?.string != nil && !correction {
        throw LoggingException(code: "session_completed")
      }
      let previous = try db.rows(
        "SELECT * FROM set_records WHERE profile_id=? AND session_id=? AND id=?",
        [.text(profileId), .text(sessionId), .text(record.id)]
      ).first
      if correction {
        guard let previous, previous["exercise_id"]?.string == record.exerciseId,
          previous["set_index"]?.int == record.index, let prior = previous["payload"]?.string
        else { throw LoggingException(code: "correction_target_mismatch") }
        try db.execute(
          "INSERT INTO set_revisions(profile_id,session_id,set_id,revision,prior_payload,changed_at) VALUES(?,?,?,?,?,?)",
          [
            .text(profileId), .text(sessionId), .text(record.id),
            .integer(Int64(expectedRevision + 1)), .text(prior), .text(dartISOString(at)),
          ])
        try db.execute(
          "UPDATE set_records SET payload=? WHERE profile_id=? AND session_id=? AND id=?",
          [.text(record.canonicalJSON), .text(profileId), .text(sessionId), .text(record.id)])
      } else {
        try db.execute(
          "INSERT INTO set_records(profile_id,session_id,id,exercise_id,set_index,payload) VALUES(?,?,?,?,?,?)",
          [
            .text(profileId), .text(sessionId), .text(record.id), .text(record.exerciseId),
            .integer(Int64(record.index)), .text(record.canonicalJSON),
          ])
      }
      try db.execute(
        "UPDATE sessions SET revision=? WHERE profile_id=? AND id=?",
        [.integer(Int64(expectedRevision + 1)), .text(profileId), .text(sessionId)])
      try receipt(profileId, sessionId, actionId, payload, expectedRevision + 1)
    }
  }
  public func complete(
    profileId: String, sessionId: String, actionId: String, expectedRevision: Int, at: Date
  ) throws {
    try validate(profileId, sessionId, actionId, at)
    guard expectedRevision >= 0 && expectedRevision < Int.max else {
      throw LoggingException(code: "invalid_revision")
    }
    let payload = ManualJSON.array([
      ManualJSON.string("complete"), ManualJSON.string(sessionId), String(expectedRevision),
      ManualJSON.string(dartISOString(at)),
    ])
    try db.transaction {
      if try replayed(profileId, actionId, payload) { return }
      let current = try session(profileId, sessionId)
      if current["completed_at"]?.string != nil {
        guard let revision = current["revision"]?.int else {
          throw LoggingException(code: "invalid_revision")
        }
        try receipt(profileId, sessionId, actionId, payload, revision)
        return
      }
      guard current["revision"]?.int == expectedRevision else {
        throw LoggingException(code: "stale_revision")
      }
      guard let started = current["started_at"]?.string, try at >= dartDate(started) else {
        throw LoggingException(code: "invalid_action_time")
      }
      try db.execute(
        "UPDATE sessions SET completed_at=?,revision=? WHERE profile_id=? AND id=?",
        [
          .text(dartISOString(at)), .integer(Int64(expectedRevision + 1)), .text(profileId),
          .text(sessionId),
        ])
      try receipt(profileId, sessionId, actionId, payload, expectedRevision + 1)
    }
  }
  public func load(_ profileId: String) throws -> [PracticeSession] {
    try validateStorageId(profileId)
    return try db.transaction {
      try db.rows(
        "SELECT * FROM sessions WHERE profile_id=? ORDER BY started_at DESC,id DESC",
        [.text(profileId)]
      ).map { row in
        guard let id = row["id"]?.string, let start = row["started_at"]?.string,
          let revision = row["revision"]?.int
        else { throw LoggingException(code: "invalid_stored_session") }
        let records = try db.rows(
          "SELECT * FROM set_records WHERE profile_id=? AND session_id=? ORDER BY exercise_id,set_index",
          [.text(profileId), .text(id)]
        ).map { item in
          guard let payload = item["payload"]?.string else {
            throw LoggingException(code: "invalid_stored_set")
          }
          let record = try PracticeSet.decode(payload)
          guard record.id == item["id"]?.string, record.exerciseId == item["exercise_id"]?.string,
            record.index == item["set_index"]?.int
          else { throw LoggingException(code: "invalid_stored_set") }
          return record
        }
        return try PracticeSession(
          id: id, profileId: profileId, startedAt: dartDate(start),
          completedAt: row["completed_at"]?.string.map(dartDate), revision: revision, sets: records)
      }
    }
  }
  public func close() throws { try db.close() }
}
