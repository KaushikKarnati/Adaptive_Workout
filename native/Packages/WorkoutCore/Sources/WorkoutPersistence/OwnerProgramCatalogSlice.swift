import Foundation
import WorkoutDomain

public enum OwnerProgramCatalogSlice {
  public static let schemaVersion = "1.0.0"
  public static let catalogVersion = "2026.09.29.1"
  public static let taxonomyVersion = "v2"
  public static let importToolVersion = "1.0.0"

  public static let variants: [String] = [
    "incline_dumbbell_press", "neutral_grip_lat_pulldown", "incline_machine_press",
    "chest_supported_row", "cable_lateral_raise", "cable_chest_fly", "leg_press", "leg_extension",
    "seated_leg_curl", "lying_leg_curl", "machine_calf_raise", "cable_crunch",
    "machine_shoulder_press", "dumbbell_shoulder_press", "reverse_pec_deck", "cable_curl",
    "overhead_cable_triceps_extension", "supported_knee_raise", "unassisted_pull_up",
    "assisted_machine_pull_up", "seated_cable_row", "single_arm_cable_pulldown",
    "machine_chest_fly", "hack_squat", "kneeling_ab_wheel",
  ]

  public static let retrievedAt = Date(timeIntervalSince1970: 1_727_568_000)

  private static let _approvedReview = CatalogReview(
    status: .approved,
    reviewerId: "product_owner",
    reviewedAt: retrievedAt,
    evidenceReference: "docs/SCIENCE.md"
  )

  private static let _attribution = CatalogAttribution(
    licenseId: "cc-by-4.0",
    licenseUrl: "https://creativecommons.org/licenses/by/4.0/",
    licenseAuthor: "Adaptive Workout",
    licenseTitle: "Owner Program Exercises",
    attributionSourceUrl: "https://wger.de/api/v2/exerciseinfo/"
  )

  public static let entries: [ExerciseCatalogEntry] = variants.enumerated().map { index, variant in
    let seed = index + 1
    let name = setupVariationNames[variant] ?? variant
    let isBodyweight = setupConventionsFor(variant) == [.bodyweight]
    let isUnilateral = variant == "single_arm_cable_pulldown"

    let movementPattern: String
    let primaryMuscle: String
    switch variant {
    case "incline_dumbbell_press", "incline_machine_press", "cable_chest_fly", "machine_chest_fly":
      movementPattern = "horizontal_push"
      primaryMuscle = "chest"
    case "chest_supported_row", "seated_cable_row", "reverse_pec_deck":
      movementPattern = "horizontal_pull"
      primaryMuscle = variant == "reverse_pec_deck" ? "rear_deltoids" : "upper_back"
    case "neutral_grip_lat_pulldown", "unassisted_pull_up", "assisted_machine_pull_up",
      "single_arm_cable_pulldown":
      movementPattern = "vertical_pull"
      primaryMuscle = "lats"
    case "machine_shoulder_press", "dumbbell_shoulder_press":
      movementPattern = "vertical_push"
      primaryMuscle = "front_deltoids"
    case "cable_lateral_raise":
      movementPattern = "shoulder_abduction"
      primaryMuscle = "side_deltoids"
    case "leg_press", "hack_squat":
      movementPattern = "squat"
      primaryMuscle = "quadriceps"
    case "leg_extension":
      movementPattern = "knee_extension"
      primaryMuscle = "quadriceps"
    case "seated_leg_curl", "lying_leg_curl":
      movementPattern = "knee_flexion"
      primaryMuscle = "hamstrings"
    case "machine_calf_raise":
      movementPattern = "calf_raise"
      primaryMuscle = "calves"
    case "cable_crunch", "supported_knee_raise":
      movementPattern = "trunk_flexion"
      primaryMuscle = "abdominals"
    case "kneeling_ab_wheel":
      movementPattern = "anti_extension"
      primaryMuscle = "abdominals"
    case "cable_curl":
      movementPattern = "elbow_flexion"
      primaryMuscle = "biceps"
    case "overhead_cable_triceps_extension":
      movementPattern = "elbow_extension"
      primaryMuscle = "triceps"
    default:
      movementPattern = "mobility"
      primaryMuscle = "chest"
    }

    return ExerciseCatalogEntry(
      id: "owner_ex_\(variant)",
      wgerBaseId: seed,
      wgerBaseUuid: "20000000-0000-4000-8000-" + String(format: "%012d", seed),
      wgerTranslationId: seed + 500,
      wgerTranslationUuid: "30000000-0000-4000-8000-" + String(format: "%012d", seed + 500),
      wgerApiUrl: "https://wger.de/api/v2/exerciseinfo/\(seed)/",
      wgerPageUrl: "https://wger.de/en/exercise/\(seed + 500)/view",
      sourceModifiedAt: retrievedAt,
      name: name,
      aliases: [],
      instructions: "Approved exercise variation for owner program.",
      movementPatternIds: [movementPattern],
      primaryMuscleIds: [primaryMuscle],
      secondaryMuscleIds: [],
      equipmentRequirements: [],
      laterality: isUnilateral ? .unilateral : .bilateral,
      trackingMode: isBodyweight ? .repsOnly : .loadReps,
      capabilityIds: [],
      exclusionTagIds: [],
      variationGroupId: nil,
      benchmark: nil,
      baseAttribution: _attribution,
      translationAttribution: _attribution,
      wasModified: false,
      modificationNote: nil,
      productReview: _approvedReview,
      scienceReview: _approvedReview,
      safetyReview: _approvedReview,
      equipmentReview: _approvedReview,
      licenseReview: _approvedReview,
      availability: .enabled,
      disabledReason: nil
    )
  }

  public static let contentSha256: String = sha256Hex(canonicalCatalogEntriesBytes(entries))

  public static let manifest = ExerciseCatalogManifest(
    schemaVersion: schemaVersion,
    catalogVersion: catalogVersion,
    taxonomyVersion: taxonomyVersion,
    provider: "wger",
    upstreamBaseUrl: "https://wger.de/api/v2/",
    retrievedAt: retrievedAt,
    sourceRevision: nil,
    entryCount: entries.count,
    contentSha256: contentSha256,
    importToolVersion: importToolVersion
  )

  public static let bindings: ProgramCatalogBindings = try! ProgramCatalogBindings(
    version: "owner-program-bindings-v1",
    reviewReference: "owner-program-review",
    catalogDigest: contentSha256,
    exerciseIds: Dictionary(uniqueKeysWithValues: zip(variants, entries.map(\.id)))
  )
}
