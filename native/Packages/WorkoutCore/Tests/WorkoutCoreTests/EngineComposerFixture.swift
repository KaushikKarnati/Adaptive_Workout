import Foundation
import WorkoutDomain

/// Synthetic fixture only. Reviews, verified baselines, and clinical clearance
/// here must never be registered by the application composition boundary.
struct EngineComposerFixture {
  static let variants = [
    "incline_dumbbell_press", "neutral_grip_lat_pulldown", "incline_machine_press",
    "chest_supported_row", "cable_lateral_raise", "cable_chest_fly", "leg_press", "leg_extension",
    "seated_leg_curl", "lying_leg_curl", "machine_calf_raise", "cable_crunch",
    "machine_shoulder_press", "dumbbell_shoulder_press", "reverse_pec_deck", "cable_curl",
    "overhead_cable_triceps_extension", "supported_knee_raise", "unassisted_pull_up",
    "assisted_machine_pull_up", "seated_cable_row", "single_arm_cable_pulldown",
    "machine_chest_fly", "hack_squat", "kneeling_ab_wheel",
  ]
  static let at = try! dartDate("2026-09-26T00:00:00.000Z")
  let sessionId: String
  var excluded: [String] = [], missing: [String] = []
  var reversed = false, stop = false, disabled = false, missingRehearsal = false,
    assistedOnly = false, requireEquipment = false
  var rehearsalLoads = [0, 50_000_000, 75_000_000]
  var history: GeneratedHistory?
  var setupRevision = 0, preferredMinutes = 60
  init(_ sessionId: String) { self.sessionId = sessionId }
  var entries: [ExerciseCatalogEntry] {
    Self.variants.enumerated().map { index, variant in
      let seed = index + 1
      let approved = CatalogReview(
        status: .approved, reviewerId: "reviewer_one",
        reviewedAt: try! dartDate("2026-09-08T10:00:00.000Z"),
        evidenceReference: "docs/reviews/example.md")
      let attribution = CatalogAttribution(
        licenseId: "cc-by-4.0", licenseUrl: "https://creativecommons.org/licenses/by/4.0/",
        licenseAuthor: "Example author", licenseTitle: "Example title",
        attributionSourceUrl: "https://wger.de/api/v2/exerciseinfo/\(seed)/")
      return ExerciseCatalogEntry(
        id: String(format: "exercise_%02d", seed), wgerBaseId: seed,
        wgerBaseUuid: "10000000-0000-4000-8000-" + String(format: "%012d", seed),
        wgerTranslationId: seed + 100,
        wgerTranslationUuid: "20000000-0000-4000-8000-" + String(format: "%012d", seed + 100),
        wgerApiUrl: "https://wger.de/api/v2/exerciseinfo/\(seed)/",
        wgerPageUrl: "https://wger.de/en/exercise/\(seed + 100)/view",
        sourceModifiedAt: try! dartDate("2026-09-08T09:00:00.000Z"),
        name: "Synthetic exercise \(seed)", instructions: "Synthetic test-only instructions.",
        movementPatternIds: ["horizontal_push"], primaryMuscleIds: ["chest"],
        equipmentRequirements: requireEquipment
          ? [.init(equipmentId: "dumbbells", quantity: 2)] : [],
        laterality: variant == "single_arm_cable_pulldown" ? .unilateral : .bilateral,
        trackingMode: setupConventionsFor(variant) == [.bodyweight] ? .repsOnly : .loadReps,
        baseAttribution: attribution, translationAttribution: attribution, wasModified: false,
        productReview: approved, scienceReview: approved, safetyReview: approved,
        equipmentReview: approved, licenseReview: approved,
        availability: disabled ? .disabled : .enabled,
        disabledReason: disabled ? "Synthetic disabled test" : nil)
    }
  }
  var manifest: ExerciseCatalogManifest {
    .init(
      schemaVersion: "1.0.0", catalogVersion: "2026.09.08.1",
      upstreamBaseUrl: "https://wger.de/api/v2/",
      retrievedAt: try! dartDate("2026-09-08T12:00:00.000Z"), entryCount: entries.count,
      contentSha256: sha256Hex(canonicalCatalogEntriesBytes(entries)), importToolVersion: "1.0.0")
  }
  var bindings: ProgramCatalogBindings {
    try! .init(
      version: "synthetic-bindings-v2", reviewReference: "synthetic-review",
      catalogDigest: manifest.contentSha256,
      exerciseIds: Dictionary(uniqueKeysWithValues: zip(Self.variants, entries.map(\.id))))
  }
  var composer: SessionComposer {
    .init(
      evaluator: .init(
        catalogValidator: .init(importedAt: try! dartDate("2026-09-08T13:00:00.000Z"))),
      bindings: bindings)
  }
  func input(id: String = "generated", revisionOverride: Int? = nil, at: Date? = nil) throws
    -> SessionCompositionInput
  {
    let session = ownerProgram.first { $0.id == sessionId }!
    var equipment: [EquipmentSetup] = []
    var baselines: [StartingLoad] = []
    var rehearsals: [SessionRehearsalVerification] = []
    for variant in Self.variants where !missing.contains(variant) {
      let convention = setupConventionsFor(variant)[0]
      equipment.append(
        try .init(
          id: variant, revision: setupRevision, label: "Synthetic station", variation: variant,
          equipmentId: nil, quantity: 1, capabilities: [], convention: convention,
          workingLoads: convention == .bodyweight ? [] : [90_000_000, 100_000_000, 105_000_000],
          rehearsalLoads: convention == .bodyweight
            ? [] : convention == .assistance ? [70_000_000] : rehearsalLoads, confirmedAt: Self.at))
    }
    for exercise in session.exercises {
      for variant in setupVariantsFor(exercise) where !missing.contains(variant) {
        let convention = setupConventionsFor(variant)[0]
        baselines.append(
          try .init(
            id: "\(exercise.id)_\(variant)", sessionId: sessionId, slotId: exercise.id,
            variation: variant, setupId: variant, setupRevision: setupRevision,
            convention: convention, microPounds: convention == .bodyweight ? nil : 100_000_000,
            confirmedAt: Self.at))
      }
      for variant in [
        "unassisted_pull_up", "assisted_machine_pull_up", "supported_knee_raise",
        "kneeling_ab_wheel",
      ] where !missing.contains(variant) && !missingRehearsal {
        let movement: RehearsalMovement
        switch variant {
        case "unassisted_pull_up": movement = .unassistedPullUp
        case "assisted_machine_pull_up": movement = .assistedPullUp
        case "supported_knee_raise": movement = .supportedKneeRaise
        default: movement = .kneelingRollout
        }
        let core = movement == .supportedKneeRaise || movement == .kneelingRollout
        rehearsals.append(
          .init(
            setupRevision: setupRevision,
            setup: .init(
              context: .init(
                profileId: "fixture", slotId: "\(sessionId)/\(exercise.id)",
                exerciseId: bindings.exerciseIds[variant]!, setupId: variant, movement: movement),
              verificationRef: "synthetic_rehearsal", easyAndControlled: true,
              assistanceMicroPounds: movement == .assistedPullUp ? 70_000_000 : nil,
              availableAssistanceMicroPounds: movement == .assistedPullUp ? [70_000_000] : nil,
              workingRangeRef: core ? "range" : nil, rehearsalRangeRef: core ? "range" : nil,
              rehearsalWithinWorkingRange: core ? true : nil)))
      }
    }
    let setup = try TrainingSetup(
      profileId: "fixture", revision: setupRevision, updatedAt: Self.at,
      trainingDays: [1, 2, 3, 4, 5], preferredMinutes: preferredMinutes, supportedCapabilities: [],
      unsupportedCapabilities: [], limitations: [],
      excludedVariations: excluded + (assistedOnly ? ["unassisted_pull_up"] : []),
      equipment: reversed ? equipment.reversed() : equipment,
      startingLoads: reversed ? baselines.reversed() : baselines)
    let inventory: [EquipmentInventoryItem] =
      requireEquipment ? [.init(equipmentId: "dumbbells", quantity: 2)] : []
    let digest = eligibilityConstraintSnapshotSha256(
      equipmentInventory: inventory, temporarilyUnavailableEquipmentIds: [],
      functionalCapabilityAssessment: .init(), limitationAssessment: .init(),
      persistentExerciseExclusionIds: [], requestExerciseExclusionIds: [])
    let eligibility = ExerciseEligibilityRequest(
      eligibilityRuleSetVersion: "1.0.0", schemaVersion: manifest.schemaVersion,
      catalogVersion: manifest.catalogVersion, taxonomyVersion: manifest.taxonomyVersion,
      catalogContentSha256: manifest.contentSha256, constraintSnapshotSha256: digest,
      manifest: manifest, catalog: reversed ? entries.reversed() : entries,
      candidateExerciseIds: entries.map(\.id), equipmentInventory: inventory,
      temporarilyUnavailableEquipmentIds: [], functionalCapabilityAssessment: .init(),
      limitationAssessment: .init(), persistentExerciseExclusionIds: [],
      requestExerciseExclusionIds: [],
      safetyState: .init(
        version: "1.0.0", kind: stop ? .stop : .clear,
        affectedExerciseId: stop ? entries[0].id : nil))
    return try .init(
      id: id, profile: "fixture", sessionId: sessionId, createdAt: at ?? Self.at,
      requestedDate: Self.at, timezone: "America/Chicago", setup: setup,
      history: history
        ?? GeneratedHistory(profile: "fixture", revision: 0, recommendations: [], occurrences: []),
      eligibility: eligibility,
      inputRevisions: [
        "profile": revisionOverride ?? setupRevision, "equipment": setupRevision,
        "baseline": setupRevision, "constraints": setupRevision, "safety": 0, "catalogSchema": 1,
        "taxonomy": 2,
      ], rehearsals: reversed ? rehearsals.reversed() : rehearsals)
  }
}
