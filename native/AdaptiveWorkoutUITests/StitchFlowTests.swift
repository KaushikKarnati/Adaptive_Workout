import XCTest

final class StitchFlowTests: XCTestCase {
  @MainActor func testDashboardNavigationRestAndSummary() throws {
    let app = XCUIApplication()
    app.launchArguments = [
      "--fixture-directory", "stitch_" + UUID().uuidString.replacingOccurrences(of: "-", with: ""),
      "--reset-fixture",
    ]
    app.launch()
    XCTAssertTrue(app.buttons["start_next_workout"].waitForExistence(timeout: 20))
    capture(app, "Stitch dashboard light")
    app.buttons["tab_plan"].tap()
    XCTAssertTrue(app.staticTexts["Your Training Plan"].waitForExistence(timeout: 5))
    app.buttons["tab_history"].tap()
    XCTAssertTrue(app.textFields["history_search"].waitForExistence(timeout: 5))
    capture(app, "Stitch history empty")
    app.buttons["tab_profile"].tap()
    XCTAssertTrue(app.buttons["Appearance and feedback"].waitForExistence(timeout: 5))
    app.buttons["tab_workout"].tap()
    app.buttons["start_next_workout"].tap()
    let layout = app.segmentedControls["logging_layout"]
    XCTAssertTrue(layout.waitForExistence(timeout: 10))
    capture(app, "Stitch active workout light")
    layout.buttons["Focus"].tap()
    let rest = app.buttons.matching(NSPredicate(format: "label MATCHES %@", "Start [0-9]+s rest"))
      .firstMatch
    reveal(rest, in: app)
    rest.tap()
    XCTAssertTrue(app.buttons["Clear rest"].waitForExistence(timeout: 5))
    capture(app, "Stitch running rest dock")
    app.buttons["Back to dashboard"].tap()
    XCTAssertTrue(app.buttons["resume_workout"].waitForExistence(timeout: 5))
    capture(app, "Stitch saved session dashboard")
    app.buttons["resume_workout"].tap()
    XCTAssertTrue(app.buttons["Clear rest"].exists)
    app.buttons["Clear rest"].tap()
    let finish = app.buttons["Finish early"]
    reveal(finish, in: app)
    finish.tap()
    app.alerts.buttons["Finish early"].tap()
    XCTAssertTrue(app.staticTexts["Workout Summary"].waitForExistence(timeout: 10))
    for _ in 0..<4 { app.swipeDown() }
    XCTAssertTrue(app.staticTexts["Workout\nFinished Early"].exists)
    capture(app, "Stitch completion summary")
    app.buttons["tab_history"].tap()
    XCTAssertTrue(
      app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "history_workout_"))
        .firstMatch.waitForExistence(timeout: 5))
    capture(app, "Stitch recorded history")
    app.buttons["tab_profile"].tap()
    app.buttons["Appearance and feedback"].tap()
    app.buttons["appearance_picker"].tap()
    app.buttons["Dark"].tap()
    app.buttons["tab_workout"].tap()
    capture(app, "Stitch summary dark")
  }
  @MainActor private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
    for _ in 0..<20 {
      if element.isHittable && element.frame.maxY < app.buttons["tab_workout"].frame.minY - 140 {
        break
      }
      app.swipeUp()
    }
    XCTAssertTrue(element.isHittable)
  }
  @MainActor private func capture(_ app: XCUIApplication, _ name: String) {
    let attachment = XCTAttachment(screenshot: app.screenshot())
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }
}
