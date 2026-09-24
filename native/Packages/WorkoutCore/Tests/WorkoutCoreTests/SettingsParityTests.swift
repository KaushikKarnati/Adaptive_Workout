import WorkoutDomain
import WorkoutPersistence
import XCTest

final class SettingsParityTests: XCTestCase {
  private let at = Date(timeIntervalSince1970: 1_790_167_200)
  func machine(
    revision: Int = 0, confirmed: Bool = true, work: [Int] = [20_000_000, 30_000_000],
    convention: SetupLoadConvention = .perDumbbell, variation: String = "incline_dumbbell_press"
  ) throws -> EquipmentSetup {
    try EquipmentSetup(
      id: "machine", revision: revision, label: "Synthetic fixture", variation: variation,
      equipmentId: "dumbbells", quantity: 2, capabilities: [], convention: convention,
      workingLoads: work, rehearsalLoads: [], confirmedAt: confirmed ? at : nil)
  }
  func setup(
    revision: Int = 0, schema: Int = 1, equipment: [EquipmentSetup] = [],
    loads: [StartingLoad] = [], reports: [ReportedWorkingSetup] = [],
    rehearsals: [RehearsalConfirmation] = [], days: [Int] = [1, 3], minutes: Int? = 60
  ) throws -> TrainingSetup {
    try TrainingSetup(
      schemaVersion: schema, reportedWork: reports, rehearsalConfirmations: rehearsals,
      profileId: "synthetic", revision: revision, updatedAt: at, trainingDays: days,
      preferredMinutes: minutes, supportedCapabilities: nil, unsupportedCapabilities: nil,
      limitations: nil, excludedVariations: [], equipment: equipment, startingLoads: loads)
  }
  func baseline(revision: Int = 0, load: Int = 20_000_000) throws -> StartingLoad {
    try StartingLoad(
      id: "baseline", sessionId: "monday", slotId: "incline_dumbbell_press",
      variation: "incline_dumbbell_press", setupId: "machine", setupRevision: revision,
      convention: .perDumbbell, microPounds: load, confirmedAt: at)
  }
  func report() throws -> ReportedWorkingSetup {
    try ReportedWorkingSetup(
      id: "report", sourceReference: "fixture", recordedAt: at, sessionId: "monday",
      slotId: "incline_dumbbell_press", variation: "incline_dumbbell_press",
      convention: .perDumbbell, load: 20_000_000, sets: 3, minReps: nil, maxReps: nil, minRir: nil,
      maxRir: nil, eachSide: false, loadScope: .perHand)
  }
  func testDartCanonicalSetupSchemasAndHistoricalVersionRoundTrip() throws {
    for key in ["setup1", "setup2", "legacySetup"] {
      let bytes = try XCTUnwrap(SettingsGoldenFixtures.values[key])
      let value = try TrainingSetup.decode(bytes)
      XCTAssertEqual(value.encode(), bytes)
      XCTAssertFalse(value.recommendationEligible)
      XCTAssertEqual(value.schemaVersion, key == "setup2" ? 2 : 1)
      XCTAssertEqual(
        value.programVersion, key == "legacySetup" ? "owner-program-v1" : "owner-program-v2")
    }
    let bytes = try XCTUnwrap(SettingsGoldenFixtures.values["setup1"])
    XCTAssertThrowsError(try TrainingSetup.decode(bytes + " "))
    XCTAssertThrowsError(
      try TrainingSetup.decode(bytes.replacingOccurrences(of: "\"schema\":1", with: "\"schema\":3"))
    )
    XCTAssertThrowsError(
      try TrainingSetup.decode(
        bytes.replacingOccurrences(of: "\"unit\":\"lb\"", with: "\"unit\":\"kg\"")))
    XCTAssertThrowsError(
      try TrainingSetup.decode(
        bytes.replacingOccurrences(of: "\"quantity\":2", with: "\"quantity\":true")))
    XCTAssertThrowsError(
      try TrainingSetup.decode(
        bytes.replacingOccurrences(of: "\"quantity\":2", with: "\"quantity\":2.0")))
    XCTAssertThrowsError(
      try TrainingSetup.decode(
        bytes.replacingOccurrences(of: "\"profileId\":", with: "\"unknown\":1,\"profileId\":")))
  }
  func testLegacyTimestampMicrosecondsSurviveBeyondFoundationPrecision() throws {
    let bytes = try XCTUnwrap(SettingsGoldenFixtures.values["setup2"])
    for stamp in [
      "0001-01-01T12:34:56.123456Z", "2300-01-01T12:34:56.123457Z", "9999-01-01T12:34:56.123457Z",
      "9999-12-31T23:59:59.999999Z",
    ] {
      let extreme = bytes.replacingOccurrences(of: "2026-09-23T12:34:56.123456Z", with: stamp)
      XCTAssertEqual(try TrainingSetup.decode(extreme).encode(), extreme)
    }
  }
  func testPreferenceUnknownsAndBounds() throws {
    let value = try setup(days: [], minutes: nil)
    XCTAssertNil(value.supportedCapabilities)
    XCTAssertNil(value.limitations)
    XCTAssertNil(value.preferredMinutes)
    XCTAssertThrowsError(try setup(days: [1, 1]))
    XCTAssertThrowsError(try setup(days: [0]))
    XCTAssertThrowsError(try setup(days: [8]))
    XCTAssertThrowsError(try setup(minutes: 0))
    XCTAssertThrowsError(try setup(minutes: 2_147_483_648))
    XCTAssertNoThrow(try setup(minutes: 1))
    XCTAssertNoThrow(try setup(minutes: 2_147_483_647))
    XCTAssertThrowsError(
      try TrainingSetup(
        schemaVersion: 1, profileId: "fixture", revision: 0, updatedAt: at, trainingDays: [],
        preferredMinutes: nil, supportedCapabilities: [], unsupportedCapabilities: nil,
        limitations: nil, excludedVariations: [], equipment: [], startingLoads: []))
  }
  func testEquipmentValidationDraftAndExactLadders() throws {
    XCTAssertNoThrow(try machine(confirmed: false, work: []))
    XCTAssertThrowsError(try machine(work: []))
    XCTAssertThrowsError(try machine(work: [20_000_000, 20_000_000]))
    XCTAssertThrowsError(try machine(work: [0]))
    XCTAssertThrowsError(try machine(work: [-1]))
    XCTAssertThrowsError(try machine(work: [1_000_000_000_001]))
    XCTAssertNoThrow(try machine(work: [1, 1_000_000_000_000]))
    XCTAssertNoThrow(
      try machine(work: [], convention: .bodyweight, variation: "unassisted_pull_up"))
    XCTAssertThrowsError(
      try machine(work: [1], convention: .bodyweight, variation: "unassisted_pull_up"))
    XCTAssertThrowsError(try machine(convention: .assistance))
    XCTAssertThrowsError(
      try EquipmentSetup(
        id: "x", revision: 0, label: "bad <tag>", variation: "leg_press", equipmentId: nil,
        quantity: 1, capabilities: [], convention: .machineSetting, workingLoads: [],
        rehearsalLoads: [], confirmedAt: nil))
    XCTAssertThrowsError(
      try EquipmentSetup(
        id: "x", revision: 0, label: "Machine", variation: "assisted_machine_pull_up",
        equipmentId: nil, quantity: 1, capabilities: [], convention: .assistance, workingLoads: [1],
        rehearsalLoads: [0], confirmedAt: at))
  }
  func testBaselineReferencesAndRevisionStaleness() throws {
    let e = try machine()
    let b = try baseline()
    let old = try setup(equipment: [e], loads: [b])
    XCTAssertTrue(old.baselineIsCurrent(b))
    XCTAssertFalse(b.recommendationEligible)
    XCTAssertThrowsError(try setup(equipment: [], loads: [b]))
    XCTAssertThrowsError(try setup(equipment: [machine(confirmed: false)], loads: [b]))
    XCTAssertThrowsError(try setup(equipment: [e], loads: [baseline(load: 21_000_000)]))
    let updated = try setup(revision: 1, equipment: [machine(revision: 1)], loads: [b])
    XCTAssertNoThrow(try validateSetupTransition(old, updated))
    XCTAssertFalse(updated.baselineIsCurrent(b))
    XCTAssertThrowsError(try validateSetupTransition(old, setup(revision: 1)))
    XCTAssertThrowsError(
      try validateSetupTransition(
        old, setup(revision: 1, equipment: [machine(revision: 2)], loads: [b])))
    XCTAssertThrowsError(try baseline(revision: -1))
  }
  func testReportsAreAppendOnlyNeverEvidenceAndSchemaCannotDowngrade() throws {
    let report = try report()
    XCTAssertFalse(report.recommendationEligible)
    XCTAssertNil(report.minReps)
    XCTAssertThrowsError(try setup(reports: [report]))
    let old = try setup(schema: 2, reports: [report])
    XCTAssertThrowsError(try validateSetupTransition(old, setup(revision: 1, schema: 2)))
    XCTAssertThrowsError(try validateSetupTransition(old, setup(revision: 1)))
    XCTAssertNoThrow(
      try validateSetupTransition(old, setup(revision: 1, schema: 2, reports: [report])))
    XCTAssertThrowsError(
      try ReportedWorkingSetup(
        id: "r", sourceReference: "f", recordedAt: at, sessionId: "monday",
        slotId: "incline_dumbbell_press", variation: "incline_dumbbell_press",
        convention: .perDumbbell, load: 1, sets: 1, minReps: 1, maxReps: nil, minRir: nil,
        maxRir: nil, eachSide: false))
    XCTAssertThrowsError(
      try ReportedWorkingSetup(
        id: "r", sourceReference: "f", recordedAt: at, sessionId: "monday",
        slotId: "incline_dumbbell_press", variation: "incline_dumbbell_press",
        convention: .perDumbbell, load: 1, sets: 1, minReps: nil, maxReps: nil, minRir: 5,
        maxRir: 2, eachSide: false, loadScope: .stackDisplay))
  }
  func testRehearsalDraftSymptomsAndExactLinkGates() throws {
    func rehearsal(setupId: String? = nil, revision: Int? = nil, symptoms: Bool? = false) throws
      -> RehearsalConfirmation
    {
      try RehearsalConfirmation(
        id: "rehearsal", sourceReference: "fixture", recordedAt: at, sessionId: "friday",
        slotId: "pull_up", variation: "unassisted_pull_up", easyAndControlled: true,
        symptomsReported: symptoms, setupId: setupId, setupRevision: revision)
    }
    XCTAssertFalse(try rehearsal().hasCompleteAttestation)
    XCTAssertTrue(try rehearsal(setupId: "machine", revision: 0).hasCompleteAttestation)
    XCTAssertFalse(
      try rehearsal(setupId: "machine", revision: 0, symptoms: true).hasCompleteAttestation)
    XCTAssertFalse(
      try rehearsal(setupId: "machine", revision: 0, symptoms: nil).hasCompleteAttestation)
    XCTAssertThrowsError(try rehearsal(setupId: "machine"))
    let unverified = try machine(
      confirmed: false, work: [], convention: .bodyweight, variation: "unassisted_pull_up")
    let linked = try setup(
      schema: 2, equipment: [unverified], rehearsals: [rehearsal(setupId: "machine", revision: 0)])
    XCTAssertThrowsError(try validateSetupTransition(nil, linked))
    let verified = try machine(work: [], convention: .bodyweight, variation: "unassisted_pull_up")
    XCTAssertNoThrow(
      try validateSetupTransition(
        nil,
        setup(
          schema: 2, equipment: [verified], rehearsals: [rehearsal(setupId: "machine", revision: 0)]
        )))
  }
  func testGymInventoryUnknownsValidationSortingAndDartBytes() throws {
    let home = homewoodProfile()
    XCTAssertTrue(home.equipment.isEmpty)
    XCTAssertTrue(home.availableCategories.isEmpty)
    let available = try GymEquipment(category: "dumbbells", availability: .available, checkedAt: at)
    let unavailable = try GymEquipment(
      category: "cable_station", availability: .unavailable, checkedAt: at)
    let updated = try home.update(available).update(unavailable)
    XCTAssertEqual(updated.availableCategories, ["dumbbells"])
    XCTAssertThrowsError(
      try GymEquipment(category: "dumbbells", availability: .unknown, checkedAt: at))
    XCTAssertThrowsError(
      try GymEquipment(category: "dumbbells", availability: .available, checkedAt: nil))
    XCTAssertThrowsError(
      try GymEquipment(category: "unknown", availability: .unknown, checkedAt: nil))
    for bad in [" padded", "a\nb", "<x>", "\u{202e}", String(repeating: "a", count: 121)] {
      XCTAssertThrowsError(try GymProfile(id: "x", name: bad, address: "", equipment: []))
    }
    XCTAssertThrowsError(
      try GymProfile(id: "x", name: "x", address: "", equipment: [available, available]))
    XCTAssertThrowsError(try GymProfiles(selectedId: "missing", profiles: [home]))
    let fixture = try XCTUnwrap(SettingsGoldenFixtures.values["gym"])
    XCTAssertEqual(try GymProfiles.decode(fixture).encode(), fixture)
  }
  func testPracticeRecordsBoundsSkipsAndDartBytes() throws {
    let bytes = try XCTUnwrap(SettingsGoldenFixtures.values["practiceSet"])
    XCTAssertEqual(try PracticeSet.decode(bytes).canonicalJSON, bytes)
    XCTAssertThrowsError(
      try PracticeSet(
        id: "x", exerciseId: "practice_press", index: 1, microPounds: 0, reps: 0, rir: nil,
        working: true, validity: .unknown, skipped: true))
    XCTAssertThrowsError(
      try PracticeSet(
        id: "x", exerciseId: "practice_press", index: 0, microPounds: 1, reps: 1, rir: nil,
        working: true, validity: .valid))
    XCTAssertThrowsError(
      try PracticeSet(
        id: "x", exerciseId: "not_practice", index: 1, microPounds: 1, reps: 1, rir: nil,
        working: true, validity: .valid))
    XCTAssertThrowsError(
      try PracticeSet(
        id: "x", exerciseId: "practice_press", index: 1, microPounds: nil, reps: 1, rir: nil,
        working: true, validity: .valid))
    XCTAssertNoThrow(
      try PracticeSet(
        id: "x", exerciseId: "practice_press", index: 10_000, microPounds: 1_000_000_000_000,
        reps: 10_000, rir: 10_000, working: false, validity: .pain))
  }
}
