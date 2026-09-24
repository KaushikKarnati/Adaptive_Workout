import Foundation
import WorkoutApplication
import WorkoutDomain
import WorkoutPersistence
import XCTest

final class SavedWorkoutServiceTests: XCTestCase {
  private let date = Date(timeIntervalSince1970: 1_728_000_000)
  private func prepared() throws -> (SqliteRecommendationHistoryRepository, SavedWorkoutService) {
    let repository = try SqliteRecommendationHistoryRepository(path: ":memory:")
    let target = try SetTarget(
      index: 1, side: .both, warmup: false, load: 20_000_000, minReps: 6, maxReps: 10, minRir: 2,
      maxRir: 3, restSeconds: 120)
    let slot = try RecommendedSlot(
      id: "press", exerciseId: "incline_dumbbell_press", blockId: "block", setupId: "machine",
      setupRevision: 0, baselineReference: "baseline", convention: .perDumbbell, unilateral: false,
      targets: [target])
    let plan = try RecommendationSnapshot(
      id: "plan", profile: "synthetic", programId: "program", programVersion: "v1",
      sessionTemplate: "monday", ruleVersion: "v1", catalogVersion: "v1",
      catalogDigest: String(repeating: "a", count: 64), createdAt: date, requestedDate: date,
      timezone: "UTC", historyRevision: 0,
      inputRevisions: Dictionary(
        uniqueKeysWithValues: [
          "profile", "equipment", "baseline", "constraints", "safety", "catalogSchema", "taxonomy",
        ].map { ($0, 0) }), evidence: [:], status: .ready, reasons: ["fixture"], slots: [slot],
      walkSeconds: 300, preferredMinutes: 60, estimatedSeconds: nil)
    try repository.saveRecommendation(plan, actionId: "recommend")
    let occurrence = try GeneratedOccurrence(
      id: "occurrence", profile: "synthetic", recommendationId: "plan", sequence: 0, revision: 0,
      startedAt: date.addingTimeInterval(10), updatedAt: date.addingTimeInterval(10), endedAt: nil,
      status: .active, sets: [], stoppedSlots: [])
    try repository.saveOccurrence(
      occurrence, expectedRevision: -1, expectedHistoryRevision: 0, actionId: "start")
    return (repository, SavedWorkoutService(repository))
  }
  func testResumptionCorrectionsTerminalRetryAndCalendarAdvance() throws {
    let (repository, service) = try prepared()
    XCTAssertEqual(try service.resume("synthetic")?.prescription.id, "plan")
    let record = ProgramSet(
      slot: "press", index: 1, side: .both, variant: "incline_dumbbell_press", setup: "machine",
      convention: .perDumbbell, load: 20_000_000, reps: 8, rir: 2, validity: .valid, warmup: false,
      skipped: false)
    let action = try service.prepareSet(
      profile: "synthetic", occurrenceId: "occurrence", set: record,
      at: date.addingTimeInterval(20), actionId: "set")
    XCTAssertEqual(try service.commit(action).occurrence.revision, 1)
    XCTAssertEqual(try service.commit(action).occurrence.revision, 1)
    let finish = try service.prepareFinish(
      profile: "synthetic", occurrenceId: "occurrence", endEarly: false,
      at: date.addingTimeInterval(30), actionId: "finish")
    XCTAssertEqual(try service.commit(finish).occurrence.status, .completed)
    XCTAssertEqual(try service.commit(finish).occurrence.status, .completed)
    XCTAssertNil(try service.resume("synthetic"))
    XCTAssertEqual(try repository.load("synthetic").revision, 3)
    let next = try service.nextSession(
      profile: "synthetic", programId: "program", orderedSessionIds: ["monday", "tuesday"],
      trainingWeekdays: [1, 2, 3, 4, 5, 6, 7], requestedDate: date,
      civilDateOfEnd: { _ in self.date })
    XCTAssertEqual(next.sessionId, "tuesday")
    XCTAssertEqual(next.date, date.addingTimeInterval(86400))
    XCTAssertThrowsError(
      try service.nextSession(
        profile: "synthetic", programId: "program", orderedSessionIds: ["monday", "tuesday"],
        trainingWeekdays: [1], requestedDate: date,
        civilDateOfEnd: { _ in self.date.addingTimeInterval(1) }))
  }
  func testEarlyFinishAndOtherProgramActive() throws {
    let (_, service) = try prepared()
    let other = try service.nextSession(
      profile: "synthetic", programId: "different", orderedSessionIds: ["monday"],
      trainingWeekdays: [1], requestedDate: date, civilDateOfEnd: { _ in self.date })
    XCTAssertEqual(other.reasonCode, "other_program_active")
    XCTAssertThrowsError(
      try service.prepareFinish(
        profile: "synthetic", occurrenceId: "occurrence", endEarly: false,
        at: date.addingTimeInterval(20), actionId: "finish"))
    let early = try service.prepareFinish(
      profile: "synthetic", occurrenceId: "occurrence", endEarly: true,
      at: date.addingTimeInterval(20), actionId: "early")
    XCTAssertEqual(try service.commit(early).occurrence.status, .endedEarly)
    XCTAssertThrowsError(
      try service.prepareFinish(
        profile: "synthetic", occurrenceId: "missing", endEarly: true, at: date, actionId: "missing"
      ))
    XCTAssertNil(try service.resume("other_profile"))
  }
}
