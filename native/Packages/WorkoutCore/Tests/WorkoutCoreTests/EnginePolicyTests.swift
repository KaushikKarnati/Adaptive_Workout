import Foundation
import XCTest

@testable import WorkoutDomain

final class EnginePolicyTests: XCTestCase {
  let policy = LoadProgressionPolicy()
  func context(
    profile: String = "owner", slot: String = "press", setup: String = "machine1",
    unilateral: Bool = false, kind: ProgressionLoadKind = .external, min: Int = 8, max: Int = 12
  ) -> ProgressionContext {
    .init(
      profileId: profile, slotId: slot, exerciseId: "fixture_press", setupId: setup,
      loadConventionId: "displayed_pounds", setCount: 3, minReps: min, maxReps: max,
      unilateral: unilateral, loadKind: kind)
  }
  func exposure(
    _ sequence: Int, context: ProgressionContext? = nil, reps: Int? = 12, rir: Int? = 2,
    valid: Bool? = true, completed: Bool = true, correctedOut: Bool = false,
    load: Int? = 50_000_000, sets: [ProgressionSet]? = nil, id: String? = nil, date: Date? = nil
  ) -> ProgressionExposure {
    let scope = context ?? self.context()
    let generatedSets = (1...scope.setCount).flatMap { index in
      (scope.unilateral ? [SetSide.left, .right] : [.bilateral]).map { side in
        ProgressionSet(
          index: index, side: side, microPounds: load, reps: reps, rir: rir, valid: valid)
      }
    }
    return .init(
      id: id ?? "session_\(sequence)", sequence: sequence,
      occurredAt: date ?? Date(timeIntervalSince1970: Double(sequence * 86400)), context: scope,
      completed: completed, correctedOut: correctedOut, sets: sets ?? generatedSets)
  }
  func evaluate(
    history: [ProgressionExposure]? = nil,
    loads: [Int] = [45_000_000, 47_500_000, 50_000_000, 52_500_000, 55_000_000],
    context: ProgressionContext? = nil, baselineContext: ProgressionContext? = nil,
    gate: ProgressionGate? = .permitted, load: Int = 50_000_000, missingBaseline: Bool = false
  ) -> LoadProgressionResult {
    let scope = context ?? self.context()
    return policy.evaluate(
      .init(
        context: scope, gate: gate,
        baseline: missingBaseline
          ? nil : .init(context: baselineContext ?? scope, microPounds: load),
        availableLoadsMicroPounds: loads, history: history ?? [exposure(1), exposure(2)]))
  }
  func testExactIncreaseAndReductionBoundaries() {
    let result = evaluate()
    XCTAssertEqual(result.action, .increase)
    XCTAssertEqual(result.candidateMicroPounds, 52_500_000)
    XCTAssertEqual(result.evidenceIds, ["session_1", "session_2"])
    XCTAssertEqual(result.ruleSetVersion, "owner-program-v1")
    XCTAssertEqual(
      evaluate(loads: [50_000_000, 52_500_001]).reasonCode, "increment_above_five_percent")
    XCTAssertEqual(evaluate(loads: [50_000_000]).reasonCode, "no_higher_load")
    for (lower, action) in [(45_000_000, ProgressionAction.decrease), (44_999_999, .blocked)] {
      XCTAssertEqual(
        evaluate(
          history: [exposure(1, reps: 7), exposure(2, reps: 7)], loads: [lower, 50_000_000]
        ).action, action)
    }
    XCTAssertEqual(
      evaluate(history: [exposure(1, rir: 1), exposure(2, rir: 0)], loads: [50_000_000]).reasonCode,
      "baseline_review_required")
    XCTAssertEqual(
      evaluate(history: [exposure(1, rir: 1), exposure(2, rir: 1)]).candidateMicroPounds, 47_500_000
    )
    XCTAssertTrue(engineProductLE(Int.max, 100, Int.max, 100))
    XCTAssertFalse(engineProductLE(Int.max, 100, Int.max, 5))
    XCTAssertFalse(engineProductLE(-1, 100, Int.max, 100))
  }
  func testEvidenceStreakAndReasons() {
    for history in [[], [exposure(1)]] {
      XCTAssertEqual(evaluate(history: history).reasonCode, "insufficient_progression_streak")
    }
    XCTAssertEqual(
      evaluate(history: [exposure(1), exposure(2, rir: 1)]).reasonCode, "effort_target_not_met")
    XCTAssertEqual(
      evaluate(history: [exposure(1), exposure(2, reps: 11)]).reasonCode, "rep_ceiling_not_met")
    XCTAssertEqual(
      evaluate(history: [exposure(1, reps: 13), exposure(2, rir: 4)]).action, .increase)
    XCTAssertEqual(evaluate(history: [exposure(1, reps: 8), exposure(2, reps: 8)]).action, .hold)
    XCTAssertEqual(evaluate(history: [exposure(1), exposure(2, reps: 7)]).action, .hold)
    let cases = [
      exposure(2, completed: false), exposure(2, correctedOut: true), exposure(2, rir: nil),
      exposure(2, rir: -1), exposure(2, valid: false), exposure(2, valid: nil),
      exposure(2, reps: -1), exposure(2, reps: nil), exposure(2, load: nil),
      exposure(2, load: 45_000_000), exposure(2, context: context(setup: "machine2")),
      exposure(2, sets: []), exposure(2, sets: Array(repeating: exposure(1).sets[0], count: 3)),
      exposure(2, sets: Array(exposure(1).sets.prefix(2))),
      exposure(
        2,
        sets: [
          .init(
            index: 1, side: .bilateral, microPounds: 50_000_000, reps: 12, rir: 2, valid: true,
            working: false)
        ]),
    ]
    for entry in cases {
      XCTAssertEqual(evaluate(history: [exposure(1), entry]).reasonCode, "insufficient_evidence")
    }
    let interrupted = evaluate(history: [exposure(1), exposure(2, completed: false), exposure(3)])
    XCTAssertEqual(interrupted.reasonCode, "insufficient_evidence")
    XCTAssertEqual(interrupted.evidenceIds, ["session_2", "session_3"])
    XCTAssertEqual(
      evaluate(history: [exposure(1, completed: false), exposure(2), exposure(3)]).action, .increase
    )
  }
  func testUnilateralAndScopedDeterminism() {
    let scope = context(unilateral: true)
    XCTAssertEqual(
      evaluate(history: [exposure(1, context: scope), exposure(2, context: scope)], context: scope)
        .action, .increase)
    XCTAssertEqual(
      evaluate(
        history: [
          exposure(1, context: scope),
          exposure(
            2, context: scope, sets: exposure(2, context: scope).sets.filter { $0.side == .left }),
        ], context: scope
      ).reasonCode, "insufficient_evidence")
    var sets = exposure(2, context: scope).sets
    sets[1] = .init(index: 1, side: .right, microPounds: 50_000_000, reps: 11, rir: 2, valid: true)
    XCTAssertEqual(
      evaluate(
        history: [exposure(1, context: scope), exposure(2, context: scope, sets: sets)],
        context: scope
      ).reasonCode, "rep_ceiling_not_met")
    XCTAssertEqual(
      evaluate(history: [
        exposure(1), exposure(2, context: context(profile: "other")),
        exposure(3, context: context(slot: "other")),
      ]).evidenceIds, ["session_1"])
    XCTAssertEqual(
      evaluate(
        history: [exposure(2, sets: exposure(2).sets.reversed()), exposure(1)],
        loads: [55_000_000, 52_500_000, 50_000_000, 52_500_000]), evaluate())
  }
  func testInvalidInputsAndGatePrecedence() {
    for history in [
      [exposure(1), exposure(1)], [exposure(1), exposure(2, id: "session_1")],
      [exposure(1), exposure(2, date: Date(timeIntervalSince1970: 0))], [exposure(-1)],
    ] {
      XCTAssertEqual(evaluate(history: history).reasonCode, "invalid_history")
    }
    for gate: ProgressionGate? in [nil, .blocked, .safetyStop] {
      let result = evaluate(gate: gate, missingBaseline: true)
      XCTAssertNil(result.candidateMicroPounds)
      XCTAssertEqual(
        result.reasonCode, gate == .safetyStop ? "safety_stop" : "current_checks_required")
    }
    XCTAssertEqual(evaluate(missingBaseline: true).reasonCode, "baseline_required")
    XCTAssertEqual(
      evaluate(baselineContext: context(setup: "other")).reasonCode, "baseline_required")
    for value in [0, -1] { XCTAssertEqual(evaluate(load: value).reasonCode, "invalid_baseline") }
    for scope in [context(profile: ""), context(min: 0), context(min: 13)] {
      XCTAssertEqual(evaluate(context: scope).reasonCode, "invalid_input")
    }
    for loads: [Int]? in [nil, [], [-1, 50_000_000], [0, 50_000_000], [45_000_000]] {
      XCTAssertEqual(
        policy.evaluate(
          .init(
            context: context(), gate: .permitted,
            baseline: .init(context: context(), microPounds: 50_000_000),
            availableLoadsMicroPounds: loads, history: [])
        ).action, .blocked)
    }
    XCTAssertEqual(
      policy.evaluate(
        .init(
          context: context(), gate: .permitted,
          baseline: .init(context: context(), microPounds: 50_000_000),
          availableLoadsMicroPounds: [50_000_000], history: nil)
      ).reasonCode, "insufficient_evidence")
    for kind: ProgressionLoadKind in [.bodyweight, .assistance] {
      XCTAssertEqual(
        evaluate(history: [], loads: [0, 5_000_000], context: context(kind: kind), load: 0)
          .reasonCode, "bodyweight_or_assistance_hold")
    }
  }
  func testExternalWarmupRules() {
    let baseline = VerifiedLoadBaseline(context: context(), microPounds: 50_000_000)
    let policy = WarmupPolicy()
    let first = policy.evaluate(
      gate: .permitted, context: context(), baseline: baseline,
      availableLoadsMicroPounds: [50_000_000, 37_500_000, 25_000_000],
      firstExternalLoadExercise: true)
    XCTAssertEqual(first.sets.map(\.microPounds), [25_000_000, 37_500_000])
    XCTAssertEqual(first.sets.map(\.reps), [8, 5])
    XCTAssertEqual(first.sets.map(\.restAfterSeconds), [60, 90])
    XCTAssertFalse(first.sets[0].isWorkingSet)
    let later = externalWarmupV2(
      gate: .permitted, context: context(), baseline: baseline,
      availableLoadsMicroPounds: [0, 25_000_001, 50_000_000], firstExternalLoadExercise: false)
    XCTAssertEqual(later.sets.map(\.microPounds), [0])
    XCTAssertEqual(later.sets.map(\.reps), [5])
    XCTAssertEqual(later.ruleSetVersion, warmupRuleVersion)
    for loads: [Int]? in [nil, [], [-1, 50_000_000], [25_000_000], [50_000_000]] {
      XCTAssertTrue(
        policy.evaluate(
          gate: .permitted, context: context(), baseline: baseline,
          availableLoadsMicroPounds: loads, firstExternalLoadExercise: true
        ).isBlocked)
    }
    XCTAssertEqual(
      policy.evaluate(
        gate: .safetyStop, context: context(), baseline: nil, availableLoadsMicroPounds: nil,
        firstExternalLoadExercise: true
      ).reasonCode, "safety_stop")
    XCTAssertTrue(
      policy.evaluate(
        gate: nil, context: context(), baseline: baseline,
        availableLoadsMicroPounds: [0, 50_000_000], firstExternalLoadExercise: true
      ).isBlocked)
    XCTAssertTrue(
      policy.evaluate(
        gate: .permitted, context: context(kind: .bodyweight), baseline: baseline,
        availableLoadsMicroPounds: [0, 50_000_000], firstExternalLoadExercise: true
      ).isBlocked)
    XCTAssertEqual(WarmupPolicy.sessionWalkingSeconds, 300)
  }
  func testBodyweightRehearsalsRequireVerifiedExactSetup() {
    let assisted = RehearsalContext(
      profileId: "owner", slotId: "pull", exerciseId: "assisted", setupId: "machine",
      movement: .assistedPullUp)
    let unassisted = RehearsalContext(
      profileId: "owner", slotId: "pull", exerciseId: "unassisted", setupId: "station",
      movement: .unassistedPullUp)
    let setup = VerifiedRehearsalSetup(
      context: assisted, verificationRef: "ref1", easyAndControlled: true,
      assistanceMicroPounds: 30_000_000, availableAssistanceMicroPounds: [30_000_000, 40_000_000])
    let free = VerifiedRehearsalSetup(
      context: unassisted, verificationRef: "ref2", easyAndControlled: true)
    let policy = BodyweightWarmupPolicy()
    let both = policy.pullUps(
      gate: .permitted, includesUnassistedWork: true, assistedContext: assisted,
      assistedSetup: setup, unassistedContext: unassisted, unassistedSetup: free)
    XCTAssertEqual(both.sets.map(\.reps), [5, 2])
    XCTAssertEqual(both.sets.map(\.restAfterSeconds), [60, 120])
    XCTAssertEqual(both.sets[0].assistanceMicroPounds, 30_000_000)
    XCTAssertEqual(
      policy.pullUps(
        gate: .permitted, includesUnassistedWork: false, assistedContext: assisted,
        assistedSetup: setup, unassistedContext: nil, unassistedSetup: nil
      ).sets.map(\.restAfterSeconds), [120])
    XCTAssertEqual(
      policy.pullUps(
        gate: .permitted, includesUnassistedWork: false, assistedContext: assisted,
        assistedSetup: setup, unassistedContext: unassisted, unassistedSetup: free
      ).reasonCode, "invalid_input")
    for invalid in [
      nil,
      VerifiedRehearsalSetup(context: assisted, verificationRef: "ref", easyAndControlled: nil),
      VerifiedRehearsalSetup(
        context: assisted, verificationRef: "ref", easyAndControlled: true,
        assistanceMicroPounds: 0, availableAssistanceMicroPounds: [0]),
      VerifiedRehearsalSetup(
        context: assisted, verificationRef: "ref", easyAndControlled: true,
        assistanceMicroPounds: 1, availableAssistanceMicroPounds: [1, 1]),
    ] {
      XCTAssertTrue(
        policy.pullUps(
          gate: .permitted, includesUnassistedWork: false, assistedContext: assisted,
          assistedSetup: invalid, unassistedContext: nil, unassistedSetup: nil
        ).isBlocked)
    }
    for movement: RehearsalMovement in [.supportedKneeRaise, .kneelingRollout] {
      let scope = RehearsalContext(
        profileId: "owner", slotId: "core", exerciseId: "core", setupId: "station",
        movement: movement)
      let exact = VerifiedRehearsalSetup(
        context: scope, verificationRef: "ref", easyAndControlled: true, workingRangeRef: "range",
        rehearsalRangeRef: "range", rehearsalWithinWorkingRange: true)
      XCTAssertEqual(
        policy.core(gate: .permitted, context: scope, setup: exact).sets.map(\.reps),
        [movement == .supportedKneeRaise ? 5 : 3])
      let shortened = VerifiedRehearsalSetup(
        context: scope, verificationRef: "ref", easyAndControlled: true, workingRangeRef: "range",
        rehearsalRangeRef: "shorter", rehearsalWithinWorkingRange: true)
      XCTAssertEqual(
        policy.core(gate: .permitted, context: scope, setup: shortened).isBlocked,
        movement == .supportedKneeRaise)
      XCTAssertTrue(policy.core(gate: .safetyStop, context: scope, setup: exact).isBlocked)
      XCTAssertTrue(policy.core(gate: .permitted, context: scope, setup: nil).isBlocked)
    }
    for ref: String? in [nil, "", "spaces not allowed", "é", String(repeating: "x", count: 129)] {
      XCTAssertFalse(engineValidRef(ref))
    }
  }
  func testContinuationRequiresEveryAcknowledgement() {
    func go(
      _ gate: ProgressionGate? = .permitted, _ interrupted: Bool? = false,
      _ completed: Bool? = true, _ feedback: RehearsalFeedback? = .easyAndControlled,
      _ elapsed: Int? = 60, _ prescribed: Int = 60, _ continues: Bool? = true
    ) -> String {
      evaluateWarmupContinuation(
        gate: gate, interrupted: interrupted, targetCompleted: completed, feedback: feedback,
        elapsedRestSeconds: elapsed, prescribedRestSeconds: prescribed, userContinues: continues)
    }
    XCTAssertEqual(go(), "next_planned_action_permitted")
    XCTAssertEqual(go(.safetyStop), "safety_stop")
    XCTAssertEqual(go(nil), "current_checks_required")
    XCTAssertEqual(go(.permitted, nil), "preparation_review_required")
    XCTAssertEqual(go(.permitted, false, false), "rehearsal_completion_required")
    XCTAssertEqual(
      go(.permitted, false, true, .notEasyOrNotControlled), "warmup_setup_review_required")
    XCTAssertEqual(go(.permitted, false, true, .unknown), "warmup_feedback_required")
    XCTAssertEqual(go(.permitted, false, true, .easyAndControlled, nil), "rest_time_required")
    XCTAssertEqual(go(.permitted, false, true, .easyAndControlled, 59), "rest_incomplete")
    XCTAssertEqual(go(.permitted, false, true, .easyAndControlled, -1), "invalid_input")
    XCTAssertEqual(go(.permitted, false, true, .easyAndControlled, 60, 0), "invalid_input")
    XCTAssertEqual(
      go(.permitted, false, true, .easyAndControlled, 60, 60, false), "continuation_required")
  }
  func testCalendarPlanningAndDuration() {
    let date = Date(timeIntervalSince1970: 1_790_208_000)  // September 24, 2026 UTC.
    let policy = SessionPlanningPolicy()
    func plan(
      _ weekdays: [Int]? = [1, 2, 3, 4, 5], _ history: [SessionSequenceEntry]? = [],
      _ sessions: [String]? = ["a", "b"], _ requested: Date? = nil
    ) -> SessionPlanningResult {
      policy.evaluate(
        .init(
          orderedSessionIds: sessions, trainingWeekdays: weekdays, history: history,
          requestedDate: requested ?? date))
    }
    XCTAssertEqual(plan().sessionId, "a")
    XCTAssertEqual(plan().date, date)
    XCTAssertEqual(plan([], []).reasonCode, "schedule_required")
    XCTAssertEqual(plan(nil).reasonCode, "required_input_missing")
    XCTAssertEqual(plan([1, 1]).reasonCode, "invalid_input")
    XCTAssertEqual(plan([8]).reasonCode, "invalid_input")
    XCTAssertEqual(plan([1], [], ["a", "a"]).reasonCode, "invalid_input")
    XCTAssertEqual(plan([1], [], [" a"]).reasonCode, "invalid_input")
    XCTAssertEqual(plan([1], [], ["a"], date.addingTimeInterval(1)).reasonCode, "invalid_input")
    let active = SessionSequenceEntry(id: "0", sequence: 0, sessionId: "a", state: .active)
    XCTAssertEqual(plan([], [active]).reasonCode, "resume_session")
    let ended = SessionSequenceEntry(id: "0", sequence: 0, sessionId: "a", state: .endedEarly)
    XCTAssertEqual(plan([1], [ended]).sessionId, "b")
    XCTAssertEqual(
      plan([1], [active, .init(id: "1", sequence: 1, sessionId: "b", state: .completed)])
        .reasonCode, "invalid_history")
    XCTAssertEqual(
      plan([1], [.init(id: "1", sequence: 1, sessionId: "b", state: .completed)]).reasonCode,
      "invalid_history")
    XCTAssertEqual(
      compareSessionDuration(preferredMinutes: 60, estimatedSeconds: 3600), .withinPreference)
    XCTAssertEqual(
      compareSessionDuration(preferredMinutes: 60, estimatedSeconds: 3601), .exceedsPreference)
    XCTAssertEqual(
      compareSessionDuration(preferredMinutes: 60, estimatedSeconds: nil), .estimateRequired)
    XCTAssertEqual(
      compareSessionDuration(preferredMinutes: nil, estimatedSeconds: 10), .invalidInput)
    XCTAssertEqual(
      compareSessionDuration(preferredMinutes: 60, estimatedSeconds: -1), .invalidInput)
    XCTAssertEqual(
      compareSessionDuration(preferredMinutes: Int.max, estimatedSeconds: Int.max),
      .withinPreference)
  }
}

