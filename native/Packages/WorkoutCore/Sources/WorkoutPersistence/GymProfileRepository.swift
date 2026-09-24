import Foundation
import WorkoutDomain

public final class SqliteGymProfileRepository: GymProfileRepository {
  private let db: SQLiteDatabase
  public init(path: String) throws {
    db = try SQLiteDatabase(path: path)
    let version = try db.rows("PRAGMA user_version").first?["user_version"]?.int ?? -1
    try requireSetup(version == 0 || version == 1, "unsupported_gym_schema")
    if version == 0 {
      try db.transaction {
        try db.execute(
          "CREATE TABLE gym_profiles (id INTEGER PRIMARY KEY CHECK(id=1), payload TEXT NOT NULL)")
        try db.execute("PRAGMA user_version=1")
      }
    }
  }
  public func load() throws -> GymProfiles {
    if let row = try db.rows("SELECT payload FROM gym_profiles WHERE id=1").first {
      guard let payload = row["payload"]?.string else {
        throw SetupException("invalid_gym_payload")
      }
      return try GymProfiles.decode(payload)
    }
    return try GymProfiles(profiles: [])
  }
  public func save(_ next: GymProfiles, expected: GymProfiles) throws {
    let payload = try GymProfiles.decode(next.encode()).encode()
    try db.transaction {
      let current = try load().encode()
      if ManualJSON.bytesEqual(current, payload) { return }
      try requireSetup(ManualJSON.bytesEqual(current, expected.encode()), "gym_profile_changed")
      try db.execute(
        "INSERT OR REPLACE INTO gym_profiles(id,payload) VALUES(1,?)", [.text(payload)])
    }
  }
  public func close() throws { try db.close() }
}
