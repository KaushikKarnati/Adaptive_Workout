import XCTest

final class HistoryNavigationTests: XCTestCase {
  @MainActor func testFiltersAndPerSeriesMetricSurviveOpeningSavedWorkout() throws {
    let app = XCUIApplication()
    let name = "history_" + UUID().uuidString.replacingOccurrences(of: "-", with: "")
    app.launchArguments = ["--fixture-directory", name, "--reset-fixture"]
    app.launch()
    XCTAssertTrue(app.buttons["start_next_workout"].waitForExistence(timeout: 20))
    app.buttons["start_next_workout"].tap()
    let firstSet = app.buttons["set_incline_dumbbell_press_1_both_false"]
    XCTAssertTrue(firstSet.waitForExistence(timeout: 10))
    firstSet.tap()
    let setup = app.textFields["set_setup"]
    XCTAssertTrue(setup.waitForExistence(timeout: 5))
    setup.tap()
    setup.typeText("History fixture")
    app.buttons["set_convention"].tap()
    app.buttons["Pounds per dumbbell"].tap()
    app.textFields["set_load"].tap()
    app.textFields["set_load"].typeText("20")
    app.textFields["set_reps"].tap()
    app.textFields["set_reps"].typeText("8")
    app.swipeUp()
    app.buttons["set_validity"].tap()
    app.buttons["Valid"].tap()
    app.buttons["save_set"].tap()
    XCTAssertTrue(firstSet.waitForExistence(timeout: 10))
    for _ in 0..<20 {
      if app.buttons["Finish early"].isHittable { break }
      app.swipeUp()
    }
    XCTAssertTrue(app.buttons["Finish early"].isHittable)
    app.buttons["Finish early"].tap()
    app.alerts.buttons["Finish early"].tap()
    top(app, button: "History")
    app.buttons["tab_history"].tap()
    let search = app.textFields["history_search"]
    XCTAssertTrue(search.waitForExistence(timeout: 10))
    search.tap()
    search.typeText("Upper\n")
    app.buttons["history_range"].tap()
    app.buttons["90 days"].tap()
    let saved = app.buttons.matching(
      NSPredicate(format: "identifier BEGINSWITH %@", "history_workout_")
    ).firstMatch
    XCTAssertTrue(saved.waitForExistence(timeout: 10))
    saved.tap()
    top(app, button: "History")
    app.buttons["tab_history"].tap()
    XCTAssertTrue(search.waitForExistence(timeout: 10))
    XCTAssertEqual(search.value as? String, "Upper")
    XCTAssertTrue(app.buttons["history_range"].label.contains("90 days"))
    app.segmentedControls["history_mode"].buttons["Recorded trends"].tap()
    let latest = app.staticTexts["graph_latest_incline_dumbbell_press"]
    XCTAssertTrue(latest.waitForExistence(timeout: 10))
    XCTAssertEqual(latest.label, "Latest: 20.00 lb")
    let metric = app.segmentedControls["graph_metric_incline_dumbbell_press"]
    for _ in 0..<4 {
      if metric.buttons["Reps"].isHittable { break }
      app.swipeUp()
    }
    metric.buttons["Reps"].tap()
    XCTAssertEqual(latest.label, "Latest: 8 reps")
    top(app, button: "Log")
    app.buttons["tab_workout"].tap()
    top(app, button: "History")
    app.buttons["tab_history"].tap()
    app.segmentedControls["history_mode"].buttons["Recorded trends"].tap()
    XCTAssertTrue(latest.waitForExistence(timeout: 10))
    XCTAssertEqual(latest.label, "Latest: 8 reps")
    XCTAssertEqual(search.value as? String, "Upper")
    let attachment = XCTAttachment(screenshot: app.screenshot())
    attachment.name = "Retained history filters and metric"
    attachment.lifetime = .keepAlways
    add(attachment)
  }
  @MainActor private func top(_ app: XCUIApplication, button: String) {
    let target = app.buttons[button == "History" ? "tab_history" : "tab_workout"]
    XCTAssertTrue(target.isHittable)
    XCTAssertTrue(target.isEnabled)
  }
}
