import XCTest

final class OnboardingFlowTests: XCTestCase {
  @MainActor func testFreshProfileAutomaticallyOpensOnboardingInIsolatedStore() {
    let app = XCUIApplication()
    let fixture = "onboarding_fresh_" + UUID().uuidString
    app.launchArguments = ["--fixture-directory", fixture, "--reset-fixture", "--onboarding-flow"]
    app.launch()
    XCTAssertTrue(app.staticTexts["Local, personal, explainable"].waitForExistence(timeout: 10))
    app.buttons["Save and continue"].tap()
    XCTAssertTrue(app.descendants(matching: .any)["onboarding_goal"].waitForExistence(timeout: 5))
    app.buttons["Pause"].tap()
    app.terminate()
    app.launchArguments = ["--fixture-directory", fixture, "--onboarding-flow"]
    app.launch()
    XCTAssertTrue(app.buttons["personalized_setup"].waitForExistence(timeout: 10))
    app.buttons["personalized_setup"].tap()
    XCTAssertTrue(app.staticTexts["Goals and experience"].waitForExistence(timeout: 5))
  }
  @MainActor func testSetupProgressSurvivesRestartWithoutUnlockingGeneration() {
    let app = XCUIApplication()
    let fixture = "onboarding_" + UUID().uuidString
    app.launchArguments = ["--fixture-directory", fixture, "--reset-fixture"]
    app.launch()
    XCTAssertTrue(app.buttons["personalized_setup"].waitForExistence(timeout: 10))
    app.buttons["personalized_setup"].tap()
    XCTAssertTrue(app.staticTexts["Local, personal, explainable"].waitForExistence(timeout: 5))
    app.buttons["Save and continue"].tap()
    XCTAssertTrue(app.staticTexts["Goals and experience"].waitForExistence(timeout: 5))
    app.buttons["Pause"].tap()
    app.terminate()
    app.launchArguments = ["--fixture-directory", fixture]
    app.launch()
    app.buttons["personalized_setup"].tap()
    XCTAssertTrue(app.staticTexts["Goals and experience"].waitForExistence(timeout: 5))
    XCTAssertTrue(app.descendants(matching: .any)["onboarding_goal"].exists)
  }
}
