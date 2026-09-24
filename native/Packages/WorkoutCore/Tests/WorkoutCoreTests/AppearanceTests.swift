import Foundation
import WorkoutDomain
import WorkoutPersistence
import XCTest

final class AppearanceTests: XCTestCase {
  func testUnavailableAppearanceDoesNotBlockWorkoutStoreOrDestroyPreference() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let path = directory.appendingPathComponent("appearance.sqlite").path
    let raw = try SQLiteDatabase(path: path)
    try raw.execute("PRAGMA user_version=99")
    try raw.execute("CREATE TABLE future_preference (payload TEXT)")
    try raw.execute("INSERT INTO future_preference VALUES (?)", [.text("keep")])
    let stores = try LocalAppStores(directory: directory)
    XCTAssertThrowsError(try stores.appearance.get())
    XCTAssertEqual(try stores.programLogs.load("appearance-fixture"), [])
    let log = ProgramLog(
      id: "draft", profile: "appearance-fixture", programId: "monday", startedAt: Date(),
      revision: 0, completedAt: nil, sets: [])
    try stores.programLogs.write(log, expectedRevision: -1, actionId: "start")
    XCTAssertEqual(try stores.programLogs.load(log.profile).map(\.id), [log.id])
    XCTAssertEqual(try raw.rows("PRAGMA user_version").first?["user_version"]?.int, 99)
    XCTAssertEqual(
      try raw.rows("SELECT payload FROM future_preference").first?["payload"]?.string, "keep")
    try raw.execute("DROP TABLE future_preference")
    try raw.execute("PRAGMA user_version=0")
    let retried = try LocalAppStores.loadAppearance(directory: directory).get()
    XCTAssertEqual(retried.preference, .system)
    try retried.repository.save(.dark)
    XCTAssertEqual(try retried.repository.load(), .dark)
    try retried.repository.close()
    try stores.programLogs.close()
    try raw.close()
  }

  func testPreferencePersistenceAndFutureSchemaPreserved() throws {
    let path = FileManager.default.temporaryDirectory.appendingPathComponent(
      "appearance-" + UUID().uuidString + ".sqlite"
    ).path
    defer { try? FileManager.default.removeItem(atPath: path) }
    let repository = try SqliteAppearanceRepository(path: path)
    XCTAssertEqual(try repository.load(), .system)
    for appearance in AppAppearance.allCases {
      try repository.save(appearance)
      XCTAssertEqual(try repository.load(), appearance)
    }
    try repository.close()
    let reopened = try SqliteAppearanceRepository(path: path)
    XCTAssertEqual(try reopened.load(), .dark)
    try reopened.close()
    let raw = try SQLiteDatabase(path: path)
    try raw.execute("PRAGMA user_version=9")
    XCTAssertThrowsError(try SqliteAppearanceRepository(path: path))
    XCTAssertEqual(try raw.rows("PRAGMA user_version").first?["user_version"]?.int, 9)
    XCTAssertEqual(
      try raw.rows("SELECT appearance FROM preferences").first?["appearance"]?.string, "dark")
    try raw.close()
  }
}
