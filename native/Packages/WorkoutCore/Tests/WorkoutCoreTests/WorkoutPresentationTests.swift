import WorkoutApplication
import WorkoutDomain
import XCTest

final class WorkoutPresentationTests: XCTestCase {
  private func log(
    _ id: String = "current", day: String = "monday", profile: String = "owner",
    version: String = ownerProgramVersion, at: TimeInterval = 1000
  ) -> ProgramLog {
    ProgramLog(
      programVersion: version, id: id, profile: profile, programId: day,
      startedAt: Date(timeIntervalSince1970: at), revision: 0, completedAt: nil, sets: [])
  }
  private func set(
    _ index: Int = 1, setup: String = "fixture", warmup: Bool = false,
    validity: SetValidity = .valid
  ) -> ProgramSet {
    ProgramSet(
      slot: "incline_dumbbell_press", index: index, side: .both,
      variant: "incline_dumbbell_press", setup: setup, convention: .perDumbbell,
      load: 20_000_000, reps: 8, rir: nil, validity: validity, warmup: warmup, skipped: false)
  }
  private func finished(_ source: ProgramLog, sets: [ProgramSet] = []) throws -> ProgramLog {
    var result = source
    for entry in sets { result = try result.record(entry) }
    return try result.finish(at: source.startedAt.addingTimeInterval(10), endEarly: true)
  }

  func testPickerConventionsAgreeWithValidationForEveryApprovedVariant() throws {
    for plan in ownerProgram {
      let source = log(day: plan.id)
      for exercise in source.exercises {
        XCTAssertTrue(manualLoadConventions(for: exercise, variant: "unknown").isEmpty)
        for variant in exercise.alternatives.isEmpty ? [exercise.id] : exercise.alternatives {
          let offered = manualLoadConventions(for: exercise, variant: variant)
          XCTAssertFalse(offered.isEmpty)
          for convention in LoadConvention.allCases {
            let entry = ProgramSet(
              slot: exercise.id, index: 1, side: exercise.eachSide ? .left : .both,
              variant: variant, setup: "fixture", convention: convention,
              load: convention == .bodyweight ? nil : 20_000_000, reps: 8, rir: nil,
              validity: .valid, warmup: false, skipped: false)
            if offered.contains(convention) {
              XCTAssertNoThrow(try source.record(entry), "\(variant): \(convention)")
            } else {
              XCTAssertThrowsError(try source.record(entry), "\(variant): \(convention)")
            }
          }
        }
      }
    }
  }

  func testWorkingSlotsInterleavePairedRoundsAndSidesWithoutCountingWarmups() throws {
    let source = try log().record(set(warmup: true))
    let slots = manualWorkingSlots(source)
    XCTAssertEqual(slots.count, 18)
    XCTAssertNil(slots[0].record(in: source))
    XCTAssertEqual(
      Array(slots[6..<10].map(\.id)),
      [
        "incline_machine_press_1_both", "chest_supported_row_1_both",
        "incline_machine_press_2_both", "chest_supported_row_2_both",
      ])
    let recorded = try source.record(set(validity: .unknown))
    XCTAssertEqual(slots[0].record(in: recorded)?.validity, .unknown)
    XCTAssertEqual(
      manualWorkingSlots(log(day: "friday")).filter {
        $0.exercise.id == "single_arm_cable_pulldown"
      }.map(\.id),
      [
        "single_arm_cable_pulldown_1_left", "single_arm_cable_pulldown_1_right",
        "single_arm_cable_pulldown_2_left", "single_arm_cable_pulldown_2_right",
        "single_arm_cable_pulldown_3_left", "single_arm_cable_pulldown_3_right",
      ])
  }

  func testNextPlanUsesProfileDraftEarlyFinishWrapAndDeterministicTies() throws {
    XCTAssertEqual(nextManualPlan([], profile: "owner").id, "monday")
    let monday = try finished(log("monday"))
    let foreign = try finished(log("foreign", day: "friday", profile: "other", at: 5000))
    XCTAssertEqual(nextManualPlan([foreign, monday], profile: "owner").id, "tuesday")
    let saturday = try finished(log("saturday", day: "saturday", at: 2000))
    XCTAssertEqual(nextManualPlan([monday, saturday], profile: "owner").id, "monday")
    let draft = log("draft", day: "wednesday", at: 500)
    XCTAssertEqual(nextManualPlan([saturday, draft], profile: "owner").id, "wednesday")
    let a = try finished(log("a", day: "tuesday"))
    let b = try finished(log("b", day: "friday"))
    XCTAssertEqual(nextManualPlan([b, a], profile: "owner").id, "wednesday")
    XCTAssertEqual(nextManualPlan([a, b], profile: "owner").id, "wednesday")
  }

