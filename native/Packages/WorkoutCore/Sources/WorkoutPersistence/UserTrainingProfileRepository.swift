import Foundation
import WorkoutDomain

/// Immutable profile/program revisions in a separate store; never rewrites legacy workouts.
public final class SqliteUserTrainingProfileRepository: UserTrainingProfileRepository,
  @unchecked Sendable
{
  private let db: SQLiteDatabase
  public init(path: String) throws {
    db = try SQLiteDatabase(path: path)
    try db.transaction {
      let version = try db.rows("PRAGMA user_version").first?["user_version"]?.int ?? 0
      guard version == 0 || version == 1 else { throw ProfileFailure.unsupportedSchema }
      try db.execute(
        "CREATE TABLE IF NOT EXISTS profiles (id TEXT NOT NULL, revision INTEGER NOT NULL, payload TEXT NOT NULL, PRIMARY KEY(id, revision))"
      )
      try db.execute("PRAGMA user_version = 1")
    }
  }
  public func currentProfile() throws -> UserTrainingProfile? {
    guard
      let id = try db.rows("SELECT id FROM profiles ORDER BY rowid DESC LIMIT 1").first?["id"]?
        .string
    else { return nil }
    return try load(id)
  }
  public func load(_ id: String) throws -> UserTrainingProfile? {
    guard
      let row = try db.rows(
        "SELECT revision, payload FROM profiles WHERE id = ? ORDER BY revision DESC LIMIT 1",
        [.text(id)]
      ).first
    else { return nil }
    guard let payload = row["payload"]?.string else { throw ProfileFailure.invalid }
    let value = try JSONDecoder().decode(UserTrainingProfile.self, from: Data(payload.utf8))
    try value.validate()
    guard value.id == id, value.revision == row["revision"]?.int else {
      throw ProfileFailure.invalid
    }
    return value
  }
  public func save(_ next: UserTrainingProfile, expectedRevision: Int?) throws {
    try next.validate()
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    let payload = String(decoding: try encoder.encode(next), as: UTF8.self)
    try db.transaction {
      let current = try load(next.id)
      // Exact retry after an uncertain acknowledgement is idempotent.
      if current == next { return }
      guard current?.revision == expectedRevision,
        next.revision == (expectedRevision.map { $0 + 1 } ?? 0)
      else { throw ProfileFailure.conflict }
      try db.execute(
        "INSERT INTO profiles(id, revision, payload) VALUES (?, ?, ?)",
        [.text(next.id), .integer(Int64(next.revision)), .text(payload)])
      guard try load(next.id) == next else { throw ProfileFailure.invalid }
    }
  }
}
