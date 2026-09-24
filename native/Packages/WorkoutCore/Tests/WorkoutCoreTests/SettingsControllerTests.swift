import WorkoutApplication
import WorkoutDomain
import WorkoutPersistence
import XCTest

@MainActor final class SettingsControllerTests: XCTestCase {
  private final class Repository: TrainingSetupRepository {
    var stored: TrainingSetup?
    var failAcknowledgement = false
    var actionIds: [String] = []
    func load(_ profileId: String) throws -> TrainingSetup? {
      if failAcknowledgement {
        failAcknowledgement = false
        throw SetupException("fixture_failed_readback")
      }
      return stored
    }
    func save(_ setup: TrainingSetup, expectedRevision: Int, actionId: String) throws {
      actionIds.append(actionId)
      if stored?.encode() == setup.encode() { return }
      try validateSetupTransition(stored, setup)
      stored = setup
    }
  }
  func testIntakeUncertainAcknowledgementLocksAndRetriesSameAction() async throws {
    let repository = Repository()
    let at = Date(timeIntervalSince1970: 1_790_000_000)
    let controller = TrainingSetupController(repository: repository, now: { at })
    controller.load()
    let report = try ReportedWorkingSetup(
      id: "report", sourceReference: "fixture", recordedAt: at, sessionId: "monday",
      slotId: "incline_dumbbell_press", variation: "incline_dumbbell_press",
      convention: .perDumbbell, load: 20_000_000, sets: 3, minReps: nil, maxReps: nil, minRir: nil,
      maxRir: nil, eachSide: false)
    repository.failAcknowledgement = true
    XCTAssertFalse(controller.saveIntake(reports: [report]))
    XCTAssertTrue(controller.locked)
    XCTAssertTrue(controller.canRetry)
    XCTAssertFalse(controller.savePreferences(days: [1], minutes: "30", exclusions: []))
    XCTAssertTrue(controller.retry())
    XCTAssertFalse(controller.locked)
    XCTAssertEqual(repository.actionIds.count, 2)
    XCTAssertEqual(repository.actionIds.first, repository.actionIds.last)
    XCTAssertEqual(controller.saved?.schemaVersion, 2)
    XCTAssertEqual(controller.saved?.reportedWork, [report])
    XCTAssertEqual(controller.saved?.equipment, [])
    XCTAssertEqual(controller.saved?.startingLoads, [])
    XCTAssertFalse(controller.saveIntake())
    XCTAssertEqual(controller.saved?.revision, 0)
    XCTAssertTrue(controller.savePreferences(days: [1, 2], minutes: "60", exclusions: []))
    XCTAssertEqual(controller.saved?.reportedWork, [report])
    XCTAssertEqual(controller.saved?.schemaVersion, 2)
  }
  func testPreparationControllerPreservesDraftAndRejectsImplicitBaseline() async throws {
    let repository = Repository()
    let at = Date(timeIntervalSince1970: 1_790_000_000)
    let controller = TrainingSetupController(repository: repository, now: { at })
    controller.load()
    XCTAssertFalse(
      controller.saveMachine(
        label: "Fixture", sessionId: "monday", slotId: "incline_dumbbell_press",
        variation: "incline_dumbbell_press", convention: .perDumbbell, workingSettings: "20",
        rehearsalSettings: "10", startingWeight: "20", confirmed: false))
    XCTAssertNil(controller.saved)
    XCTAssertTrue(
      controller.saveMachine(
        label: "Fixture", sessionId: "monday", slotId: "incline_dumbbell_press",
        variation: "incline_dumbbell_press", convention: .perDumbbell, workingSettings: "20",
        rehearsalSettings: "10", startingWeight: "", confirmed: false))
    XCTAssertEqual(controller.saved?.equipment.first?.confirmed, false)
    XCTAssertTrue(controller.saved?.startingLoads.isEmpty == true)
    let id = try XCTUnwrap(controller.saved?.equipment.first?.id)
    XCTAssertTrue(
      controller.saveMachine(
        existingId: id, label: "Fixture", sessionId: "monday", slotId: "incline_dumbbell_press",
        variation: "incline_dumbbell_press", convention: .perDumbbell, workingSettings: "20, 30",
        rehearsalSettings: "10", startingWeight: "20", confirmed: true))
    XCTAssertEqual(controller.saved?.equipment.first?.revision, 1)
    let baseline = try XCTUnwrap(controller.saved?.startingLoads.first)
    XCTAssertTrue(controller.saved?.baselineIsCurrent(baseline) == true)
  }
}
