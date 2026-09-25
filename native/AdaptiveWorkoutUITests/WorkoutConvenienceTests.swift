import XCTest

final class WorkoutConvenienceTests: XCTestCase {
  @MainActor private func launch() -> XCUIApplication {
    let app = XCUIApplication()
    app.launchArguments = [
      "--fixture-directory", "convenience_" + UUID().uuidString,
      "--reset-fixture",
    ]
    app.launch()
    XCTAssertTrue(app.buttons["start_monday"].waitForExistence(timeout: 20))
    return app
  }
  @MainActor func testSupersetFocusFollowsPairedRoundsAfterConfirmedSkips() {
    let app = launch()
    app.buttons["start_monday"].tap()
    let targets = [
      "incline_dumbbell_press_1", "incline_dumbbell_press_2", "incline_dumbbell_press_3",
      "neutral_grip_lat_pulldown_1", "neutral_grip_lat_pulldown_2", "neutral_grip_lat_pulldown_3",
      "incline_machine_press_1", "chest_supported_row_1", "incline_machine_press_2",
    ]
    for target in targets {
      let row = app.buttons["set_" + target + "_both_false"]
      XCTAssertTrue(row.waitForExistence(timeout: 10))
      XCTAssertTrue(row.label.contains("Current set"), target)
      row.tap()
      let measurement = app.buttons["set_convention"]
      XCTAssertTrue(measurement.waitForExistence(timeout: 5))
      if measurement.label.contains("Choose measurement") {
        measurement.tap()
        app.buttons["Displayed machine setting (lb)"].tap()
      }
      XCTAssertFalse(app.textFields["set_setup"].exists)
      app.buttons["Skip set"].tap()
      XCTAssertTrue(row.waitForExistence(timeout: 5))
      XCTAssertTrue(row.label.contains("Skipped"))
    }
    XCTAssertTrue(app.buttons["set_chest_supported_row_2_both_false"].label.contains("Current set"))
  }
  @MainActor func testOfflineLibraryAndNotificationSettingsAreAvailable() {
    let app = launch()
    app.tabBars.buttons["Settings"].tap()
    let notifications = app.buttons["Notifications"]
    for _ in 0..<6 {
      if notifications.isHittable { break }
      app.swipeUp()
    }
    notifications.tap()
    XCTAssertTrue(app.switches["Rest timer alerts"].exists)
    app.switches["Workout reminders"].coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5))
      .tap()
    XCTAssertTrue(app.switches["Monday"].waitForExistence(timeout: 5))
    app.switches["Monday"].coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
    for _ in 0..<6 {
      if app.buttons["Save notifications"].isHittable { break }
      app.swipeUp()
    }
    app.buttons["Save notifications"].tap()
    XCTAssertTrue(app.staticTexts["Notifications are disabled in test fixtures."].exists)
    let library = app.buttons["Exercise library · wger"]
    for _ in 0..<8 {
      if library.isHittable { break }
      app.swipeDown()
    }
    library.tap()
    XCTAssertTrue(
      app.staticTexts["Snapshot: September 25, 2026 · 788 exercises"].waitForExistence(timeout: 10))
    let search = app.searchFields.firstMatch
    search.tap()
    search.typeText("Arnold\n")
    XCTAssertTrue(
      app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Arnold")).firstMatch
        .waitForExistence(timeout: 5))
  }
}
