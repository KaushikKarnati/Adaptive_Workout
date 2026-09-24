import Foundation
import WorkoutApplication
import WorkoutDomain
import XCTest

final class EngineComposerTests: XCTestCase {
  func testAllFiveNativeSessionsMatchDartGoldenBytesAndReopen() throws {
    for session in ownerProgram {
      let fixture = EngineComposerFixture(session.id)
      let result = try fixture.composer.compose(fixture.input())
      XCTAssertEqual(result.reason, "session_ready", "\(session.id): \(result.slotReasons)")
      let snapshot = try XCTUnwrap(result.snapshot)
      XCTAssertEqual(
        snapshot.encode(), EngineComposerGoldens.snapshots[session.id],
        "Dart compatibility: \(session.id)")
      XCTAssertEqual(
        try RecommendationSnapshot.decode(snapshot.encode()).encode(), snapshot.encode())
      XCTAssertEqual(snapshot.walkSeconds, 300)
      XCTAssertEqual(snapshot.slots.map(\.id), session.exercises.map(\.id))
      XCTAssertEqual(
        snapshot.slots.flatMap(\.targets).filter { !$0.warmup }.count,
        session.exercises.reduce(0) { $0 + $1.sets * ($1.eachSide ? 2 : 1) })
      XCTAssertTrue(
        snapshot.slots.flatMap(\.targets).filter(\.warmup).allSatisfy {
          $0.minRir == nil && $0.maxRir == nil
        })
      var reversed = fixture
      reversed.reversed = true
      XCTAssertEqual(
        try reversed.composer.compose(reversed.input()).snapshot?.encode(), snapshot.encode())
      XCTAssertEqual(result.durationFit, .estimateRequired)
      XCTAssertNil(snapshot.estimatedSeconds)
    }
  }
  func testPairedExecutionWalkingRampsAndRests() throws {
    let fixture = EngineComposerFixture("monday")
    let result = try fixture.composer.compose(fixture.input())
    let snapshot = try XCTUnwrap(result.snapshot)
    let paired = result.executionOrder.filter {
      ["incline_machine_press", "chest_supported_row"].contains($0.slotId)
    }
    XCTAssertTrue(paired.prefix(2).allSatisfy { $0.target.warmup })
    XCTAssertEqual(
      paired.dropFirst(2).map(\.slotId),
      [
        "incline_machine_press", "chest_supported_row", "incline_machine_press",
        "chest_supported_row", "incline_machine_press", "chest_supported_row",
      ])
    XCTAssertEqual(
      snapshot.slots[0].targets.filter(\.warmup).map(\.load), [50_000_000, 75_000_000])
    XCTAssertEqual(snapshot.slots[0].targets.filter(\.warmup).map(\.minReps), [8, 5])
    XCTAssertEqual(snapshot.slots[0].targets.filter(\.warmup).map(\.restSeconds), [60, 90])
    XCTAssertTrue(snapshot.slots.dropFirst().allSatisfy { $0.targets.filter(\.warmup).count == 1 })
    XCTAssertEqual(snapshot.slots[2].targets.filter { !$0.warmup }.map(\.restSeconds), [0, 0, 0])
    XCTAssertEqual(
      snapshot.slots[3].targets.filter { !$0.warmup }.map(\.restSeconds), [90, 90, 90])
  }
  func testBodyweightCrossSetupAndUnilateralIdentity() throws {
    let fixture = EngineComposerFixture("friday")
    let snapshot = try XCTUnwrap(fixture.composer.compose(fixture.input()).snapshot)
    let rehearsals = snapshot.slots[0].targets.filter(\.warmup)
    XCTAssertEqual(rehearsals.map(\.load), [70_000_000, nil])
    XCTAssertEqual(rehearsals.map(\.minReps), [5, 2])
    XCTAssertEqual(rehearsals.map(\.restSeconds), [60, 120])
    XCTAssertEqual(rehearsals[0].rehearsalIdentity?.convention, .assistance)
    XCTAssertEqual(snapshot.slots[1].targets.filter(\.warmup).count, 2)
    let arm = try XCTUnwrap(snapshot.slots.first { $0.id == "single_arm_cable_pulldown" })
    XCTAssertEqual(
      arm.targets.filter { !$0.warmup }.map(\.side), [.left, .right, .left, .right, .left, .right])
    let core = EngineComposerFixture("saturday")
    XCTAssertTrue(
      try XCTUnwrap(core.composer.compose(core.input()).snapshot).slots.last!.targets.filter {
        !$0.warmup
      }.allSatisfy { $0.rangeReference == "range" })
  }
  func testPreferencesAlternativesAndAllOrNothingFailure() throws {
    for day in ["tuesday", "saturday"] {
      var fixture = EngineComposerFixture(day)
      XCTAssertTrue(
        try fixture.composer.compose(fixture.input()).snapshot!.slots.contains {
          $0.setupId == "seated_leg_curl"
        })
      fixture.excluded = ["seated_leg_curl"]
      XCTAssertTrue(
        try fixture.composer.compose(fixture.input()).snapshot!.slots.contains {
          $0.setupId == "lying_leg_curl"
        })
    }
    var shoulders = EngineComposerFixture("wednesday")
    shoulders.missing = ["machine_shoulder_press"]
    XCTAssertEqual(
      try shoulders.composer.compose(shoulders.input()).snapshot?.slots.first?.setupId,
      "dumbbell_shoulder_press")
    var assisted = EngineComposerFixture("friday")
    assisted.assistedOnly = true
    let slot = try XCTUnwrap(assisted.composer.compose(assisted.input()).snapshot?.slots.first)
    XCTAssertEqual(slot.convention, .assistance)
    XCTAssertEqual(slot.targets.filter(\.warmup).map(\.restSeconds), [120])
    var missing = EngineComposerFixture("monday")
    missing.missing = ["incline_dumbbell_press"]
    var excluded = EngineComposerFixture("tuesday")
    excluded.excluded = ["seated_leg_curl", "lying_leg_curl"]
    var disabled = EngineComposerFixture("monday")
    disabled.disabled = true
    var noRehearsal = EngineComposerFixture("friday")
    noRehearsal.missingRehearsal = true
    var excludedRehearsal = EngineComposerFixture("friday")
    excludedRehearsal.excluded = ["assisted_machine_pull_up"]
    var mismatch = EngineComposerFixture("monday")
    mismatch.requireEquipment = true
    for fixture in [missing, excluded, disabled, noRehearsal, excludedRehearsal, mismatch] {
      let result = try fixture.composer.compose(fixture.input())
      XCTAssertFalse(result.isReady)
      XCTAssertTrue(result.snapshot!.slots.isEmpty)
      XCTAssertEqual(result.snapshot!.walkSeconds, 0)
      XCTAssertTrue(result.proposals.isEmpty)
    }
    var zero = EngineComposerFixture("monday")
    zero.rehearsalLoads = [0]
    zero.preferredMinutes = 1
    let tinyPreference = try zero.composer.compose(zero.input())
    XCTAssertTrue(tinyPreference.isReady)
    XCTAssertEqual(tinyPreference.snapshot?.walkSeconds, 300)
    XCTAssertTrue(
      tinyPreference.snapshot!.slots[0].targets.filter(\.warmup).allSatisfy { $0.load == 0 })
    zero.rehearsalLoads = []
    XCTAssertFalse(try zero.composer.compose(zero.input()).isReady)
  }
  func testSafetyStalenessAndInvalidEnvelope() throws {
    var fixture = EngineComposerFixture("monday")
    fixture.stop = true
    XCTAssertEqual(try fixture.composer.compose(fixture.input()).reason, "safety_stop")
    fixture.stop = false
    XCTAssertEqual(
      try fixture.composer.compose(fixture.input(revisionOverride: 1)).reason, "stale_input")
    let original = try fixture.input()
    for index in 0..<4 {
      let input = SessionCompositionInput(
        id: original.id, profile: index == 2 ? "other" : original.profile,
        sessionId: original.sessionId, createdAt: original.createdAt,
        requestedDate: index == 3
          ? original.requestedDate.addingTimeInterval(3600) : original.requestedDate,
        timezone: original.timezone, setup: index == 0 ? nil : original.setup,
        history: index == 1 ? nil : original.history, eligibility: original.eligibility,
        inputRevisions: original.inputRevisions, rehearsals: original.rehearsals)
      XCTAssertEqual(
        fixture.composer.compose(input).reason,
        index < 2 ? "required_input_missing" : "invalid_input")
      XCTAssertNil(fixture.composer.compose(input).snapshot)
    }
  }
  func testProgressionProposalsNeverMutateConfirmedTargets() throws {
    var plans: [RecommendationSnapshot] = []
    var occurrences: [GeneratedOccurrence] = []
    for index in 0..<2 {
      var fixture = EngineComposerFixture("monday")
      fixture.history = try .init(
        profile: "fixture", revision: occurrences.reduce(0) { $0 + $1.revision + 1 },
        recommendations: plans, occurrences: occurrences)
      let at = EngineComposerFixture.at.addingTimeInterval(Double(index * 86400))
      let snapshot = try XCTUnwrap(
        fixture.composer.compose(fixture.input(id: "r\(index)", at: at)).snapshot)
      plans.append(snapshot)
      var occurrence = try GeneratedOccurrence(
        id: "s\(index)", profile: "fixture", recommendationId: snapshot.id, sequence: index,
        revision: 0, startedAt: at, updatedAt: at, endedAt: nil, status: .active, sets: [],
        stoppedSlots: [])
      for slot in snapshot.slots {
        for target in slot.targets where !target.warmup {
          let actual = ProgramSet(
            slot: slot.id, index: target.index, side: target.side, variant: slot.exerciseId,
            setup: slot.setupId, convention: slot.convention, load: target.load,
            reps: target.maxReps, rir: 2, validity: .valid, warmup: false, skipped: false)
          occurrence = try occurrence.record(actual, at: at, prescription: snapshot)
        }
      }
      occurrences.append(try occurrence.finish(at: at, status: .completed, prescription: snapshot))
    }
    var fixture = EngineComposerFixture("monday")
    fixture.history = try .init(
      profile: "fixture", revision: occurrences.reduce(0) { $0 + $1.revision + 1 },
      recommendations: plans, occurrences: occurrences)
    let result = try fixture.composer.compose(
      fixture.input(id: "next", at: EngineComposerFixture.at.addingTimeInterval(172800)))
    XCTAssertTrue(result.isReady)
    XCTAssertEqual(result.proposals.count, 6)
    XCTAssertTrue(result.snapshot!.proposedLoads.values.allSatisfy { $0 == 105_000_000 })
    XCTAssertTrue(
      result.snapshot!.slots.flatMap(\.targets).filter { !$0.warmup }.allSatisfy {
        $0.load == 100_000_000
      })
    XCTAssertEqual(result.snapshot!.slots[0].targets[0].load, 50_000_000)
    XCTAssertEqual(Set(result.snapshot!.evidence.keys), ["s0", "s1"])
  }
  func testGenerationAcknowledgesOnlyCommittedResults() throws {
    for missing in [false, true] {
      var fixture = EngineComposerFixture("monday")
      if missing { fixture.missing = ["incline_dumbbell_press"] }
      let source = EngineFakeGenerationSource(fixture)
      let service = SessionGenerationService(source: source, composer: fixture.composer)
      let first = try service.generate("request", actionId: "action")
      XCTAssertEqual(source.saved, first.snapshot?.encode())
      XCTAssertEqual(
        try service.generate("request", actionId: "action").snapshot?.encode(), source.saved)
      XCTAssertEqual(source.receipts.count, 1)
      XCTAssertThrowsError(try service.generate("other", actionId: "action"))
    }
    for stale in [false, true] {
      let fixture = EngineComposerFixture("monday")
      let source = EngineFakeGenerationSource(fixture)
      source.changeDuringCapture = stale
      source.failSave = !stale
      XCTAssertThrowsError(
        try SessionGenerationService(source: source, composer: fixture.composer).generate(
          "request", actionId: "action"))
      XCTAssertNil(source.saved)
      XCTAssertTrue(source.receipts.isEmpty)
    }
    var fixture = EngineComposerFixture("monday")
    fixture.stop = true
    let source = EngineFakeGenerationSource(fixture)
    XCTAssertEqual(
      try SessionGenerationService(source: source, composer: fixture.composer).generate(
        "request", actionId: "action"
      ).reason, "safety_stop")
    XCTAssertNil(source.saved)
  }
}
private final class EngineFakeGenerationSource: SessionGenerationSource {
  let fixture: EngineComposerFixture
  var revision = 0, changeDuringCapture = false, failSave = false
  var receipts: [String: String] = [:], saved: String?
  init(_ fixture: EngineComposerFixture) { self.fixture = fixture }
  func capture(_ requestId: String) throws -> CapturedSessionInputs {
    let captured = try CapturedSessionInputs(
      revisionToken: String(revision), input: fixture.input(id: requestId))
    if changeDuringCapture { revision += 1 }
    return captured
  }
  func saveIfCurrent(
    captured: CapturedSessionInputs, result: SessionCompositionResult, actionId: String
  ) throws {
    let payload = result.snapshot!.encode()
    if let prior = receipts[actionId] {
      if prior != payload { throw LoggingException("action_conflict") }
      return
    }
    if captured.revisionToken != String(revision) { throw LoggingException("stale_input") }
    if failSave { throw LoggingException("storage_unavailable") }
    saved = payload
    receipts[actionId] = payload
  }
}