  func testPreviousSetsRequireExactContextAndOnlyLatestFinishedWorkout() throws {
    let current = log(at: 10000)
    let older = try finished(log("older"), sets: [set()])
    let latest = try finished(log("latest", at: 2000), sets: [set(), set(2)])
    let unrelated = [
      try finished(log("foreign", profile: "other", at: 3000), sets: [set()]),
      try finished(log("legacy", version: legacyOwnerProgramVersion, at: 3000), sets: [set()]),
      try finished(log("setup", at: 3000), sets: [set(setup: "different")]),
      try finished(log("future", at: 11000), sets: [set()]),
      try finished(log("invalid", at: 3000), sets: [set(validity: .invalid)]),
      try log("draft", at: 3000).record(set()),
      try finished(current, sets: [set()]),
    ]
    let points = previousMatchingSets(
      for: set(), in: current, history: unrelated + [latest, older])
    XCTAssertEqual(points.map { $0.log.id }, ["latest", "latest"])
    XCTAssertEqual(points.map { $0.set.index }, [1, 2])
    let unicode = try finished(log("unicode"), sets: [set(setup: "café")])
    XCTAssertTrue(
      previousMatchingSets(
        for: set(setup: "cafe\u{0301}"), in: current, history: [unicode]
      ).isEmpty)
  }

  func testPreviousExerciseHistoryPreservesSetupContextsAndScopesHistoricalEvidence() throws {
    let current = log(at: 10000)
    let exercise = try XCTUnwrap(current.exercises.first)
    let first = try finished(log("first"), sets: [set(setup: "machine_a")])
    let second = try finished(log("second", at: 2000), sets: [set(setup: "machine_b")])
    let later = try finished(log("later", at: 3000), sets: [set(2, setup: "machine_a")])
    let excluded = [
      try finished(log("foreign", profile: "other", at: 4000), sets: [set()]),
      try finished(log("legacy", version: legacyOwnerProgramVersion, at: 4000), sets: [set()]),
      try finished(log("same_time", at: 10000), sets: [set()]),
      try finished(log("future", at: 11000), sets: [set()]),
      try finished(log("invalid", at: 4000), sets: [set(validity: .invalid)]),
      try finished(log("warmup", at: 4000), sets: [set(warmup: true)]),
      try log("draft", at: 4000).record(set()),
      try finished(current, sets: [set()]),
    ]
    let history = excluded + [second, later, first]
    let series = previousExerciseHistory(for: exercise, in: current, history: history)
    XCTAssertEqual(series.map { $0.key.setup }, ["machine_a", "machine_b"])
    XCTAssertEqual(series[0].points.map { $0.log.id }, ["first", "later"])
    XCTAssertEqual(series[1].points.map { $0.log.id }, ["second"])
    let otherSlot = try XCTUnwrap(current.exercises.last)
    XCTAssertTrue(previousExerciseHistory(for: otherSlot, in: current, history: history).isEmpty)
    XCTAssertTrue(
      previousExerciseHistory(for: exercise, in: log(day: "friday", at: 10000), history: history)
        .isEmpty)
    XCTAssertTrue(previousExerciseHistory(for: exercise, in: current, history: []).isEmpty)
  }

  func testHistoryOrderingRetainsMicrosecondsWhenFoundationDatesRoundTogether() throws {
    let earlier = try ManualTimestamp(parsing: "9999-01-01T00:00:00.000001Z")
    let later = try ManualTimestamp(parsing: "9999-01-01T00:00:00.000002Z")
    XCTAssertEqual(earlier.date, later.date)
    XCTAssertLessThan(earlier.microsecondsSince1970, later.microsecondsSince1970)
    func exact(_ id: String, day: String, timestamp: ManualTimestamp) throws -> ProgramLog {
      var json = try ManualJSON.decode(finished(log(id, day: day)).encodedJSON())
      json["startedAt"] = timestamp.encoded
      json["completedAt"] = timestamp.encoded
      return try ProgramLog(json: json)
    }
    let olderPlan = try exact("a", day: "monday", timestamp: earlier)
    let newerPlan = try exact("z", day: "tuesday", timestamp: later)
    XCTAssertEqual(nextManualPlan([olderPlan, newerPlan], profile: "owner").id, "wednesday")
    var pastJSON = try ManualJSON.decode(finished(log("past"), sets: [set()]).encodedJSON())
    pastJSON["startedAt"] = earlier.encoded
    pastJSON["completedAt"] = earlier.encoded
    let past = try ProgramLog(json: pastJSON)
    let current = try exact("current", day: "monday", timestamp: later)
    XCTAssertEqual(
      previousMatchingSets(for: set(), in: current, history: [past]).map { $0.log.id }, ["past"])
    XCTAssertEqual(
      previousExerciseHistory(for: current.exercises[0], in: current, history: [past]).count, 1)
  }

