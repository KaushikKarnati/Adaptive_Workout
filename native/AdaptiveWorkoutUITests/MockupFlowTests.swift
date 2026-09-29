import XCTest

final class MockupFlowTests: XCTestCase {
  @MainActor func testLoggingLayoutsAndGlassTimerInBothAppearances() throws {
    let app = launchFixture("layouts")
    app.buttons["start_next_workout"].tap()
    let layout = app.segmentedControls["logging_layout"]
    XCTAssertTrue(layout.waitForExistence(timeout: 10))
    reveal(layout, in: app)
    XCTAssertTrue(layout.buttons["Cards"].isSelected)
    XCTAssertTrue(app.descendants(matching: .any)["workout_timer_capsule"].exists)
    capture(app, "Cards and separate timer capsule light")
    layout.buttons["Table"].tap()
    XCTAssertTrue(layout.buttons["Table"].isSelected)
    XCTAssertTrue(app.buttons["set_incline_dumbbell_press_1_both_false"].exists)
    capture(app, "Table light")
    layout.buttons["Focus"].tap()
    XCTAssertTrue(layout.buttons["Focus"].isSelected)
    let startRest = app.buttons.matching(
      NSPredicate(format: "label MATCHES %@", "Start [0-9]+s rest")
    )
    .firstMatch
    reveal(startRest, in: app)
    startRest.tap()
    XCTAssertTrue(app.buttons["Clear rest"].waitForExistence(timeout: 5))
    app.buttons["tab_profile"].tap()
    app.buttons["tab_workout"].tap()
    XCTAssertTrue(app.buttons["Clear rest"].exists)
    capture(app, "Focus with running capsule")
    app.buttons["Clear rest"].tap()
    XCTAssertTrue(app.staticTexts["Rest ready"].exists)
    app.buttons["tab_profile"].tap()
    app.buttons["Appearance and feedback"].tap()
    app.buttons["appearance_picker"].tap()
    app.buttons["Dark"].tap()
    app.buttons["tab_workout"].tap()
    reveal(layout, in: app, upward: false)
    capture(app, "Focus and timer capsule dark")
    layout.buttons["Cards"].tap()
    XCTAssertTrue(layout.buttons["Cards"].isSelected)
    capture(app, "Cards dark")
  }

  @MainActor func testFocusSkipPersistsAndCanceledPainDoesNotWrite() throws {
    let name = fixtureName("focus_skip")
    let app = launchFixture(name, exact: true)
    app.buttons["start_next_workout"].tap()
    let layout = app.segmentedControls["logging_layout"]
    XCTAssertTrue(layout.waitForExistence(timeout: 10))
    reveal(layout, in: app)
    layout.buttons["Focus"].tap()
    let skip = app.buttons["Skip set"]
    reveal(skip, in: app)
    skip.tap()
    let setup = app.textFields["set_setup"]
    XCTAssertTrue(setup.waitForExistence(timeout: 5))
    XCTAssertFalse(app.textFields["set_load"].exists)
    XCTAssertFalse(app.textFields["set_reps"].exists)
    XCTAssertFalse(app.textFields["set_rir"].exists)
    XCTAssertFalse(app.buttons["set_validity"].exists)
    XCTAssertFalse(app.buttons["save_set"].exists)
    setup.tap()
    setup.typeText("Skipped fixture dumbbells")
    app.buttons["set_convention"].tap()
    app.buttons["Pounds per dumbbell"].tap()
    // The sheet's Form and the underlying Focus screen both expose Skip set.
    let saveSkip = app.collectionViews.buttons["Skip set"]
    reveal(saveSkip, in: app)
    saveSkip.tap()
    let firstSet = app.buttons["set_incline_dumbbell_press_1_both_false"]
    XCTAssertTrue(firstSet.waitForExistence(timeout: 10))
    XCTAssertTrue(firstSet.label.contains("Skipped"))
    app.terminate()
    app.launchArguments = ["--fixture-directory", name]
    app.launch()
    XCTAssertTrue(app.buttons["resume_workout"].waitForExistence(timeout: 20))
    app.buttons["resume_workout"].tap()
    XCTAssertTrue(firstSet.waitForExistence(timeout: 20))
    XCTAssertTrue(firstSet.label.contains("Skipped"))
    XCTAssertTrue(layout.buttons["Focus"].isSelected)
    let options = app.buttons["Warm-ups and exercise options"]
    reveal(options, in: app)
    options.tap()
    let change = app.buttons["Change exercise"]
    reveal(change, in: app)
    change.tap()
    let pain = app.buttons["Pain or concerning symptom"]
    XCTAssertTrue(pain.waitForExistence(timeout: 5))
    reveal(pain, in: app)
    pain.tap()
    let validity = app.buttons["set_validity"]
    XCTAssertTrue(validity.waitForExistence(timeout: 10))
    reveal(validity, in: app)
    XCTAssertTrue(validity.label.contains("Pain"))
    let emptyReps = app.textFields["set_reps"]
    reveal(emptyReps, in: app, upward: false)
    XCTAssertEqual(emptyReps.placeholderValue, "Completed reps")
    // iOS on device exposes an empty field as nil; Simulator may expose its placeholder.
    let repsValue = emptyReps.value as? String ?? ""
    XCTAssertTrue(repsValue.isEmpty || repsValue == "Completed reps")
    capture(app, "Pain route awaiting explicit actuals")
    app.buttons["Cancel"].tap()
    let secondSet = app.buttons["set_incline_dumbbell_press_2_both_false"]
    XCTAssertTrue(secondSet.waitForExistence(timeout: 10))
    XCTAssertTrue(secondSet.label.contains("Not recorded"))
    XCTAssertFalse(
      app.staticTexts[
        "Pain was recorded. Further sets for that exercise are stopped; remaining sets may be skipped."
      ].exists)
    app.terminate()
    app.launch()
    XCTAssertTrue(app.buttons["resume_workout"].waitForExistence(timeout: 20))
    app.buttons["resume_workout"].tap()
    XCTAssertTrue(secondSet.waitForExistence(timeout: 20))
    XCTAssertTrue(secondSet.label.contains("Not recorded"))
    XCTAssertTrue(firstSet.label.contains("Skipped"))
  }

