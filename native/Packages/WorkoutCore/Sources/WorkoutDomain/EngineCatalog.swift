import Foundation

public enum ReviewStatus: String, Codable, Sendable {
  case pending
  case approved
  case rejected
}
public enum ExerciseAvailability: String, Codable, Sendable {
  case enabled
  case disabled
}
public enum Laterality: String, Codable, Sendable {
  case bilateral
  case unilateral
  case alternating
}
public enum TrackingMode: String, Codable, Sendable {
  case loadReps = "load_reps"
  case repsOnly = "reps_only"
  case duration
  case distance
  case loadDistance = "load_distance"
}
public enum Benchmark: String, Codable, Sendable {
  case barbellBackSquat = "barbell_back_squat"
  case flatBarbellBenchPress = "flat_barbell_bench_press"
  case conventionalBarbellDeadlift = "conventional_barbell_deadlift"
}

public struct ExerciseCatalogManifest: Equatable, Codable, Sendable {
  public let schemaVersion: String
  public let catalogVersion: String
  public let taxonomyVersion: String
  public let provider: String
  public let upstreamBaseUrl: String
  public let retrievedAt: Date
  public let sourceRevision: String?
  public let entryCount: Int
  public let contentSha256: String
  public let importToolVersion: String
  public init(
    schemaVersion: String, catalogVersion: String, taxonomyVersion: String = "v2",
    provider: String = "wger", upstreamBaseUrl: String, retrievedAt: Date,
    sourceRevision: String? = nil, entryCount: Int, contentSha256: String, importToolVersion: String
  ) {
    self.schemaVersion = schemaVersion
    self.catalogVersion = catalogVersion
    self.taxonomyVersion = taxonomyVersion
    self.provider = provider
    self.upstreamBaseUrl = upstreamBaseUrl
    self.retrievedAt = retrievedAt
    self.sourceRevision = sourceRevision
    self.entryCount = entryCount
    self.contentSha256 = contentSha256
    self.importToolVersion = importToolVersion
  }
}

public struct CatalogReview: Equatable, Codable, Sendable {
  public let status: ReviewStatus
  public let reviewerId: String?
  public let reviewedAt: Date?
  public let evidenceReference: String?
  public init(
    status: ReviewStatus, reviewerId: String? = nil, reviewedAt: Date? = nil,
    evidenceReference: String? = nil
  ) {
    self.status = status
    self.reviewerId = reviewerId
    self.reviewedAt = reviewedAt
    self.evidenceReference = evidenceReference
  }
  var canonical: EngineJSON {
    .object([
      "status": .string(status.rawValue),
      "reviewerId": reviewerId.map { .string($0) } ?? .null,
      "reviewedAt": reviewedAt.map { .string(engineTimestamp($0)) } ?? .null,
      "evidenceReference": evidenceReference.map { .string($0) } ?? .null,
    ])
  }
}

public struct CatalogAttribution: Equatable, Codable, Sendable {
  public let licenseId: String
  public let licenseUrl: String
  public let licenseAuthor: String?
  public let licenseTitle: String?
  public let attributionSourceUrl: String
  public init(
    licenseId: String, licenseUrl: String, licenseAuthor: String? = nil,
    licenseTitle: String? = nil, attributionSourceUrl: String
  ) {
    self.licenseId = licenseId
    self.licenseUrl = licenseUrl
    self.licenseAuthor = licenseAuthor
    self.licenseTitle = licenseTitle
    self.attributionSourceUrl = attributionSourceUrl
  }
  var canonical: EngineJSON {
    .object([
      "licenseId": .string(licenseId),
      "licenseUrl": .string(licenseUrl),
      "licenseAuthor": licenseAuthor.map { .string($0) } ?? .null,
      "licenseTitle": licenseTitle.map { .string($0) } ?? .null,
      "attributionSourceUrl": .string(attributionSourceUrl),
    ])
  }
}

public struct EquipmentRequirement: Equatable, Codable, Sendable {
  public let equipmentId: String
  public let quantity: Int
  public let capabilityIds: Set<String>
  public init(equipmentId: String, quantity: Int, capabilityIds: Set<String> = []) {
    self.equipmentId = equipmentId
    self.quantity = quantity
    self.capabilityIds = capabilityIds
  }
  var canonical: EngineJSON {
    .object([
      "equipmentId": .string(equipmentId),
      "quantity": .integer(quantity),
      "capabilityIds": .strings(capabilityIds.sorted(by: engineUnicodeLess)),
    ])
  }
}

