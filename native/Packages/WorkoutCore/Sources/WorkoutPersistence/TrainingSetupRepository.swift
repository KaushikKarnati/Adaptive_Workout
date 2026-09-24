import Foundation
import WorkoutDomain

public final class SqliteTrainingSetupRepository: TrainingSetupRepository {
  private let db: SQLiteDatabase
  public init(path: String) throws {
    db = try SQLiteDatabase(path: path)
    try db.execute("PRAGMA foreign_keys=ON")
    try db.execute("PRAGMA synchronous=FULL")
    try requireSetup(
      try db.rows("PRAGMA foreign_keys").first?["foreign_keys"]?.int == 1, "foreign_keys_required")
    let version = try db.rows("PRAGMA user_version").first?["user_version"]?.int ?? -1
    try requireSetup(version == 0 || version == 1, "unsupported_schema")
    if version == 0 {
      try db.transaction {
        try db.execute(
          "CREATE TABLE profiles(id TEXT PRIMARY KEY,revision INTEGER NOT NULL,payload TEXT NOT NULL)"
        )
        try db.execute(
          "CREATE TABLE revisions(profile TEXT NOT NULL,revision INTEGER NOT NULL,payload TEXT NOT NULL,PRIMARY KEY(profile,revision),FOREIGN KEY(profile) REFERENCES profiles(id))"
        )
        try db.execute(
          "CREATE TABLE receipts(profile TEXT NOT NULL,action TEXT NOT NULL,request TEXT NOT NULL,PRIMARY KEY(profile,action),FOREIGN KEY(profile) REFERENCES profiles(id))"
        )
        try db.execute("PRAGMA user_version=1")
      }
    }
  }
  private func read(_ row: [String: SQLValue]) throws -> TrainingSetup {
    guard let payload = row["payload"]?.string else {
      throw SetupException("invalid_setup_payload")
    }
    let result = try TrainingSetup.decode(payload)
    try requireSetup(
      result.profileId == row["id"]?.string && result.revision == row["revision"]?.int
        && ManualJSON.bytesEqual(result.encode(), payload), "stored_identity_mismatch")
    return result
  }
  public func load(_ profileId: String) throws -> TrainingSetup? {
    try validateSetupId(profileId)
    return try db.rows("SELECT * FROM profiles WHERE id=?", [.text(profileId)]).first.map(read)
  }
  public func save(_ setup: TrainingSetup, expectedRevision: Int, actionId: String) throws {
    try validateSetupId(actionId)
    let payload = setup.encode()
    _ = try TrainingSetup.decode(payload)
    try requireSetup(
      expectedRevision >= -1 && setup.revision == expectedRevision + 1, "invalid_revision")
    let request = ManualJSON.object([
      ("expectedRevision", String(expectedRevision)), ("payload", ManualJSON.string(payload)),
    ])
    try db.transaction {
      let old = try load(setup.profileId)
      if let receipt = try db.rows(
        "SELECT request FROM receipts WHERE profile=? AND action=?",
        [.text(setup.profileId), .text(actionId)]
      ).first {
        try requireSetup(
          receipt["request"]?.string.map({ ManualJSON.bytesEqual($0, request) }) == true
            && old != nil, "action_conflict")
        return
      }
      try requireSetup((old?.revision ?? -1) == expectedRevision, "stale_revision")
      try validateSetupTransition(old, setup)
      if let old {
        try db.execute(
          "INSERT INTO revisions(profile,revision,payload) VALUES(?,?,?)",
          [.text(old.profileId), .integer(Int64(old.revision)), .text(old.encode())])
        try db.execute(
          "UPDATE profiles SET revision=?,payload=? WHERE id=?",
          [.integer(Int64(setup.revision)), .text(payload), .text(setup.profileId)])
      } else {
        try db.execute(
          "INSERT INTO profiles(id,revision,payload) VALUES(?,?,?)",
          [.text(setup.profileId), .integer(Int64(setup.revision)), .text(payload)])
      }
      try db.execute(
        "INSERT INTO receipts(profile,action,request) VALUES(?,?,?)",
        [.text(setup.profileId), .text(actionId), .text(request)])
    }
  }
  public func close() throws { try db.close() }
}