  @MainActor func testFinishedFocusKeepsWarmupCorrectionAvailable() throws {
    let app = launchFixture("finished_warmup")
    app.buttons["start_next_workout"].tap()
    let layout = app.segmentedControls["logging_layout"]
    XCTAssertTrue(layout.waitForExistence(timeout: 10))
    let addWarmup = app.buttons.matching(identifier: "Add warm-up").firstMatch
    reveal(addWarmup, in: app)
    addWarmup.tap()
    let setup = app.textFields["set_setup"]
    XCTAssertTrue(setup.waitForExistence(timeout: 5))
    setup.tap()
    setup.typeText("Warmup fixture dumbbells")
    app.buttons["set_convention"].tap()
    app.buttons["Pounds per dumbbell"].tap()
    app.swipeUp()
    app.textFields["set_load"].tap()
    app.textFields["set_load"].typeText("10")
    app.textFields["set_reps"].tap()
    app.textFields["set_reps"].typeText("5")
    let save = app.buttons["save_set"]
    reveal(save, in: app)
    save.tap()
    let warmup = app.buttons["set_incline_dumbbell_press_1_both_true"]
    XCTAssertTrue(warmup.waitForExistence(timeout: 10))
    let finish = app.buttons["Finish early"]
    reveal(finish, in: app)
    finish.tap()
    app.alerts.buttons["Finish early"].tap()
    let review = app.buttons["Review / correct saved sets"]
    reveal(review, in: app)
    review.tap()
    reveal(layout, in: app, upward: false)
    layout.buttons["Focus"].tap()
    let recordedWarmups = app.buttons["Recorded warm-ups"]
    reveal(recordedWarmups, in: app)
    recordedWarmups.tap()
    reveal(warmup, in: app)
    // XCTest can mark a row hittable while its center is behind the floating timer.
    let timer = app.buttons["tab_workout"]
    for _ in 0..<10 {
      if warmup.isHittable && warmup.frame.maxY < timer.frame.minY - 16 { break }
      app.swipeUp()
    }
    XCTAssertTrue(warmup.isHittable)
    XCTAssertLessThan(warmup.frame.maxY, timer.frame.minY - 16)
    XCTAssertTrue(warmup.label.contains("10 lb"))
    warmup.tap()
    XCTAssertTrue(setup.waitForExistence(timeout: 5))
    XCTAssertEqual(setup.value as? String, "Warmup fixture dumbbells")
    XCTAssertEqual(app.textFields["set_load"].value as? String, "10")
    XCTAssertEqual(app.textFields["set_reps"].value as? String, "5")
    app.buttons["Cancel"].tap()
  }

  @MainActor func testLargeTextTimerFitsSafeArea() throws {
    let app = launchFixture("large_timer", largerText: true)
    let start = app.buttons["start_next_workout"]
    reveal(start, in: app)
    start.tap()
    let timer = app.descendants(matching: .any).matching(identifier: "workout_timer_capsule")
      .firstMatch
    XCTAssertTrue(timer.waitForExistence(timeout: 10))
    XCTAssertGreaterThan(timer.frame.width, 0)
    XCTAssertLessThanOrEqual(timer.frame.width, app.frame.width)
    XCTAssertGreaterThanOrEqual(timer.frame.minX, app.frame.minX)
    XCTAssertLessThanOrEqual(timer.frame.maxX, app.frame.maxX)
    XCTAssertLessThanOrEqual(timer.frame.maxY, app.buttons["tab_workout"].frame.minY + 1)
    capture(app, "Accessibility XXXL timer safe area")
    let layout = app.segmentedControls["logging_layout"]
    reveal(layout.buttons["Focus"], in: app)
    layout.buttons["Focus"].tap()
    let rest = app.buttons.matching(
      NSPredicate(format: "label MATCHES %@", "Start [0-9]+s rest")
    ).firstMatch
    reveal(rest, in: app)
    rest.tap()
    let clear = app.buttons["Clear rest"]
    XCTAssertTrue(clear.waitForExistence(timeout: 5))
    XCTAssertTrue(clear.isHittable)
    XCTAssertLessThanOrEqual(timer.frame.width, app.frame.width)
    capture(app, "Accessibility XXXL running timer and reachable clear")
    clear.tap()
    XCTAssertFalse(app.buttons["Clear rest"].exists)
    XCTAssertTrue(timer.exists)
  }

