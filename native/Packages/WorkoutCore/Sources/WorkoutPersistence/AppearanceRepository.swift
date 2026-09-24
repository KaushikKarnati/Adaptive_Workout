import Foundation

public enum AppAppearance: String, CaseIterable, Sendable { case system, light, dark }
public enum AppearanceFailure: Error { case unsupportedSchema, invalidPreference }
public final class SqliteAppearanceRepository: Sendable {
  private let database: SQLiteDatabase
  public init(path: String) throws {
    database = try SQLiteDatabase(path: path)
    try database.transaction {
      let version = try database.rows("PRAGMA user_version").first?["user_version"]?.int ?? -1
      if version == 0 {
        try database.execute(
          "CREATE TABLE preferences (id INTEGER PRIMARY KEY CHECK(id=1), appearance TEXT NOT NULL CHECK(appearance IN ('system','light','dark')))"
        )
        try database.execute("PRAGMA user_version=1")
      } else if version != 1 {
        throw AppearanceFailure.unsupportedSchema
      }
    }
  }
  public func load() throws -> AppAppearance {
    let rows = try database.rows("SELECT appearance FROM preferences WHERE id=1")
    if rows.isEmpty { return .system }
    guard let raw = rows.first?["appearance"]?.string, let result = AppAppearance(rawValue: raw)
    else { throw AppearanceFailure.invalidPreference }
    return result
  }
  public func save(_ appearance: AppAppearance) throws {
    try database.execute(
      "INSERT OR REPLACE INTO preferences(id,appearance) VALUES(1,?)", [.text(appearance.rawValue)])
  }
  public func close() throws { try database.close() }
}
