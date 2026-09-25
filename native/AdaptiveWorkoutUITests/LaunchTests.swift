import XCTest

final class LaunchTests: XCTestCase {
  @MainActor func testAppLaunchesIntoWorkoutShell() {
    let app = XCUIApplication()
    let name = "launch_" + UUID().uuidString.replacingOccurrences(of: "-", with: "")
    app.launchArguments = ["--fixture-directory", name, "--reset-fixture"]
    app.launch()

    XCTAssertTrue(app.buttons["start_monday"].waitForExistence(timeout: 20))
    XCTAssertTrue(app.tabBars.buttons["Workout"].exists)
    XCTAssertTrue(app.tabBars.buttons["Settings"].exists)
  }
}
