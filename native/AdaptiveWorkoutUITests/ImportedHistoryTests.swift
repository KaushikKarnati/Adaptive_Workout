import XCTest

/// Optional private-data smoke test. The caller supplies an isolated fixture;
/// no health records or source values are bundled in this test target.
final class ImportedHistoryTests: XCTestCase {
  @MainActor func testImportedHistorySurvivesRestart() throws {
    let environment = ProcessInfo.processInfo.environment
    guard let fixture = environment["ADAPTIVE_IMPORTED_FIXTURE"],
      let countText = environment["ADAPTIVE_IMPORTED_FINISHED_COUNT"],
      let expectedCount = Int(countText), expectedCount > 0
    else { throw XCTSkip("No private imported fixture was supplied.") }
    guard fixture.hasPrefix("private_import_"),
      fixture.utf8.allSatisfy({
        (65...90).contains($0) || (97...122).contains($0) || (48...57).contains($0) || $0 == 95
      })
    else { throw XCTSkip("An isolated private fixture is required.") }
    let app = XCUIApplication()
    app.launchArguments = ["--fixture-directory", fixture]
    defer { app.terminate() }
    for _ in 0..<2 {
      app.launch()
      XCTAssertTrue(app.buttons["tab_history"].waitForExistence(timeout: 20))
      app.buttons["tab_history"].tap()
      let workouts = app.buttons.matching(
        NSPredicate(format: "identifier BEGINSWITH %@", "history_workout_"))
      XCTAssertTrue(workouts.firstMatch.waitForExistence(timeout: 10))
      XCTAssertEqual(workouts.count, expectedCount)
      workouts.firstMatch.tap()
      XCTAssertTrue(app.staticTexts["Workout Summary"].waitForExistence(timeout: 10))
      app.terminate()
    }
  }
}