  @MainActor func testDurationSaveCancelAndRestart() throws {
    let name = fixtureName("duration")
    let app = launchFixture(name, exact: true)
    app.buttons["duration_button"].tap()
    app.buttons["30 min"].tap()
    let save = app.buttons["Use 30 min"]
    reveal(save, in: app)
    save.tap()
    XCTAssertTrue(app.buttons["duration_button"].waitForExistence(timeout: 10))
    XCTAssertTrue(app.buttons["duration_button"].label.contains("30 Min"))
    app.buttons["duration_button"].tap()
    app.buttons["No time limit"].tap()
    app.buttons["Cancel"].tap()
    XCTAssertTrue(app.buttons["duration_button"].label.contains("30 Min"))
    app.terminate()
    app.launchArguments = ["--fixture-directory", name]
    app.launch()
    XCTAssertTrue(app.buttons["duration_button"].waitForExistence(timeout: 20))
    XCTAssertTrue(app.buttons["duration_button"].label.contains("30 Min"))
    app.buttons["duration_button"].tap()
    app.buttons["No time limit"].tap()
    let unlimited = app.buttons["Use no time limit"]
    reveal(unlimited, in: app)
    unlimited.tap()
    XCTAssertTrue(app.buttons["duration_button"].waitForExistence(timeout: 10))
    app.terminate()
    app.launch()
    XCTAssertTrue(app.buttons["duration_button"].waitForExistence(timeout: 20))
    app.buttons["duration_button"].tap()
    XCTAssertTrue(app.staticTexts["No time limit is saved."].waitForExistence(timeout: 5))
    capture(app, "Saved unlimited advisory duration")
  }

  @MainActor func testLastTrainedReviewGateAndLargeText() throws {
    let app = launchFixture("large_text", largerText: true)
    capture(app, "Next workout accessibility text")
    app.buttons["tab_history"].tap()
    app.segmentedControls["history_mode"].buttons["Last trained"].tap()
    let toggle = app.switches["Show last trained"]
    XCTAssertTrue(toggle.waitForExistence(timeout: 10))
    reveal(toggle, in: app)
    XCTAssertEqual(toggle.value as? String, "0")
    // A large Dynamic Type label can occupy most of the accessibility row.
    // Target the native switch at its trailing edge, not the label's center.
    toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
    let enabled = NSPredicate(format: "value == %@", "1")
    expectation(for: enabled, evaluatedWith: toggle)
    waitForExpectations(timeout: 5)
    let gate = app.staticTexts["Muscle mappings awaiting review"]
    XCTAssertTrue(gate.waitForExistence(timeout: 5))
    reveal(gate, in: app)
    capture(app, "Last trained mapping gate accessibility text")
    app.terminate()
    app.launchArguments.removeAll { $0 == "--reset-fixture" }
    app.launch()
    XCTAssertTrue(app.buttons["start_next_workout"].waitForExistence(timeout: 20))
    app.buttons["tab_history"].tap()
    app.segmentedControls["history_mode"].buttons["Last trained"].tap()
    XCTAssertTrue(toggle.waitForExistence(timeout: 10))
    XCTAssertEqual(toggle.value as? String, "1")
  }

  private func fixtureName(_ prefix: String) -> String {
    prefix + "_" + UUID().uuidString.replacingOccurrences(of: "-", with: "")
  }

  @MainActor private func launchFixture(
    _ prefix: String, exact: Bool = false, largerText: Bool = false
  ) -> XCUIApplication {
    let app = XCUIApplication()
    app.launchArguments = [
      "--fixture-directory", exact ? prefix : fixtureName(prefix), "--reset-fixture",
    ]
    if largerText {
      app.launchArguments += [
        "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL",
      ]
    }
    app.launch()
    XCTAssertTrue(app.buttons["start_next_workout"].waitForExistence(timeout: 20))
    return app
  }

  @MainActor private func reveal(
    _ element: XCUIElement, in app: XCUIApplication, upward: Bool = true
  ) {
    for _ in 0..<20 {
      if element.isHittable { break }
      if upward { app.swipeUp() } else { app.swipeDown() }
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
