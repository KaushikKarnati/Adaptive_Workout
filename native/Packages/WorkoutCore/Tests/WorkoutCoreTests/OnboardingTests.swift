import Foundation
import WorkoutDomain
import WorkoutPersistence
import XCTest

final class OnboardingTests: XCTestCase {
  func testFreshProfileHasNoOwnerInputsAndRemainsBlocked() throws {
    let value = UserTrainingProfile(id: "fixture")
    try value.validate()
    XCTAssertNil(value.goal)
    XCTAssertNil(value.experience)
    XCTAssertTrue(value.weekdays.isEmpty)
    XCTAssertTrue(value.sessions.isEmpty)
    XCTAssertTrue(value.equipment.isEmpty)
    XCTAssertNil(value.symptomReported)
    XCTAssertFalse(value.activationBlockers.isEmpty)
  }
  func testRevisionPersistenceRetryConflictAndIsolation() throws {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: folder) }
    let path = folder.appendingPathComponent("profiles.sqlite").path
    let repository = try SqliteUserTrainingProfileRepository(path: path)
    var value = UserTrainingProfile(id: "fixture")
    try repository.save(value, expectedRevision: nil)
    try repository.save(value, expectedRevision: nil)
    value.revision = 1
    value.goal = .strength
    value.step = .schedule
    try repository.save(value, expectedRevision: 0)
    let reopened = try SqliteUserTrainingProfileRepository(path: path)
    XCTAssertEqual(try reopened.load("fixture"), value)
    XCTAssertNil(try reopened.load("other"))
    var stale = value
    stale.goal = .muscle
    XCTAssertThrowsError(try repository.save(stale, expectedRevision: 0))
    XCTAssertEqual(try repository.load("fixture"), value)
  }
  func testInvalidInputsAndReviewDoNotUnlock() throws {
    var value = UserTrainingProfile(id: "fixture")
    value.weekdays = [0]
    XCTAssertThrowsError(try value.validate())
    value.weekdays = [1, 1]
    XCTAssertThrowsError(try value.validate())
    value.weekdays = [1]
    value.minutes = 0
    XCTAssertThrowsError(try value.validate())
    value.minutes = 60
    value.sessions = UserTrainingProfile.ownerDraft()
    try value.validate()
    value.sessions[0].exercises[0].maxReps = 1
    XCTAssertThrowsError(try value.validate())
    value.sessions = UserTrainingProfile.ownerDraft()
    value.preferencesReviewed = true
    value.goal = .strength
    value.experience = .experienced
    value.symptomReported = false
    XCTAssertFalse(value.activationBlockers.isEmpty)
  }
}

extension OnboardingTests {
  func testHealthSnapshotMissingDuplicateInvalidAndOverlappingInputs() throws {
    let at = Date(timeIntervalSince1970: 1000)
    let sample = HealthObservation(
      id: "sleep", category: .sleep, source: "fixture",
      start: at.addingTimeInterval(-100), end: at, value: 1, unit: "sleepStage")
    let overlapping = HealthObservation(
      id: "sleep2", category: .sleep, source: "other",
      start: at.addingTimeInterval(-50), end: at, value: 3, unit: "sleepStage")
    let snapshot = try HealthSnapshot(
      capturedAt: at, requested: [.sleep, .hrv], observations: [overlapping, sample])
    XCTAssertTrue(snapshot.hasOverlappingSleep)
    XCTAssertEqual(snapshot.unavailableCategories, [.hrv])
    XCTAssertEqual(snapshot.observations.map(\.id), ["sleep", "sleep2"])
    XCTAssertThrowsError(
      try HealthSnapshot(capturedAt: at, requested: [.sleep], observations: [sample, sample]))
    var invalid = sample
    invalid.value = .nan
    XCTAssertThrowsError(
      try HealthSnapshot(capturedAt: at, requested: [.sleep], observations: [invalid]))
    let deleted = try HealthSnapshot(capturedAt: at, requested: [.sleep], observations: [])
    XCTAssertEqual(deleted.unavailableCategories, [.sleep])
  }
  func testEveryOnboardingStepSurvivesReopenWithoutEnablingGeneration() throws {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: folder) }
    let path = folder.appendingPathComponent("profiles.sqlite").path
    var profile = UserTrainingProfile(id: "fixture")
    for (index, step) in OnboardingStep.allCases.enumerated() {
      let repository = try SqliteUserTrainingProfileRepository(path: path)
      profile.step = step
      profile.revision = index
      try repository.save(profile, expectedRevision: index == 0 ? nil : index - 1)
      XCTAssertEqual(try repository.currentProfile(), profile)
      XCTAssertFalse(profile.activationBlockers.isEmpty)
    }
  }
}
