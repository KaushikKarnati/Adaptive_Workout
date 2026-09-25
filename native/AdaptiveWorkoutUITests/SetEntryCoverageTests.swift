import XCTest

final class SetEntryCoverageTests: XCTestCase {
  @MainActor private func start(_ day: String) -> XCUIApplication {
    let app = XCUIApplication()
    app.launchArguments = ["--fixture-directory", "entry_" + UUID().uuidString, "--reset-fixture"]
    app.launch()
    XCTAssertTrue(app.buttons["start_monday"].waitForExistence(timeout: 20))
    for _ in 0..<5 {
      if app.buttons["start_" + day].isHittable { break }
      app.swipeUp()
    }
    app.buttons["start_" + day].tap()
    return app
  }
  @MainActor private func edit(_ app: XCUIApplication, slot: String, index: Int) -> XCUIElement {
    let row = app.buttons["set_\(slot)_\(index)_both_false"]
    XCTAssertTrue(row.waitForExistence(timeout: 10))
    row.tap()
    XCTAssertTrue(app.buttons["save_set"].waitForExistence(timeout: 5))
    XCTAssertFalse(app.textFields["set_setup"].exists)
    return row
  }
  @MainActor private func variation(_ app: XCUIApplication, _ value: String) {
    app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Variation")).firstMatch.tap()
    app.buttons[value].tap()
  }
  @MainActor private func save(_ app: XCUIApplication, row: XCUIElement) {
    for _ in 0..<3 {
      if app.buttons["save_set"].isHittable { break }
      app.swipeUp()
    }
    app.buttons["save_set"].tap()
    XCTAssertTrue(row.waitForExistence(timeout: 10))
    XCTAssertFalse(app.navigationBars["Record set"].exists)
  }
  @MainActor func testBodyweightAssistanceAndCopySaveThroughTheRealForm() {
    let app = start("friday")
    let first = edit(app, slot: "pull_up", index: 1)
    variation(app, "unassisted pull up")
    XCTAssertFalse(app.textFields["set_load"].exists)
    app.textFields["set_reps"].tap()
    app.textFields["set_reps"].typeText("8")
    save(app, row: first)
    XCTAssertTrue(first.label.contains("Bodyweight · 8 reps"))
    let second = edit(app, slot: "pull_up", index: 2)
    variation(app, "assisted machine pull up")
    XCTAssertTrue(app.buttons["set_convention"].label.contains("Assistance"))
    app.textFields["set_load"].tap()
    app.textFields["set_load"].typeText("70.125")
    app.textFields["set_reps"].tap()
    app.textFields["set_reps"].typeText("7")
    save(app, row: second)
    XCTAssertTrue(second.label.contains("70.125 lb support · 7 reps"))
    let third = edit(app, slot: "pull_up", index: 3)
    app.buttons["copy_previous_set"].tap()
    XCTAssertEqual(app.textFields["set_load"].value as? String, "70.125")
    XCTAssertEqual(app.textFields["set_reps"].value as? String, "7")
    save(app, row: third)
    XCTAssertTrue(third.label.contains("70.125 lb support · 7 reps"))
  }
  @MainActor func testMachinePlatesAndTotalLoadOptionsAllSaveWithoutSetup() {
    let app = start("tuesday")
    for (offset, label) in [
      "Displayed machine setting (lb)", "Added plates only (lb)", "Total load (lb)",
    ].enumerated() {
      let row = edit(app, slot: "leg_press", index: offset + 1)
      app.buttons["set_convention"].tap()
      app.buttons[label].tap()
      app.textFields["set_load"].tap()
      app.textFields["set_load"].typeText("45.123456")
      app.textFields["set_reps"].tap()
      app.textFields["set_reps"].typeText("10")
      save(app, row: row)
      XCTAssertTrue(row.label.contains("45.123456 lb · 10 reps"))
    }
  }
  @MainActor func testMissingAndMalformedActualsStayUnsavedThenCorrectionSucceeds() {
    let app = start("monday")
    let row = edit(app, slot: "incline_dumbbell_press", index: 1)
    app.buttons["save_set"].tap()
    XCTAssertTrue(app.navigationBars["Record set"].exists)
    let error = app.staticTexts[
      "Choose a variation and load measurement, then enter valid weight and reps. RIR may be blank."
    ]
    XCTAssertTrue(error.exists)
    let load = app.textFields["set_load"]
    load.tap()
    load.typeText("1..2")
    app.textFields["set_reps"].tap()
    app.textFields["set_reps"].typeText("8")
    app.swipeUp()
    app.buttons["save_set"].tap()
    XCTAssertTrue(app.navigationBars["Record set"].exists)
    XCTAssertTrue(error.exists)
    load.tap()
    load.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 4) + "20")
    save(app, row: row)
    XCTAssertTrue(row.label.contains("20 lb · 8 reps"))
  }
}
