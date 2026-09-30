import XCTest

final class WorkoutFlowTests: XCTestCase {
  @MainActor func testSavedDraftSurvivesProcessRestartAndTabSwitch() throws {
    let app = XCUIApplication()
    let name = "flow_" + UUID().uuidString.replacingOccurrences(of: "-", with: "")
    app.launchArguments = ["--fixture-directory", name, "--reset-fixture"]
    app.launch()
    let start = app.buttons["start_next_workout"]
    XCTAssertTrue(start.waitForExistence(timeout: 20))
    start.tap()
    let firstSet = app.buttons["set_incline_dumbbell_press_1_both_false"]
    XCTAssertTrue(firstSet.waitForExistence(timeout: 10))
    firstSet.tap()
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
    app.buttons["tab_profile"].tap()
    app.buttons["tab_workout"].tap()
    XCTAssertTrue(firstSet.exists)
    app.terminate()
    app.launchArguments = ["--fixture-directory", name]
    app.launch()
    XCTAssertTrue(app.buttons["resume_workout"].waitForExistence(timeout: 20))
    app.buttons["resume_workout"].tap()
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
    app.buttons["tab_profile"].tap()
    let settings = XCTAttachment(screenshot: app.screenshot())
    settings.name = "Native settings"
    settings.lifetime = .keepAlways
    add(settings)
    app.buttons["tab_workout"].tap()
    for _ in 0..<18 {
      if app.buttons["Finish early"].isHittable { break }
      app.swipeUp()
    }
    XCTAssertTrue(app.buttons["Finish early"].isHittable)
    app.buttons["Finish early"].tap()
    app.alerts.buttons["Finish early"].tap()
    for _ in 0..<18 {
      if app.buttons["tab_history"].isHittable { break }
      app.swipeDown()
    }
    app.buttons["tab_history"].tap()
    app.segmentedControls["history_mode"].buttons["Recorded trends"].tap()
    XCTAssertTrue(app.staticTexts["Incline Dumbbell Press"].waitForExistence(timeout: 10))
    let graph = XCTAttachment(screenshot: app.screenshot())
    graph.name = "Native graph"
    graph.lifetime = .keepAlways
    add(graph)
    app.segmentedControls["history_mode"].buttons["Workouts"].tap()
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
    XCTAssertTrue(app.buttons["start_next_workout"].waitForExistence(timeout: 20))
    app.buttons["tab_profile"].tap()
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
    minutes.typeText("4")
    XCTAssertEqual(minutes.value as? String, "4")
    minutes.typeText("5")
    XCTAssertEqual(minutes.value as? String, "45")
    app.buttons["tab_workout"].tap()
    app.buttons["tab_profile"].tap()
    XCTAssertEqual(minutes.value as? String, "45")
    XCTAssertFalse(app.keyboards.firstMatch.exists)
    let savePreferences = app.buttons["Save preferences"]
    for _ in 0..<10 {
      if savePreferences.isHittable { break }
      app.swipeUp()
    }
    XCTAssertTrue(savePreferences.isHittable)
    savePreferences.tap()
    XCTAssertTrue(app.staticTexts["Saved on this device."].waitForExistence(timeout: 10))
    app.terminate()
    app.launchArguments = ["--fixture-directory", name]
    app.launch()
    XCTAssertTrue(app.buttons["start_next_workout"].waitForExistence(timeout: 20))
    app.buttons["tab_profile"].tap()
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
