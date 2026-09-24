import Foundation
import WorkoutApplication
import XCTest

@testable import WorkoutPersistence

final class StorageTimingTests: XCTestCase {
  func testBoundValuesAndRollback() throws {
    let db = try SQLiteDatabase(path: ":memory:")
    try db.execute("CREATE TABLE records(id INTEGER PRIMARY KEY, value TEXT)")
    let value = "test'\u{0}; DROP TABLE records;"
    try db.execute("INSERT INTO records VALUES(?,?)", [.integer(1), .text(value)])
    XCTAssertEqual(try db.rows("SELECT value FROM records").first?["value"]?.string, value)
    XCTAssertThrowsError(
      try db.transaction {
        try db.execute("INSERT INTO records VALUES(?,?)", [.integer(2), .text("fixture")])
        try db.execute("INSERT INTO records VALUES(?,?)", [.integer(1), .text("duplicate")])
      })
    XCTAssertEqual(try db.rows("SELECT * FROM records").count, 1)
    XCTAssertThrowsError(try db.execute("DELETE FROM records WHERE id=?"))
    try db.execute("INSERT INTO records VALUES(2,CAST(X'80' AS TEXT))")
    XCTAssertThrowsError(try db.rows("SELECT value FROM records WHERE id=2"))
    try db.close()
    XCTAssertThrowsError(try db.rows("SELECT * FROM records"))
  }
  func testTimersUseExplicitDatesAndRoundUp() throws {
    let now = Date(timeIntervalSince1970: 100)
    XCTAssertEqual(sessionElapsed(start: now, end: nil, now: now.addingTimeInterval(-5)), 0)
    XCTAssertEqual(
      sessionElapsed(start: now, end: now.addingTimeInterval(65), now: now.addingTimeInterval(100)),
      65)
    XCTAssertEqual(timerText(65), "01:05")
    var rest = RestCountdown()
    XCTAssertThrowsError(try rest.start(seconds: 0, now: now))
    try rest.start(seconds: 60, now: now)
    XCTAssertEqual(rest.remaining(now: now.addingTimeInterval(59.1)), 1)
    XCTAssertEqual(rest.remaining(now: now.addingTimeInterval(60)), 0)
    XCTAssertEqual(rest.remaining(now: now.addingTimeInterval(1000)), 0)
    rest.clear()
    XCTAssertFalse(rest.started)
  }
  func testInvalidOrExtremeTimingDoesNotTrap() throws {
    XCTAssertEqual(timerText(.infinity), "00:00")
    XCTAssertEqual(timerText(.nan), "00:00")
    XCTAssertEqual(timerText(-100), "00:00")
    XCTAssertFalse(timerText(Double.greatestFiniteMagnitude).isEmpty)
    XCTAssertEqual(timerText(Double(60) * 3_000_000_000 + 5), "3000000000:05")
    var rest = RestCountdown()
    XCTAssertThrowsError(try rest.start(seconds: 60, now: Date(timeIntervalSince1970: .nan)))
    try rest.start(seconds: Int.max, now: Date(timeIntervalSince1970: 0))
    XCTAssertFalse(timerText(rest.remaining(now: Date(timeIntervalSince1970: 0))).isEmpty)
    XCTAssertEqual(
      sessionElapsed(start: Date(timeIntervalSince1970: .nan), end: nil, now: Date()), 0)
  }
  func testFixtureNamesRejectTrailingNewlinesAndNonASCII() throws {
    let directory = URL(fileURLWithPath: "/fixture/Documents")
    for name in [
      "flow\n", "flow\r\n", "flow\u{0000}", "flowé", "", String(repeating: "a", count: 129),
    ] {
      XCTAssertThrowsError(
        try StorageLaunchContext(
          documents: directory, arguments: ["--fixture-directory", name],
          hostedTest: false, allowsTesting: true, hostedIdentity: "run"))
    }
    let maximum = String(repeating: "a", count: 128)
    let context = try StorageLaunchContext(
      documents: directory, arguments: ["--fixture-directory", maximum],
      hostedTest: false, allowsTesting: true, hostedIdentity: "run")
    XCTAssertEqual(context.directory.lastPathComponent, maximum)
  }
  func testFixtureRoutingSeparatesDatabasesAndPreferencesAndFailsClosedInRelease() throws {
    let directory = URL(fileURLWithPath: "/fixture/Documents")
    let normal = try StorageLaunchContext(
      documents: directory, arguments: [], hostedTest: false, allowsTesting: false,
      hostedIdentity: "run")
    XCTAssertEqual(normal.directory, directory)
    XCTAssertNil(normal.preferencesDomain)
    let fixture = try StorageLaunchContext(
      documents: directory, arguments: ["--fixture-directory", "flow_1", "--reset-fixture"],
      hostedTest: false, allowsTesting: true, hostedIdentity: "run")
    XCTAssertEqual(fixture.directory.path, "/fixture/Documents/UITestFixtures/flow_1")
    XCTAssertNotNil(fixture.preferencesDomain)
    XCTAssertTrue(fixture.resetFixture)
    let hosted = try StorageLaunchContext(
      documents: directory, arguments: [], hostedTest: true, allowsTesting: true,
      hostedIdentity: "run")
    XCTAssertEqual(hosted.directory.lastPathComponent, "hosted_run")
    for arguments in [["--fixture-directory", "flow"], ["--reset-fixture"], ["--practice"]] {
      XCTAssertThrowsError(
        try StorageLaunchContext(
          documents: directory, arguments: arguments, hostedTest: false, allowsTesting: false,
          hostedIdentity: "run"))
    }
    for arguments in [
      ["--fixture-directory"], ["--fixture-directory", "../normal"], ["--reset-fixture"],
    ] {
      XCTAssertThrowsError(
        try StorageLaunchContext(
          documents: directory, arguments: arguments, hostedTest: false, allowsTesting: true,
          hostedIdentity: "run"))
    }
  }

}