extension EnginePolicyTests {
  func testPlanningUsesProlepticGregorianDatesAcrossHistoricCutover() throws {
    // Dart DateTime uses a continuous proleptic Gregorian calendar, not the
    // Foundation Gregorian calendar's October 1582 discontinuity.
    let friday = try dartDate("1582-10-15T00:00:00.000Z")
    let previous = try dartDate("1582-10-14T00:00:00.000Z")
    let result = SessionPlanningPolicy().evaluate(
      .init(orderedSessionIds: ["a"], trainingWeekdays: [5], history: [], requestedDate: previous))
    XCTAssertEqual(result.reasonCode, "next_session")
    XCTAssertEqual(result.date, friday)
    let first = try dartDate("0001-01-01T00:00:00.000Z")
    XCTAssertEqual(
      SessionPlanningPolicy().evaluate(
        .init(orderedSessionIds: ["a"], trainingWeekdays: [1], history: [], requestedDate: first)
      ).date, first)
    let tooLate = try dartDate("9999-01-01T00:00:00.000Z")
    XCTAssertEqual(
      SessionPlanningPolicy().evaluate(
        .init(orderedSessionIds: ["a"], trainingWeekdays: [1], history: [], requestedDate: tooLate)
      ).reasonCode, "invalid_input")
  }
}
