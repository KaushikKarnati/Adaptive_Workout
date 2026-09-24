import Foundation
import WorkoutDomain

public enum BenchmarkCatalogSlice {
  public static let schemaVersion = "1.0.0"
  public static let catalogVersion = "2026.09.08.1"
  public static let taxonomyVersion = "v2"
  public static let importToolVersion = "1.0.0"
  public static let contentSha256 =
    "4bda4d4b43bba409c66585acb76d88c871cda97d9b13ca0fe732595488578eb4"

  public static let retrievedAt = date(2026, 9, 8, 23, 14, 3)

  public static let entries: [ExerciseCatalogEntry] = [
    _barbellBackSquat, _flatBenchPress, _deadlift,
  ]

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
    importToolVersion: importToolVersion)

  private static let _pendingReview = CatalogReview(status: .pending)

  private static let _productReview = CatalogReview(
    status: .approved,
    reviewerId: "product_owner",
    reviewedAt: retrievedAt,
    evidenceReference: "docs/SCIENCE.md")

  private static let _barbellBackSquat = ExerciseCatalogEntry(
    id: "wger_a2f5b6efb78049c08d96fdaff23e27ce",
    wgerBaseId: 615,
    wgerBaseUuid: "a2f5b6ef-b780-49c0-8d96-fdaff23e27ce",
    wgerTranslationId: 111,
    wgerTranslationUuid: "c4856da3-8454-4857-8997-336d06df590f",
    wgerApiUrl: "https://wger.de/api/v2/exerciseinfo/615/",
    wgerPageUrl: "https://wger.de/en/exercise/111/view",
    sourceModifiedAt: date(2026, 4, 15, 20, 23, 56),
    name: "Barbell Back Squat",
    aliases: ["Squats"],
    instructions: nil,
    movementPatternIds: ["squat"],
    primaryMuscleIds: ["quadriceps"],
    secondaryMuscleIds: ["glutes"],
    equipmentRequirements: [
      EquipmentRequirement(equipmentId: "standard_barbell", quantity: 1),
      EquipmentRequirement(equipmentId: "weight_plates", quantity: 1),
      EquipmentRequirement(
        equipmentId: "power_rack",
        quantity: 1,
        capabilityIds: ["adjustable_height", "safety_arms"]),
    ],
    laterality: .bilateral,
    trackingMode: .loadReps,
    capabilityIds: [
      "bar_on_back_position",
      "deep_knee_flexion",
      "standing_unsupported",
      "sustained_grip",
    ],
    exclusionTagIds: [
      "avoid_bar_on_back_position",
      "avoid_deep_knee_flexion",
      "avoid_sustained_grip",
    ],
    variationGroupId: nil,
    benchmark: .barbellBackSquat,
    baseAttribution: _squatBaseAttribution,
    translationAttribution: _squatTranslationAttribution,
    wasModified: true,
    modificationNote:
      "Display name normalized to the approved benchmark label; upstream instructions omitted pending science and safety review.",
    productReview: _productReview,
    scienceReview: _pendingReview,
    safetyReview: _pendingReview,
    equipmentReview: _pendingReview,
    licenseReview: _pendingReview,
    availability: .disabled,
    disabledReason: "Pending science, safety, equipment, and licensing review.")

  private static let _flatBenchPress = ExerciseCatalogEntry(
    id: "wger_3717d14478154a979a56956fb889c996",
    wgerBaseId: 73,
    wgerBaseUuid: "3717d144-7815-4a97-9a56-956fb889c996",
    wgerTranslationId: 192,
    wgerTranslationUuid: "5da6340b-22ec-4c1b-a443-eef2f59f92f0",
    wgerApiUrl: "https://wger.de/api/v2/exerciseinfo/73/",
    wgerPageUrl: "https://wger.de/en/exercise/192/view",
    sourceModifiedAt: date(2026, 6, 19, 16, 46, 21),
    name: "Flat Barbell Bench Press",
    aliases: ["Bench Press"],
    instructions: nil,
    movementPatternIds: ["horizontal_push"],
    primaryMuscleIds: ["chest"],
    secondaryMuscleIds: ["front_deltoids", "triceps"],
    equipmentRequirements: [
      EquipmentRequirement(equipmentId: "standard_barbell", quantity: 1),
      EquipmentRequirement(equipmentId: "weight_plates", quantity: 1),
      EquipmentRequirement(equipmentId: "flat_bench", quantity: 1),
      EquipmentRequirement(
        equipmentId: "power_rack",
        quantity: 1,
        capabilityIds: ["adjustable_height", "safety_arms"]),
    ],
    laterality: .bilateral,
    trackingMode: .loadReps,
    capabilityIds: ["supine_position", "sustained_grip"],
    exclusionTagIds: ["avoid_sustained_grip"],
    variationGroupId: nil,
    benchmark: .flatBarbellBenchPress,
    baseAttribution: _benchBaseAttribution,
    translationAttribution: _benchTranslationAttribution,
    wasModified: true,
    modificationNote:
      "Display name normalized to the approved benchmark label; upstream instructions omitted pending science and safety review.",
    productReview: _productReview,
    scienceReview: _pendingReview,
    safetyReview: _pendingReview,
    equipmentReview: _pendingReview,
    licenseReview: _pendingReview,
    availability: .disabled,
    disabledReason: "Pending science, safety, equipment, and licensing review.")

  private static let _deadlift = ExerciseCatalogEntry(
    id: "wger_ee8e8db42d8249e1ab7f891e9a354934",
    wgerBaseId: 184,
    wgerBaseUuid: "ee8e8db4-2d82-49e1-ab7f-891e9a354934",
    wgerTranslationId: 105,
    wgerTranslationUuid: "22cca8fc-cfaf-4941-b0f7-faf9f2937c52",
    wgerApiUrl: "https://wger.de/api/v2/exerciseinfo/184/",
    wgerPageUrl: "https://wger.de/en/exercise/105/view",
    sourceModifiedAt: date(2026, 6, 19, 17, 55, 7),
    name: "Conventional Barbell Deadlift",
    aliases: ["Deadlifts"],
    instructions: nil,
    movementPatternIds: ["hinge"],
    primaryMuscleIds: ["lats"],
    secondaryMuscleIds: ["glutes"],
    equipmentRequirements: [
      EquipmentRequirement(equipmentId: "standard_barbell", quantity: 1),
      EquipmentRequirement(equipmentId: "weight_plates", quantity: 1),
    ],
    laterality: .bilateral,
    trackingMode: .loadReps,
    capabilityIds: [
      "loaded_hip_hinge",
      "standing_unsupported",
      "sustained_grip",
    ],
    exclusionTagIds: [
      "avoid_loaded_hip_hinge",
      "avoid_sustained_grip",
    ],
    variationGroupId: nil,
    benchmark: .conventionalBarbellDeadlift,
    baseAttribution: _deadliftBaseAttribution,
    translationAttribution: _deadliftTranslationAttribution,
    wasModified: true,
    modificationNote:
      "Display name normalized to the approved benchmark label; upstream instructions omitted pending science and safety review.",
    productReview: _productReview,
    scienceReview: _pendingReview,
    safetyReview: _pendingReview,
    equipmentReview: _pendingReview,
    licenseReview: _pendingReview,
    availability: .disabled,
    disabledReason: "Pending science, safety, equipment, and licensing review.")

  private static let _squatBaseAttribution = _attribution(
    sourceId: 615,
    author: "wger.de",
    isTranslation: false)
  private static let _squatTranslationAttribution = _attribution(
    sourceId: 111,
    author: "wger.de",
    isTranslation: true)
  private static let _benchBaseAttribution = _attribution(
    sourceId: 73,
    author: "sistab2",
    isTranslation: false)
  private static let _benchTranslationAttribution = _attribution(
    sourceId: 192,
    author: "sistab2",
    isTranslation: true)
  private static let _deadliftBaseAttribution = _attribution(
    sourceId: 184,
    author: "wger.de",
    isTranslation: false)
  private static let _deadliftTranslationAttribution = _attribution(
    sourceId: 105,
    author: "wger.de",
    isTranslation: true)

  private static func _attribution(sourceId: Int, author: String, isTranslation: Bool)
    -> CatalogAttribution
  {
    .init(
      licenseId: "cc-by-sa-3.0", licenseUrl: "https://creativecommons.org/licenses/by-sa/3.0/",
      licenseAuthor: author,
      licenseTitle: nil,
      attributionSourceUrl: isTranslation
        ? "https://wger.de/en/exercise/\(sourceId)/view"
        : "https://wger.de/api/v2/exerciseinfo/\(sourceId)/")
  }
  private static func date(
    _ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int, _ second: Int
  ) -> Date {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    return calendar.date(
      from: DateComponents(
        year: year, month: month, day: day, hour: hour, minute: minute, second: second))!
  }
}
