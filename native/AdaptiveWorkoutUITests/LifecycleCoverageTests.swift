import XCTest

final class LifecycleCoverageTests: XCTestCase {
  @MainActor private func launch(_ name: String) -> XCUIApplication {
    let app = XCUIApplication()
    app.launchArguments = ["--fixture-directory", name, "--reset-fixture"]
    app.launch()
    XCTAssertTrue(app.buttons["start_monday"].waitForExistence(timeout: 20))
    return app
  }
  @MainActor private func reveal(_ app: XCUIApplication, button: String, up: Bool = true) {
    for _ in 0..<12 {
      if app.buttons.matching(identifier: button).firstMatch.isHittable { return }
      if up { app.swipeUp() } else { app.swipeDown() }
    }
    XCTAssertTrue(app.buttons.matching(identifier: button).firstMatch.isHittable)
  }
  @MainActor func testRestAndWorkoutSwitchCancellationPreserveDraftThenConfirmedSwitchKeepsHistory()
  {
    let app = launch("lifecycle_" + UUID().uuidString)
    app.buttons["start_monday"].tap()
    XCTAssertTrue(
      app.buttons["set_incline_dumbbell_press_1_both_false"].waitForExistence(timeout: 10))
    reveal(app, button: "Start 120s rest")
    app.buttons.matching(identifier: "Start 120s rest").firstMatch.tap()
    XCTAssertTrue(app.buttons["Clear rest"].exists)
    app.tabBars.buttons["Settings"].tap()
    app.tabBars.buttons["Workout"].tap()
    XCTAssertTrue(app.buttons["Clear rest"].exists)
    app.buttons["Choose workout"].tap()
    app.buttons["choose_tuesday"].tap()
    XCTAssertTrue(app.alerts["Finish current workout early?"].waitForExistence(timeout: 5))
    app.alerts.buttons["Keep current workout"].tap()
    XCTAssertTrue(app.buttons["set_incline_dumbbell_press_1_both_false"].exists)
    XCTAssertTrue(app.buttons["Clear rest"].exists)
    app.buttons["Choose workout"].tap()
    app.buttons["choose_tuesday"].tap()
    XCTAssertTrue(app.alerts["Finish current workout early?"].waitForExistence(timeout: 5))
    let confirmation = XCTAttachment(screenshot: app.screenshot())
    confirmation.name = "Workout switch confirmation"
    confirmation.lifetime = .keepAlways
    add(confirmation)
    app.alerts.buttons["Finish early and continue"].tap()
    XCTAssertTrue(app.buttons["set_leg_press_1_both_false"].waitForExistence(timeout: 10))
    XCTAssertFalse(app.buttons["Clear rest"].exists)
    reveal(app, button: "History", up: false)
    app.buttons["History"].tap()
    XCTAssertTrue(app.buttons["Delete"].waitForExistence(timeout: 10))
    app.buttons["Delete"].tap()
    app.alerts.buttons["Cancel"].tap()
    XCTAssertTrue(app.buttons["Delete"].exists)
    app.buttons["Log"].tap()
    XCTAssertTrue(app.buttons["set_leg_press_1_both_false"].exists)
  }
  @MainActor func testCustomGymAndSelectionSurviveRestart() {
    let name = "gym_" + UUID().uuidString
    let app = launch(name)
    app.tabBars.buttons["Settings"].tap()
    reveal(app, button: "My gym")
    app.buttons["My gym"].tap()
    reveal(app, button: "Add another location")
    app.buttons["Add another location"].tap()
    XCTAssertTrue(app.textFields["Gym name"].waitForExistence(timeout: 5))
    app.textFields["Gym name"].tap()
    app.textFields["Gym name"].typeText("Fixture gym")
    app.textFields["Address (optional)"].tap()
    app.textFields["Address (optional)"].typeText("Fixture address")
    app.buttons["Save location"].tap()
    XCTAssertTrue(app.staticTexts["Fixture address"].waitForExistence(timeout: 10))
    app.terminate()
    app.launchArguments = ["--fixture-directory", name]
    app.launch()
    XCTAssertTrue(app.buttons["start_monday"].waitForExistence(timeout: 20))
    app.tabBars.buttons["Settings"].tap()
    reveal(app, button: "My gym")
    app.buttons["My gym"].tap()
    XCTAssertTrue(app.staticTexts["Fixture address"].waitForExistence(timeout: 10))
    XCTAssertTrue(
      app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Fixture gym")).firstMatch
        .exists)
  }
}
