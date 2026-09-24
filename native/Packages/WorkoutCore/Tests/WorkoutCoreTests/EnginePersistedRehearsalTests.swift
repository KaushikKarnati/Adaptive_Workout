import Foundation
import WorkoutDomain
import XCTest

final class EnginePersistedRehearsalTests: XCTestCase {
  func persisted(
    _ fixture: EngineComposerFixture, unlink: Bool = false, stale: Bool = false,
    symptoms: Bool? = false, easy: Bool? = true, duplicate: Bool = false,
    includeInjected: Bool = false
  ) throws -> SessionCompositionInput {
    let input = try fixture.input()
    let slot =
      fixture.sessionId == "friday"
      ? "pull_up" : fixture.sessionId == "wednesday" ? "hanging_knee_raise" : "ab_wheel_rollout"
    let variants =
      fixture.sessionId == "friday"
      ? ["assisted_machine_pull_up", "unassisted_pull_up"]
      : fixture.sessionId == "wednesday" ? ["supported_knee_raise"] : ["kneeling_ab_wheel"]
    var confirmations: [RehearsalConfirmation] = []
    for variant in variants {
      let rehearsal = input.rehearsals.first {
        $0.setup.context.slotId == "\(fixture.sessionId)/\(slot)"
          && $0.setup.context.setupId == variant
      }!
      let setup = rehearsal.setup
      confirmations.append(
        try .init(
          id: "saved_\(variant)", sourceReference: "synthetic",
          recordedAt: EngineComposerFixture.at, sessionId: fixture.sessionId, slotId: slot,
          variation: variant, easyAndControlled: easy, symptomsReported: symptoms,
          setupId: unlink ? nil : variant,
          setupRevision: unlink ? nil : stale ? 0 : rehearsal.setupRevision,
          assistance: setup.assistanceMicroPounds, workingRangeRef: setup.workingRangeRef,
          rehearsalRangeRef: setup.rehearsalRangeRef,
          withinWorkingRange: setup.rehearsalWithinWorkingRange))
    }
    if duplicate {
      let old = confirmations[0]
      confirmations.append(
        try .init(
          id: "duplicate", sourceReference: old.sourceReference, recordedAt: old.recordedAt,
          sessionId: old.sessionId, slotId: old.slotId, variation: old.variation,
          easyAndControlled: old.easyAndControlled, symptomsReported: old.symptomsReported,
          setupId: old.setupId, setupRevision: old.setupRevision, assistance: old.assistance,
          workingRangeRef: old.workingRangeRef, rehearsalRangeRef: old.rehearsalRangeRef,
          withinWorkingRange: old.withinWorkingRange))
    }
    let old = input.setup!
    let setup = try TrainingSetup(
      schemaVersion: 2, rehearsalConfirmations: confirmations, programVersion: old.programVersion,
      profileId: old.profileId, revision: old.revision, updatedAt: old.updatedAt,
      trainingDays: old.trainingDays, preferredMinutes: old.preferredMinutes,
      supportedCapabilities: old.supportedCapabilities,
      unsupportedCapabilities: old.unsupportedCapabilities, limitations: old.limitations,
      excludedVariations: old.excludedVariations, equipment: old.equipment,
      startingLoads: old.startingLoads)
    let reopened = try TrainingSetup.decode(setup.encode())
    return .init(
      id: input.id, profile: input.profile, sessionId: input.sessionId, createdAt: input.createdAt,
      requestedDate: input.requestedDate, timezone: input.timezone, setup: reopened,
      history: input.history, eligibility: input.eligibility, inputRevisions: input.inputRevisions,
      rehearsals: includeInjected ? input.rehearsals : [])
  }
  func testDurableExactConfirmationsSupplyAllBodyweightSessions() throws {
    for day in ["wednesday", "friday", "saturday"] {
      let fixture = EngineComposerFixture(day)
      let result = try fixture.composer.compose(persisted(fixture))
      XCTAssertTrue(result.isReady, "\(day) \(result.slotReasons)")
      let identities = result.snapshot!.slots.flatMap(\.targets).compactMap(\.rehearsalIdentity)
      XCTAssertFalse(identities.isEmpty)
      XCTAssertTrue(identities.allSatisfy { $0.verificationReference.hasPrefix("saved_") })
    }
  }
  func testUnlinkedStaleUnknownOrAmbiguousAttestationsRemainBlocked() throws {
    let fixture = EngineComposerFixture("friday")
    var revised = fixture
    revised.setupRevision = 1
    let inputs = try [
      persisted(fixture, unlink: true), persisted(fixture, symptoms: nil),
      persisted(fixture, easy: nil), persisted(fixture, duplicate: true),
      persisted(revised, stale: true),
    ]
    for input in inputs { XCTAssertFalse(fixture.composer.compose(input).isReady) }
  }
  func testAdverseDurableReportsCannotBeClearedByInjectedRehearsals() throws {
    let fixture = EngineComposerFixture("friday")
    XCTAssertEqual(
      try fixture.composer.compose(persisted(fixture, symptoms: true, includeInjected: true))
        .reason, "safety_stop")
    XCTAssertEqual(
      try fixture.composer.compose(persisted(fixture, easy: false, includeInjected: true)).reason,
      "warmup_setup_review_required")
  }
}
