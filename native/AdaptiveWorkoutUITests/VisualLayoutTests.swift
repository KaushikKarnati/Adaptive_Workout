import XCTest

final class VisualLayoutTests: XCTestCase {
  @MainActor private func capture(_ app: XCUIApplication, _ name: String) {
    let screenshot = XCTAttachment(screenshot: app.screenshot())
    screenshot.name = name
    screenshot.lifetime = .keepAlways
    add(screenshot)
  }
  @MainActor func testDarkAppearanceAndScrollableSetEntry() {
    let app = XCUIApplication()
    app.launchArguments = ["--fixture-directory", "visual_" + UUID().uuidString, "--reset-fixture"]
    app.launch()
    XCTAssertTrue(app.buttons["start_monday"].waitForExistence(timeout: 20))
    app.tabBars.buttons["Settings"].tap()
    app.buttons["Appearance and feedback"].tap()
    app.buttons["appearance_picker"].tap()
    app.buttons["Dark"].tap()
    XCTAssertTrue(app.buttons["appearance_picker"].label.contains("Dark"))
    capture(app, "Dark settings")
    app.tabBars.buttons["Workout"].tap()
    capture(app, "Workout home typography")
    app.buttons["start_monday"].tap()
    let first = app.buttons["set_incline_dumbbell_press_1_both_false"]
    XCTAssertTrue(first.waitForExistence(timeout: 10))
    first.tap()
    XCTAssertTrue(app.textFields["set_load"].waitForExistence(timeout: 5))
    app.textFields["set_load"].tap()
    app.textFields["set_load"].typeText("20")
    app.textFields["set_reps"].tap()
    app.textFields["set_reps"].typeText("8")
    for _ in 0..<8 {
      if app.buttons["save_set"].isHittable { break }
      app.swipeUp()
    }
    capture(app, "Set editor typography")
    app.buttons["save_set"].tap()
    XCTAssertTrue(first.waitForExistence(timeout: 10))
    XCTAssertTrue(first.label.contains("20 lb · 8 reps"))
    capture(app, "Current set typography")
  }
}