public struct ExerciseCatalogEntry: Equatable, Codable, Sendable {
  public let id: String
  public let wgerBaseId: Int
  public let wgerBaseUuid: String
  public let wgerTranslationId: Int
  public let wgerTranslationUuid: String
  public let wgerApiUrl: String
  public let wgerPageUrl: String
  public let sourceModifiedAt: Date?
  public let name: String
  public let aliases: Set<String>
  public let instructions: String?
  public let language: String
  public let movementPatternIds: Set<String>
  public let primaryMuscleIds: Set<String>
  public let secondaryMuscleIds: Set<String>
  public let equipmentRequirements: [EquipmentRequirement]
  public let laterality: Laterality
  public let trackingMode: TrackingMode
  public let capabilityIds: Set<String>
  public let exclusionTagIds: Set<String>
  public let variationGroupId: String?
  public let substitutionGroupIds: Set<String>
  public let benchmark: Benchmark?
  public let baseAttribution: CatalogAttribution
  public let translationAttribution: CatalogAttribution
  public let wasModified: Bool
  public let modificationNote: String?
  public let productReview: CatalogReview
  public let scienceReview: CatalogReview
  public let safetyReview: CatalogReview
  public let equipmentReview: CatalogReview
  public let licenseReview: CatalogReview
  public let availability: ExerciseAvailability
  public let disabledReason: String?
  public init(
    id: String, wgerBaseId: Int, wgerBaseUuid: String, wgerTranslationId: Int,
    wgerTranslationUuid: String, wgerApiUrl: String, wgerPageUrl: String,
    sourceModifiedAt: Date? = nil, name: String, aliases: Set<String> = [],
    instructions: String? = nil, language: String = "en", movementPatternIds: Set<String>,
    primaryMuscleIds: Set<String>, secondaryMuscleIds: Set<String> = [],
    equipmentRequirements: [EquipmentRequirement] = [], laterality: Laterality,
    trackingMode: TrackingMode, capabilityIds: Set<String> = [], exclusionTagIds: Set<String> = [],
    variationGroupId: String? = nil, substitutionGroupIds: Set<String> = [],
    benchmark: Benchmark? = nil, baseAttribution: CatalogAttribution,
    translationAttribution: CatalogAttribution, wasModified: Bool, modificationNote: String? = nil,
    productReview: CatalogReview, scienceReview: CatalogReview, safetyReview: CatalogReview,
    equipmentReview: CatalogReview, licenseReview: CatalogReview,
    availability: ExerciseAvailability, disabledReason: String? = nil
  ) {
    self.id = id
    self.wgerBaseId = wgerBaseId
    self.wgerBaseUuid = wgerBaseUuid
    self.wgerTranslationId = wgerTranslationId
    self.wgerTranslationUuid = wgerTranslationUuid
    self.wgerApiUrl = wgerApiUrl
    self.wgerPageUrl = wgerPageUrl
    self.sourceModifiedAt = sourceModifiedAt
    self.name = name
    self.aliases = aliases
    self.instructions = instructions
    self.language = language
    self.movementPatternIds = movementPatternIds
    self.primaryMuscleIds = primaryMuscleIds
    self.secondaryMuscleIds = secondaryMuscleIds
    self.equipmentRequirements = equipmentRequirements
    self.laterality = laterality
    self.trackingMode = trackingMode
    self.capabilityIds = capabilityIds
    self.exclusionTagIds = exclusionTagIds
    self.variationGroupId = variationGroupId
    self.substitutionGroupIds = substitutionGroupIds
    self.benchmark = benchmark
    self.baseAttribution = baseAttribution
    self.translationAttribution = translationAttribution
    self.wasModified = wasModified
    self.modificationNote = modificationNote
    self.productReview = productReview
    self.scienceReview = scienceReview
    self.safetyReview = safetyReview
    self.equipmentReview = equipmentReview
    self.licenseReview = licenseReview
    self.availability = availability
    self.disabledReason = disabledReason
  }
  public var reviews: [CatalogReview] {
    [productReview, scienceReview, safetyReview, equipmentReview, licenseReview]
  }
  public var isSelectable: Bool {
    availability == .enabled && reviews.allSatisfy { $0.status == .approved }
  }
  var canonical: EngineJSON {
    .object([
      "id": .string(id),
      "wgerBaseId": .integer(wgerBaseId),
      "wgerBaseUuid": .string(wgerBaseUuid),
      "wgerTranslationId": .integer(wgerTranslationId),
      "wgerTranslationUuid": .string(wgerTranslationUuid),
      "wgerApiUrl": .string(wgerApiUrl),
      "wgerPageUrl": .string(wgerPageUrl),
      "sourceModifiedAt": sourceModifiedAt.map { .string(engineTimestamp($0)) } ?? .null,
      "name": .string(name),
      "aliases": .strings(aliases.sorted(by: engineUnicodeLess)),
      "instructions": instructions.map { .string($0) } ?? .null,
      "language": .string(language),
      "movementPatternIds": .strings(movementPatternIds.sorted(by: engineUnicodeLess)),
      "primaryMuscleIds": .strings(primaryMuscleIds.sorted(by: engineUnicodeLess)),
      "secondaryMuscleIds": .strings(secondaryMuscleIds.sorted(by: engineUnicodeLess)),
      "equipmentRequirements": .array(
        equipmentRequirements.sorted { $0.equipmentId < $1.equipmentId }.map(\.canonical)),
      "laterality": .string(laterality.rawValue),
      "trackingMode": .string(trackingMode.rawValue),
      "capabilityIds": .strings(capabilityIds.sorted(by: engineUnicodeLess)),
      "exclusionTagIds": .strings(exclusionTagIds.sorted(by: engineUnicodeLess)),
      "variationGroupId": variationGroupId.map { .string($0) } ?? .null,
      "substitutionGroupIds": .strings(substitutionGroupIds.sorted(by: engineUnicodeLess)),
      "benchmark": benchmark.map { .string($0.rawValue) } ?? .null,
      "baseAttribution": baseAttribution.canonical,
      "translationAttribution": translationAttribution.canonical,
      "wasModified": .bool(wasModified),
      "modificationNote": modificationNote.map { .string($0) } ?? .null,
      "productReview": productReview.canonical,
      "scienceReview": scienceReview.canonical,
      "safetyReview": safetyReview.canonical,
      "equipmentReview": equipmentReview.canonical,
      "licenseReview": licenseReview.canonical,
      "availability": .string(availability.rawValue),
      "disabledReason": disabledReason.map { .string($0) } ?? .null,
    ])
  }
}
