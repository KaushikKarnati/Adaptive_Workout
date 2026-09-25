import XCTest

final class WorkoutFlowTests: XCTestCase {
  @MainActor func testSavedDraftSurvivesProcessRestartAndTabSwitch() throws {
    let app = XCUIApplication()
    let name = "flow_" + UUID().uuidString.replacingOccurrences(of: "-", with: "")
    app.launchArguments = ["--fixture-directory", name, "--reset-fixture"]
    app.launch()
    let start = app.buttons["start_monday"]
    XCTAssertTrue(start.waitForExistence(timeout: 20))
    start.tap()
    let firstSet = app.buttons["set_incline_dumbbell_press_1_both_false"]
    XCTAssertTrue(firstSet.waitForExistence(timeout: 10))
    firstSet.tap()
    XCTAssertTrue(app.textFields["set_load"].waitForExistence(timeout: 5))
    XCTAssertFalse(app.textFields["set_setup"].exists)
    let load = app.textFields["set_load"]
    load.tap()
    load.typeText("20")
    let reps = app.textFields["set_reps"]
    reps.tap()
    reps.typeText("8")
    app.swipeUp()
    app.buttons["set_validity"].tap()
    app.buttons["Valid"].tap()
    app.buttons["save_set"].tap()
    XCTAssertTrue(firstSet.waitForExistence(timeout: 10))
    XCTAssertTrue(firstSet.label.contains("20 lb"))
    let secondSet = app.buttons["set_incline_dumbbell_press_2_both_false"]
    XCTAssertTrue(secondSet.label.contains("Current set"))
    secondSet.tap()
    XCTAssertTrue(app.buttons["copy_previous_set"].waitForExistence(timeout: 5))
    app.buttons["copy_previous_set"].tap()
    XCTAssertEqual(app.textFields["set_load"].value as? String, "20")
    XCTAssertEqual(app.textFields["set_reps"].value as? String, "8")
    XCTAssertFalse(app.textFields["set_setup"].exists)
    app.buttons["Cancel"].tap()
    app.tabBars.buttons["Settings"].tap()
    app.tabBars.buttons["Workout"].tap()
    XCTAssertTrue(firstSet.exists)
    app.terminate()
    app.launchArguments = ["--fixture-directory", name]
    app.launch()
    XCTAssertTrue(firstSet.waitForExistence(timeout: 20))
    XCTAssertTrue(firstSet.label.contains("20 lb"))
    firstSet.tap()
    let corrected = app.textFields["set_reps"]
    XCTAssertTrue(corrected.waitForExistence(timeout: 5))
    corrected.tap()
    corrected.press(forDuration: 1)
    // Clear using the known existing fixture value, not assumptions about real data.
    corrected.typeText(XCUIKeyboardKey.delete.rawValue + "9")
    app.swipeUp()
    app.buttons["save_set"].tap()
    XCTAssertTrue(firstSet.waitForExistence(timeout: 10))
    XCTAssertTrue(firstSet.label.contains("9 reps"))
    let shot = XCTAttachment(screenshot: app.screenshot())
    shot.name = "Native workout"
    shot.lifetime = .keepAlways
    add(shot)
    app.tabBars.buttons["Settings"].tap()
    let settings = XCTAttachment(screenshot: app.screenshot())
    settings.name = "Native settings"
    settings.lifetime = .keepAlways
    add(settings)
    app.tabBars.buttons["Workout"].tap()
    for _ in 0..<18 {
      if app.buttons["Finish early"].isHittable { break }
      app.swipeUp()
    }
    XCTAssertTrue(app.buttons["Finish early"].isHittable)
    app.buttons["Finish early"].tap()
    app.alerts.buttons["Finish early"].tap()
    XCTAssertTrue(app.buttons["start_monday"].waitForExistence(timeout: 10))
    for _ in 0..<18 {
      if app.buttons["Graphs"].isHittable { break }
      app.swipeDown()
    }
    app.buttons["Graphs"].tap()
    XCTAssertTrue(app.staticTexts["Incline Dumbbell Press"].waitForExistence(timeout: 10))
    let graph = XCTAttachment(screenshot: app.screenshot())
    graph.name = "Native graph"
    graph.lifetime = .keepAlways
    add(graph)
    app.buttons["History"].tap()
    XCTAssertTrue(app.buttons["Delete"].waitForExistence(timeout: 10))
    app.buttons["Delete"].tap()
    app.alerts.buttons["Delete"].tap()
    XCTAssertTrue(
      app.staticTexts["No finished workouts match these filters."].waitForExistence(timeout: 10))
  }
  @MainActor func testAppearanceAndUnsavedSetupSurviveNavigation() throws {
    let app = XCUIApplication()
    let name = "settings_" + UUID().uuidString.replacingOccurrences(of: "-", with: "")
    app.launchArguments = ["--fixture-directory", name, "--reset-fixture"]
    app.launch()
    XCTAssertTrue(app.buttons["start_monday"].waitForExistence(timeout: 20))
    app.tabBars.buttons["Settings"].tap()
    app.buttons["Appearance and feedback"].tap()
    app.buttons["appearance_picker"].tap()
    app.buttons["Light"].tap()
    let light = XCTAttachment(screenshot: app.screenshot())
    light.name = "Native settings light"
    light.lifetime = .keepAlways
    add(light)
    app.buttons["Training setup"].tap()
    let minutes = app.textFields["Preferred workout minutes"]
    XCTAssertTrue(minutes.waitForExistence(timeout: 10))
    minutes.tap()
    minutes.typeText("45")
    app.tabBars.buttons["Workout"].tap()
    app.tabBars.buttons["Settings"].tap()
    XCTAssertEqual(minutes.value as? String, "45")
    app.buttons["Save preferences"].tap()
    XCTAssertTrue(app.staticTexts["Saved on this device."].waitForExistence(timeout: 10))
    app.terminate()
    app.launchArguments = ["--fixture-directory", name]
    app.launch()
    XCTAssertTrue(app.buttons["start_monday"].waitForExistence(timeout: 20))
    app.tabBars.buttons["Settings"].tap()
    app.buttons["Appearance and feedback"].tap()
    XCTAssertTrue(app.buttons["appearance_picker"].label.contains("Light"))
    app.buttons["Training setup"].tap()
    XCTAssertTrue(minutes.waitForExistence(timeout: 10))
    XCTAssertEqual(minutes.value as? String, "45")
    let setup = XCTAttachment(screenshot: app.screenshot())
    setup.name = "Native saved setup"
    setup.lifetime = .keepAlways
    add(setup)
  }

}
