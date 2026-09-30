import WorkoutApplication
import WorkoutDomain
import WorkoutPersistence
import XCTest

final class ManualWorkoutFlowTests: XCTestCase {
  private func log(_ day: String = "monday", id: String = "fixture") -> ProgramLog {
    ProgramLog(
      id: id, profile: "fixture", programId: day, startedAt: .now,
      revision: 0, completedAt: nil, sets: [])
  }
  private func set(
    _ exercise: ProgramExercise, index: Int = 1, side: LoggedSide = .both,
    variant: String? = nil, convention: LoadConvention? = nil, warmup: Bool = false,
    skipped: Bool = false, setup: String = ""
  ) -> ProgramSet {
    let variant = variant ?? exercise.alternatives.first ?? exercise.id
    let convention = convention ?? manualLoadConventions(variant: variant)[0]
    return ProgramSet(
      slot: exercise.id, index: index, side: side, variant: variant,
      setup: setup, convention: convention,
      load: skipped || convention == .bodyweight ? nil : 12_345_678,
      reps: skipped ? nil : 8, rir: nil, validity: skipped ? .unknown : .valid,
      warmup: warmup, skipped: skipped)
  }
  func testEveryOfferedMeasurementSavesAndIncompatibleMeasurementsAreRejected() throws {
    var seen = Set<LoadConvention>()
    for plan in ownerProgram {
      let source = log(plan.id)
      for exercise in plan.exercises {
        for variant in exercise.alternatives.isEmpty ? [exercise.id] : exercise.alternatives {
          let allowed = manualLoadConventions(variant: variant)
          for convention in LoadConvention.allCases {
            let entry = set(
              exercise, side: exercise.eachSide ? .left : .both,
              variant: variant, convention: convention)
            if allowed.contains(convention) {
              seen.insert(convention)
              let recorded = try source.record(entry)
              XCTAssertEqual(try ProgramLog(jsonString: recorded.encodedJSON()), recorded)
              XCTAssertEqual(recorded.sets[0].setup, "")
            } else {
              XCTAssertThrowsError(try source.record(entry))
            }
          }
        }
      }
    }
    XCTAssertEqual(seen, Set(LoadConvention.allCases))
    XCTAssertEqual(manualLoadConventions(variant: "incline_dumbbell_press"), [.perDumbbell])
    XCTAssertEqual(manualLoadConventions(variant: "unassisted_pull_up"), [.bodyweight])
    XCTAssertEqual(manualLoadConventions(variant: "assisted_machine_pull_up"), [.assistance])
  }
  func testCurrentTargetAdvancesInPairedRoundsAndBothSides() throws {
    var source = log()
    let expected = source.plan.blocks.flatMap { block -> [String] in
      if block.isSuperset {
        let a = block.exercises[0].id
        let b = block.exercises[1].id
        return [a, b, a, b, a, b]
      }
      return Array(repeating: block.exercises[0].id, count: block.exercises[0].sets)
    }
    XCTAssertEqual(source.workingTargets.map { $0.exercise.id }, expected)
    for target in source.workingTargets {
      XCTAssertEqual(source.currentTarget, target)
      source = try source.record(set(target.exercise, index: target.index, side: target.side))
    }
    XCTAssertNil(source.currentTarget)
    XCTAssertNil(try source.finish(at: .now).currentTarget)
    let friday = log("friday")
    let unilateral = friday.workingTargets.filter { $0.exercise.eachSide }
    XCTAssertEqual(unilateral.map(\.side), [.left, .right, .left, .right, .left, .right])
    XCTAssertEqual(unilateral.map(\.index), [1, 1, 2, 2, 3, 3])
  }
  func testWarmupsCorrectionsAndOutOfOrderRecordsDoNotSkipMissingTargets() throws {
    var source = log()
    let exercise = source.exercises[0]
    source = try source.record(set(exercise, warmup: true))
    source = try source.record(set(exercise, index: 3))
    XCTAssertEqual(source.currentTarget?.index, 1)
    source = try source.record(set(exercise, skipped: true))
    XCTAssertEqual(source.currentTarget?.index, 2)
    source = try source.record(set(exercise, skipped: true))
    XCTAssertEqual(source.currentTarget?.index, 2)
    XCTAssertNil(try source.finish(at: .now, endEarly: true).currentTarget)
  }
  func testPreviousDataStaysWithinExerciseSideAndCategoryAndExcludesSkips() throws {
    var source = log("friday")
    let exercise = try XCTUnwrap(source.exercises.first { $0.eachSide })
    XCTAssertNil(source.previousSet(slot: exercise.id, index: 1, side: .left, warmup: false))
    source = try source.record(set(exercise, side: .left))
    source = try source.record(set(exercise, index: 2, side: .left, skipped: true))
    source = try source.record(set(exercise, side: .right, warmup: true))
    XCTAssertEqual(
      source.previousSet(slot: exercise.id, index: 3, side: .left, warmup: false)?.index, 1)
    XCTAssertNil(source.previousSet(slot: exercise.id, index: 3, side: .right, warmup: false))
    XCTAssertNil(source.previousSet(slot: "missing", index: 3, side: .left, warmup: false))
    XCTAssertNil(source.previousSet(slot: exercise.id, index: 0, side: .left, warmup: false))
    XCTAssertEqual(
      source.previousSet(slot: exercise.id, index: 2, side: .right, warmup: true)?.load, 12_345_678)
  }
  func testMissingSetupPersistsWithoutRewritingLegacyLabelsOrJoiningDifferentSessions() throws {
    let repository = try SqliteProgramLogRepository(path: ":memory:")
    defer { try? repository.close() }
    let first = log(id: "first")
    let second = log(id: "second")
    let a = try first.record(set(first.exercises[0])).finish(at: .now, endEarly: true)
    let b = try second.record(set(second.exercises[0])).finish(at: .now, endEarly: true)
    XCTAssertEqual(exerciseHistory([a, b]).count, 2)
    let start = log()
    try repository.write(start, expectedRevision: -1, actionId: "start")
    let legacy = try start.record(set(start.exercises[0], setup: "Existing label"))
    try repository.write(legacy, expectedRevision: 0, actionId: "legacy")
    let updated = try legacy.record(set(start.exercises[0], index: 2))
    try repository.write(updated, expectedRevision: 1, actionId: "new")
    let reloaded = try XCTUnwrap(repository.load("fixture").first)
    XCTAssertEqual(reloaded.sets.map(\.setup), ["Existing label", ""])
    XCTAssertFalse(reloaded.recommendationEligible)
  }
  @MainActor func testConfirmedNormalFinishReturnsHomeAndHistoryRemainsEditable() async throws {
    let controller = ProgramLogController(
      repository: try SqliteProgramLogRepository(path: ":memory:"))
    let started = await controller.start("monday")
    XCTAssertTrue(started)
    let source = try XCTUnwrap(controller.selected)
    let incomplete = await controller.finish()
    XCTAssertFalse(incomplete)
    XCTAssertEqual(controller.selectedID, source.id)
    for target in source.workingTargets {
      let recorded = await controller.record(
        set(target.exercise, index: target.index, side: target.side, skipped: true))
      XCTAssertTrue(recorded)
    }
    let finished = await controller.finish()
    XCTAssertTrue(finished)
    XCTAssertNil(controller.selectedID)
    XCTAssertTrue(controller.logs[0].completed)
    await controller.load()
    XCTAssertNil(controller.selectedID)
    controller.select(source.id)
    let corrected = await controller.record(set(source.exercises[0]))
    XCTAssertTrue(corrected)
    XCTAssertEqual(controller.selectedID, source.id)
  }
  func testReminderDaysAndTimeAreExplicitAndValidated() throws {
    let schedule = try WorkoutReminderSchedule(weekdays: [6, 2], hour: 18, minute: 30)
    XCTAssertEqual(schedule.dates.map(\.weekday), [2, 6])
    XCTAssertTrue(
      schedule.dates.allSatisfy { $0.hour == 18 && $0.minute == 30 && $0.timeZone == nil })
    XCTAssertNoThrow(try WorkoutReminderSchedule(weekdays: [1, 7], hour: 0, minute: 0))
    XCTAssertNoThrow(try WorkoutReminderSchedule(weekdays: [7], hour: 23, minute: 59))
    for days: Set<Int> in [[], [0], [8], [1, 8]] {
      XCTAssertThrowsError(try WorkoutReminderSchedule(weekdays: days, hour: 12, minute: 0))
    }
    XCTAssertThrowsError(try WorkoutReminderSchedule(weekdays: [1], hour: 24, minute: 0))
    XCTAssertThrowsError(try WorkoutReminderSchedule(weekdays: [1], hour: 12, minute: 60))
    XCTAssertThrowsError(try WorkoutReminderSchedule(weekdays: [1], hour: -1, minute: -1))
  }
}
