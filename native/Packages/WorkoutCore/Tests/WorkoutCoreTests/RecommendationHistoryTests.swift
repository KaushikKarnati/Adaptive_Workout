import Foundation
import WorkoutDomain
import WorkoutPersistence
import XCTest

final class RecommendationHistoryTests: XCTestCase {
  let time = Date(timeIntervalSince1970: 1_790_294_400)
  func slot(
    setup: String = "machine", setupRevision: Int = 0, baseline: String = "baseline_r0",
    exercise: String = "fixture_press",
    unilateral: Bool = false, convention: LoadConvention = .machineSetting
  ) throws -> RecommendedSlot {
    let sides: [LoggedSide] = unilateral ? [.left, .right] : [.both]
    let warmups = try sides.map {
      try SetTarget(
        index: 1, side: $0, warmup: true, load: convention == .bodyweight ? nil : 50_000_000,
        minReps: 5, maxReps: 5, minRir: 4, maxRir: 6, restSeconds: 90)
    }
    let work = try (1...2).flatMap { index in
      try sides.map {
        try SetTarget(
          index: index, side: $0, warmup: false,
          load: convention == .bodyweight ? nil : 100_000_000,
          minReps: 8, maxReps: 12, minRir: 2, maxRir: 3, restSeconds: 120)
      }
    }
    return try RecommendedSlot(
      id: "press", exerciseId: exercise, blockId: "block1", setupId: setup,
      setupRevision: setupRevision,
      baselineReference: baseline, convention: convention, unilateral: unilateral,
      targets: warmups + work)
  }
  func plan(
    id: String = "rec0", profile: String = "fixture", history: Int = 0,
    version: String = "fixture_program_v1",
    slot: RecommendedSlot? = nil, at: Date? = nil, evidence: [String: Int] = [:],
    status: RecommendationStatus = .ready
  ) throws -> RecommendationSnapshot {
    try RecommendationSnapshot(
      id: id, profile: profile, programId: "fixture_program", programVersion: version,
      sessionTemplate: "session_a",
      ruleVersion: "fixture_rules_v1", catalogVersion: "fixture_catalog_v1",
      catalogDigest: String(repeating: "a", count: 64),
      createdAt: at ?? time, requestedDate: time, timezone: "America/Chicago",
      historyRevision: history,
      inputRevisions: [
        "profile": 0, "equipment": 0, "baseline": 0, "constraints": 0, "safety": 0,
        "catalogSchema": 1, "taxonomy": 2,
      ],
      evidence: evidence, status: status,
      reasons: [status == .ready ? "fixture_ready" : "catalog_review_required"],
      slots: status == .ready ? [try slot ?? self.slot()] : [], walkSeconds: 300,
      preferredMinutes: 60, estimatedSeconds: nil)
  }
  func start(
    _ plan: RecommendationSnapshot, id: String = "session0", sequence: Int = 0, at: Date? = nil
  ) throws -> GeneratedOccurrence {
    try GeneratedOccurrence(
      id: id, profile: plan.profile, recommendationId: plan.id, sequence: sequence, revision: 0,
      startedAt: at ?? plan.createdAt, updatedAt: at ?? plan.createdAt, endedAt: nil,
      status: .active, sets: [], stoppedSlots: [])
  }
  func actual(
    index: Int = 1, side: LoggedSide = .both, warmup: Bool = false, skipped: Bool = false,
    reps: Int = 12,
    rir: Int? = 2, validity: SetValidity = .valid, slot: RecommendedSlot? = nil,
    load: Int? = 100_000_000
  ) throws -> ProgramSet {
    let s = try slot ?? self.slot()
    return ProgramSet(
      slot: s.id, index: index, side: side, variant: s.exerciseId, setup: s.setupId,
      convention: s.convention,
      load: skipped || s.convention == .bodyweight ? nil : load, reps: skipped ? nil : reps,
      rir: skipped ? nil : rir,
      validity: skipped ? .unknown : validity, warmup: warmup, skipped: skipped)
  }
  func complete(_ plan: RecommendationSnapshot, id: String = "session0", sequence: Int = 0) throws
    -> GeneratedOccurrence
  {
    var occurrence = try start(plan, id: id, sequence: sequence)
    for s in plan.slots {
      for target in s.targets where !target.warmup {
        occurrence = try occurrence.record(
          actual(index: target.index, side: target.side, slot: s),
          at: occurrence.updatedAt.addingTimeInterval(1), prescription: plan)
      }
    }
    return try occurrence.finish(
      at: occurrence.updatedAt.addingTimeInterval(1), status: .completed, prescription: plan)
  }
  func history(_ plans: [RecommendationSnapshot], _ occurrences: [GeneratedOccurrence]) throws
    -> GeneratedHistory
  {
    try GeneratedHistory(
      profile: "fixture", revision: occurrences.reduce(0) { $0 + $1.revision + 1 },
      recommendations: plans, occurrences: occurrences)
  }
  func evaluate(_ history: GeneratedHistory, current: RecommendedSlot? = nil) throws
    -> LoadProgressionResult
  {
    let s = try current ?? slot()
    let context = progressionContext("fixture", "fixture_program", "session_a", s)
    return LoadProgressionPolicy().evaluate(
      LoadProgressionInput(
        context: context, gate: .permitted,
        baseline: VerifiedLoadBaseline(context: context, microPounds: 100_000_000),
        availableLoadsMicroPounds: [95_000_000, 100_000_000, 105_000_000],
        history: history.progression(
          programId: "fixture_program", programVersion: "fixture_program_v1",
          sessionTemplate: "session_a", current: s)))
  }
  func testSchemaOneAndTwoRoundTripExactDartBytes() throws {
    for key in ["plan_v1", "plan_v2"] {
      let payload = try XCTUnwrap(RecommendationGoldenFixtures.values[key])
      let restored = try RecommendationSnapshot.decode(payload)
      XCTAssertTrue(ManualJSON.bytesEqual(restored.encode(), payload))
      XCTAssertEqual(restored.createdTimestamp.encoded, "2026-09-25T00:00:00.123457Z")
    }
    let v2 = try RecommendationSnapshot.decode(
      XCTUnwrap(RecommendationGoldenFixtures.values["plan_v2"]))
    XCTAssertEqual(v2.schemaVersion, 2)
    XCTAssertNil(v2.slots[0].targets[0].minRir)
    XCTAssertEqual(v2.slots[0].targets[0].rehearsalIdentity?.setupId, "warmup_machine")
    XCTAssertEqual(v2.proposedLoads["press"], 105_000_000)
    XCTAssertEqual(try plan(version: "historical_v0").programVersion, "historical_v0")
  }
  func testOccurrenceTransitionsMatchDartExactBytesIncludingStickyPain() throws {
    let plan = try RecommendationSnapshot.decode(
      XCTUnwrap(RecommendationGoldenFixtures.values["plan_v1"]))
    var old = try GeneratedOccurrence.decode(
      XCTUnwrap(RecommendationGoldenFixtures.values["start"]))
    for key in ["recorded", "pain", "corrected", "completed"] {
      let next = try GeneratedOccurrence.decode(XCTUnwrap(RecommendationGoldenFixtures.values[key]))
      try validateOccurrenceTransition(old, next, plan)
      XCTAssertEqual(next.startedTimestamp.encoded, "2026-09-25T00:00:00.123457Z")
      old = next
    }
    XCTAssertEqual(old.stoppedSlots, ["press"])
    XCTAssertEqual(old.status, .completed)
  }
  func testUnknownFieldsSchemasUnitsAndNoncanonicalEncodingReject() throws {
    let payload = try plan().encode()
    for modified in [
      payload.replacingOccurrences(of: "\"schema\":1", with: "\"schema\":3"),
      payload.replacingOccurrences(of: "\"unit\":\"lb\"", with: "\"unit\":\"kg\""),
      payload.replacingOccurrences(of: "\"schema\":1", with: "\"schema\":1,\"unexpected\":true"),
      payload.replacingOccurrences(of: "\"historyRevision\":0", with: "\"historyRevision\":-1"),
      payload.replacingOccurrences(of: "\"preferredMinutes\":60", with: "\"preferredMinutes\":0"),
      payload.replacingOccurrences(of: "\"historyRevision\":0", with: "\"historyRevision\":0.0"),
      " " + payload, String(repeating: "x", count: 2_000_001),
    ] {
      XCTAssertThrowsError(try RecommendationSnapshot.decode(modified))
    }
    let started = try start(plan()).encode()
    XCTAssertThrowsError(
      try GeneratedOccurrence.decode(
        started.replacingOccurrences(of: "\"unit\":\"lb\"", with: "\"unit\":\"kg\"")))
    XCTAssertThrowsError(
      try GeneratedOccurrence.decode(
        started.replacingOccurrences(of: "\"schema\":1", with: "\"schema\":1,\"extra\":0")))
  }
  func testBlockedPlansCannotExecuteAndWarmupDoesNotCompleteWork() throws {
    let blocked = try plan(status: .blocked)
    XCTAssertTrue(blocked.slots.isEmpty)
    XCTAssertThrowsError(try start(blocked).validateAgainst(blocked))
    let plan = try plan()
    let started = try start(plan)
    XCTAssertThrowsError(try started.finish(at: time, status: .completed, prescription: plan))
    let warm = try started.record(actual(warmup: true), at: time, prescription: plan)
    XCTAssertThrowsError(try warm.finish(at: time, status: .completed, prescription: plan))
    let recorded = try warm.record(actual(), at: time, prescription: plan).record(
      actual(index: 2, skipped: true), at: time, prescription: plan)
    let finished = try recorded.finish(at: time, status: .completed, prescription: plan)
    let correction = try finished.record(actual(reps: 8, rir: nil), at: time, prescription: plan)
    try validateOccurrenceTransition(finished, correction, plan)
    XCTAssertEqual(correction.sets.count, 3)
    XCTAssertThrowsError(try correction.record(actual(index: 3), at: time, prescription: plan))
  }
  func testPainRemainsStoppedAfterCorrectionAndSkipsAreAllowed() throws {
    let plan = try plan()
    let stopped = try start(plan).record(actual(validity: .pain), at: time, prescription: plan)
    let corrected = try stopped.record(actual(), at: time, prescription: plan)
    XCTAssertEqual(corrected.stoppedSlots, ["press"])
    XCTAssertThrowsError(try corrected.record(actual(index: 2), at: time, prescription: plan))
    XCTAssertEqual(
      try corrected.record(actual(index: 2, skipped: true), at: time, prescription: plan).sets
        .count, 2)
    XCTAssertThrowsError(
      try corrected.record(actual(), at: time.addingTimeInterval(-1), prescription: plan))
  }
  func testInvalidTargetContextsNumbersAndDuplicateActualsFail() throws {
    let plan = try plan()
    let start = try start(plan)
    for set in [
      try actual(slot: slot(setup: "other")), try actual(side: .left), try actual(index: 0),
      try actual(reps: -1), try actual(rir: -1), try actual(load: nil),
    ] {
      XCTAssertThrowsError(try start.record(set, at: time, prescription: plan))
    }
    XCTAssertThrowsError(
      try GeneratedOccurrence(
        id: "s", profile: "fixture", recommendationId: plan.id, sequence: 0, revision: 0,
        startedAt: time, updatedAt: time, endedAt: nil, status: .active,
        sets: [actual(), actual()], stoppedSlots: []))
    XCTAssertThrowsError(
      try GeneratedOccurrence(
        id: "s", profile: "fixture", recommendationId: plan.id, sequence: 0, revision: 0,
        startedAt: time, updatedAt: time, endedAt: nil, status: .completed, sets: [],
        stoppedSlots: []))
  }
  func testTargetBoundsSidesContiguousWorkAndSchemaTwoRequirement() throws {
    XCTAssertThrowsError(
      try SetTarget(
        index: 0, side: .both, warmup: false, load: 1, minReps: 8, maxReps: 12, minRir: 2,
        maxRir: 3, restSeconds: 120))
    XCTAssertThrowsError(
      try SetTarget(
        index: 1, side: .both, warmup: false, load: 1, minReps: 8, maxReps: 12, minRir: nil,
        maxRir: nil, restSeconds: 120))
    let s = try slot()
    for targets in [[s.targets[1], s.targets[1]], [s.targets[2]], [s.targets[0]]] {
      XCTAssertThrowsError(
        try RecommendedSlot(
          id: s.id, exerciseId: s.exerciseId, blockId: s.blockId, setupId: s.setupId,
          setupRevision: 0,
          baselineReference: s.baselineReference, convention: s.convention, unilateral: false,
          targets: targets))
    }
    XCTAssertThrowsError(
      try RecommendedSlot(
        id: s.id, exerciseId: s.exerciseId, blockId: s.blockId, setupId: s.setupId,
        setupRevision: 0,
        baselineReference: s.baselineReference, convention: s.convention, unilateral: true,
        targets: s.targets))
    let rehearsal = try SetTarget(
      index: 1, side: .both, warmup: true, load: 0, minReps: 5, maxReps: 5, minRir: nil,
      maxRir: nil, restSeconds: 90)
    let noEffort = try RecommendedSlot(
      id: s.id, exerciseId: s.exerciseId, blockId: s.blockId, setupId: s.setupId, setupRevision: 0,
      baselineReference: s.baselineReference, convention: s.convention, unilateral: false,
      targets: [rehearsal] + Array(s.targets.dropFirst()))
    XCTAssertThrowsError(try plan(slot: noEffort))
  }
  func testProgressionKeepsIncompleteAndIncomparableEvidence() throws {
    let first = try plan()
    let second = try plan(id: "rec1", at: time.addingTimeInterval(86_400))
    let a = try complete(first)
    let b = try complete(second, id: "session1", sequence: 1)
    XCTAssertEqual(try evaluate(history([first, second], [b, a])).action, .increase)
    let corrected = try b.record(actual(rir: nil), at: b.updatedAt, prescription: second)
    XCTAssertEqual(try evaluate(history([first, second], [a, corrected])).action, .hold)
    let interrupted = try start(second, id: "session1", sequence: 1)
    XCTAssertEqual(try evaluate(history([first, second], [a, interrupted])).action, .hold)
    let early = try interrupted.finish(
      at: interrupted.updatedAt, status: .endedEarly, prescription: second)
    XCTAssertEqual(try evaluate(history([first, second], [a, early])).action, .hold)
    XCTAssertEqual(
      try evaluate(history([first, second], [a, b]), current: slot(setupRevision: 1)).action, .hold)
    XCTAssertEqual(
      try evaluate(history([first, second], [a, b]), current: slot(baseline: "new_baseline"))
        .action, .hold)
  }
  func testVersionChangesAndHistoricallyMissingSlotsRemainNonqualifyingExposures() throws {
    let first = try plan()
    let second = try plan(id: "old_version", version: "old_v0", at: time.addingTimeInterval(86_400))
    let a = try complete(first)
    let b = try complete(second, id: "session1", sequence: 1)
    let h = try history([first, second], [a, b])
    let exposures = h.progression(
      programId: "fixture_program", programVersion: "fixture_program_v1",
      sessionTemplate: "session_a", current: try slot())
    XCTAssertEqual(exposures.count, 2)
    XCTAssertTrue(exposures[0].completed)
    XCTAssertFalse(exposures[1].completed)
    XCTAssertEqual(try evaluate(h).action, .hold)
    let s = try slot()
    let omitted = try RecommendedSlot(
      id: "other_slot", exerciseId: s.exerciseId, blockId: s.blockId, setupId: s.setupId,
      setupRevision: s.setupRevision,
      baselineReference: s.baselineReference, convention: s.convention, unilateral: s.unilateral,
      targets: s.targets)
    let missing = try plan(id: "missing_slot", slot: omitted, at: time.addingTimeInterval(86_400))
    let missingOccurrence = try complete(missing, id: "session1", sequence: 1)
    let missingHistory = try history([first, missing], [a, missingOccurrence])
    let missingExposures = missingHistory.progression(
      programId: "fixture_program", programVersion: "fixture_program_v1",
      sessionTemplate: "session_a", current: s)
    XCTAssertEqual(missingExposures.count, 2)
    XCTAssertFalse(missingExposures[1].completed)
    XCTAssertTrue(missingExposures[1].sets.isEmpty)
  }
  func testUnilateralCompletionRequiresBothSidesAndBodyweightHasNoInventedLoad() throws {
    let unilateral = try slot(unilateral: true)
    let plan = try plan(slot: unilateral)
    var occurrence = try start(plan)
    for index in 1...2 {
      occurrence = try occurrence.record(
        actual(index: index, side: .left, slot: unilateral), at: time, prescription: plan)
    }
    XCTAssertThrowsError(try occurrence.finish(at: time, status: .completed, prescription: plan))
    for index in 1...2 {
      occurrence = try occurrence.record(
        actual(index: index, side: .right, slot: unilateral), at: time, prescription: plan)
    }
    XCTAssertEqual(
      try occurrence.finish(at: time, status: .completed, prescription: plan).sets.count, 4)
    let bodyweight = try slot(convention: .bodyweight)
    let bwPlan = try self.plan(slot: bodyweight)
    let bwOccurrence = try complete(bwPlan)
    XCTAssertTrue(bwOccurrence.sets.allSatisfy { $0.load == nil })
    XCTAssertEqual(
      progressionContext("fixture", "program", "session", bodyweight).loadKind, .bodyweight)
    XCTAssertEqual(
      progressionContext("fixture", "program", "session", try slot(convention: .assistance))
        .loadKind, .assistance)
  }
  func testHistoryRejectsMissingSequencesDuplicatePlansAndRevisionGaps() throws {
    let plan = try plan()
    let a = try start(plan)
    XCTAssertThrowsError(try history([plan, plan], [a]))
    XCTAssertThrowsError(try history([], [a]))
    XCTAssertThrowsError(try history([plan], [start(plan, sequence: 1)]))
    XCTAssertThrowsError(
      try GeneratedHistory(
        profile: "fixture", revision: 0, recommendations: [plan], occurrences: [a]))
    XCTAssertThrowsError(
      try GeneratedHistory(
        profile: "another", revision: 1, recommendations: [plan], occurrences: [a]))
  }
  func testRehearsalIdentityControlsOnlyWarmupActualContext() throws {
    let plan = try RecommendationSnapshot.decode(
      XCTUnwrap(RecommendationGoldenFixtures.values["plan_v2"]))
    let occurrence = try start(plan)
    let wrong = try actual(warmup: true)
    XCTAssertThrowsError(try occurrence.record(wrong, at: occurrence.updatedAt, prescription: plan))
    let correct = ProgramSet(
      slot: "press", index: 1, side: .both, variant: "warmup_press", setup: "warmup_machine",
      convention: .machineSetting,
      load: 50_000_000, reps: 5, rir: nil, validity: .valid, warmup: true, skipped: false)
    XCTAssertEqual(
      try occurrence.record(correct, at: occurrence.updatedAt, prescription: plan).sets.count, 1)
  }
}