  func testLastTrainedNeedsReviewedMappingAndCountsLocalCalendarDays() throws {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "America/Chicago"))
    let now = try XCTUnwrap(
      calendar.date(from: DateComponents(year: 2026, month: 3, day: 9, hour: 0, minute: 5)))
    let end = try XCTUnwrap(
      calendar.date(from: DateComponents(year: 2026, month: 3, day: 8, hour: 23, minute: 55)))
    let source = try finished(log(at: end.timeIntervalSince1970 - 10), sets: [set()])
    XCTAssertTrue(
      lastTrainedAreas([source], profile: "owner", reviewedAreas: [:], now: now, calendar: calendar)
        .isEmpty)
    let map = ["incline_dumbbell_press": ["fixture_area"]]
    let foreign = try finished(
      log("foreign", profile: "other", at: now.timeIntervalSince1970 - 20), sets: [set()])
    let warmup = try finished(
      log("warmup", at: now.timeIntervalSince1970 - 20), sets: [set(warmup: true)])
    let future = try finished(log("future", at: now.timeIntervalSince1970 + 20), sets: [set()])
    let result = lastTrainedAreas(
      [foreign, warmup, future, source, log()], profile: "owner", reviewedAreas: map, now: now,
      calendar: calendar)
    XCTAssertEqual(result.map(\.id), ["fixture_area"])
    XCTAssertEqual(result.first?.days, 1)
    XCTAssertEqual(result.first?.log.id, source.id)
  }
}

@MainActor final class PresentationSetupControllerTests: XCTestCase {
  private final class Repository: TrainingSetupRepository {
    var stored: TrainingSetup?
    func load(_ profileId: String) throws -> TrainingSetup? { stored }
    func save(_ setup: TrainingSetup, expectedRevision: Int, actionId: String) throws {
      try validateSetupTransition(stored, setup)
      stored = setup
    }
  }
  func testDurationCanBeClearedAndExclusionPreservesSavedPreferences() async throws {
    let repository = Repository()
    let controller = TrainingSetupController(repository: repository)
    XCTAssertFalse(controller.saveDuration(30))
    XCTAssertFalse(controller.excludeVariation("incline_dumbbell_press"))
    controller.load()
    XCTAssertTrue(controller.savePreferences(days: [1, 3], minutes: "45", exclusions: []))
    XCTAssertTrue(controller.saveDuration(nil))
    XCTAssertNil(controller.saved?.preferredMinutes)
    XCTAssertEqual(controller.saved?.trainingDays, [1, 3])
    XCTAssertTrue(controller.excludeVariation("incline_dumbbell_press"))
    XCTAssertTrue(controller.excludeVariation("incline_dumbbell_press"))
    XCTAssertEqual(controller.saved?.excludedVariations, ["incline_dumbbell_press"])
    XCTAssertNil(controller.saved?.preferredMinutes)
    let saved = controller.saved
    XCTAssertFalse(controller.saveDuration(0))
    XCTAssertFalse(controller.excludeVariation("unknown"))
    XCTAssertEqual(controller.saved, saved)
    XCTAssertTrue(controller.saveDuration(75))
    XCTAssertEqual(controller.saved?.excludedVariations, ["incline_dumbbell_press"])
    XCTAssertEqual(controller.saved?.preferredMinutes, 75)
  }

  func testPreferencesPreserveExplicitNoTimeLimitAndBlankClearsExistingDuration() async throws {
    let repository = Repository()
    let controller = TrainingSetupController(repository: repository)
    controller.load()
    XCTAssertTrue(controller.saveDuration(45))
    XCTAssertTrue(controller.saveDuration(nil))
    XCTAssertTrue(controller.savePreferences(days: [2, 4], minutes: "", exclusions: []))
    XCTAssertNil(controller.saved?.preferredMinutes)
    XCTAssertEqual(controller.saved?.trainingDays, [2, 4])
    XCTAssertTrue(controller.saveDuration(60))
    XCTAssertTrue(
      controller.savePreferences(
        days: [1], minutes: " \n\t ", exclusions: ["incline_dumbbell_press"]))
    XCTAssertNil(controller.saved?.preferredMinutes)
    XCTAssertEqual(controller.saved?.trainingDays, [1])
    XCTAssertEqual(controller.saved?.excludedVariations, ["incline_dumbbell_press"])
  }

  func testPreferenceMinutesRejectMalformedAndOutOfRangeValuesWithoutChangingSavedSetup()
    async throws
  {
    let repository = Repository()
    let controller = TrainingSetupController(repository: repository)
    controller.load()
    XCTAssertTrue(controller.savePreferences(days: [1], minutes: "30", exclusions: []))
    let saved = controller.saved
    for value in [
      "0", "-1", "+30", "1.5", "1e2", "30 minutes", "３０", "2147483648",
      String(repeating: "9", count: 30),
    ] {
      XCTAssertFalse(controller.savePreferences(days: [2], minutes: value, exclusions: []), value)
      XCTAssertEqual(controller.saved, saved, value)
      XCTAssertEqual(repository.stored, saved, value)
    }
    XCTAssertTrue(controller.savePreferences(days: [1], minutes: " 1 ", exclusions: []))
    XCTAssertEqual(controller.saved?.preferredMinutes, 1)
    XCTAssertTrue(controller.savePreferences(days: [1], minutes: "2147483647", exclusions: []))
    XCTAssertEqual(controller.saved?.preferredMinutes, 2_147_483_647)
  }
}
