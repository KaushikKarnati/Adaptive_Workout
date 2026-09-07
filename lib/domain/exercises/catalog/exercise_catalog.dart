enum ReviewStatus { pending, approved, rejected }

enum ExerciseAvailability { enabled, disabled }

enum Laterality { bilateral, unilateral, alternating }

enum TrackingMode { loadReps, repsOnly, duration, distance, loadDistance }

enum Benchmark {
  barbellBackSquat,
  flatBarbellBenchPress,
  conventionalBarbellDeadlift,
}

final class ExerciseCatalogManifest {
  const ExerciseCatalogManifest({
    required this.schemaVersion,
    required this.catalogVersion,
    this.taxonomyVersion = 'v2',
    this.provider = 'wger',
    required this.upstreamBaseUrl,
    required this.retrievedAt,
    required this.sourceRevision,
    required this.entryCount,
    required this.contentSha256,
    required this.importToolVersion,
  });

  final String schemaVersion;
  final String catalogVersion;
  final String taxonomyVersion;
  final String provider;
  final Uri upstreamBaseUrl;
  final DateTime retrievedAt;
  final String? sourceRevision;
  final int entryCount;
  final String contentSha256;
  final String importToolVersion;
}

final class CatalogReview {
  const CatalogReview({
    required this.status,
    this.reviewerId,
    this.reviewedAt,
    this.evidenceReference,
  });

  final ReviewStatus status;
  final String? reviewerId;
  final DateTime? reviewedAt;
  final String? evidenceReference;
}

final class CatalogAttribution {
  const CatalogAttribution({
    required this.licenseId,
    required this.licenseUrl,
    required this.licenseAuthor,
    required this.licenseTitle,
    required this.attributionSourceUrl,
  });

  final String licenseId;
  final Uri licenseUrl;
  final String? licenseAuthor;
  final String? licenseTitle;
  final Uri attributionSourceUrl;
}

final class EquipmentRequirement {
  const EquipmentRequirement({
    required this.equipmentId,
    required this.quantity,
    this.capabilityIds = const <String>{},
  });

  final String equipmentId;
  final int quantity;
  final Set<String> capabilityIds;
}

final class ExerciseCatalogEntry {
  const ExerciseCatalogEntry({
    required this.id,
    required this.wgerBaseId,
    required this.wgerBaseUuid,
    required this.wgerTranslationId,
    required this.wgerTranslationUuid,
    required this.wgerApiUrl,
    required this.wgerPageUrl,
    required this.sourceModifiedAt,
    required this.name,
    this.aliases = const <String>{},
    required this.instructions,
    this.language = 'en',
    required this.movementPatternIds,
    required this.primaryMuscleIds,
    this.secondaryMuscleIds = const <String>{},
    this.equipmentRequirements = const <EquipmentRequirement>[],
    required this.laterality,
    required this.trackingMode,
    this.capabilityIds = const <String>{},
    this.exclusionTagIds = const <String>{},
    required this.variationGroupId,
    this.substitutionGroupIds = const <String>{},
    required this.benchmark,
    required this.baseAttribution,
    required this.translationAttribution,
    required this.wasModified,
    required this.modificationNote,
    required this.productReview,
    required this.scienceReview,
    required this.safetyReview,
    required this.equipmentReview,
    required this.licenseReview,
    required this.availability,
    required this.disabledReason,
  });

  final String id;
  final int wgerBaseId;
  final String wgerBaseUuid;
  final int wgerTranslationId;
  final String wgerTranslationUuid;
  final Uri wgerApiUrl;
  final Uri wgerPageUrl;
  final DateTime? sourceModifiedAt;
  final String name;
  final Set<String> aliases;
  final String? instructions;
  final String language;
  final Set<String> movementPatternIds;
  final Set<String> primaryMuscleIds;
  final Set<String> secondaryMuscleIds;
  final List<EquipmentRequirement> equipmentRequirements;
  final Laterality laterality;
  final TrackingMode trackingMode;
  final Set<String> capabilityIds;
  final Set<String> exclusionTagIds;
  final String? variationGroupId;
  final Set<String> substitutionGroupIds;
  final Benchmark? benchmark;
  final CatalogAttribution baseAttribution;
  final CatalogAttribution translationAttribution;
  final bool wasModified;
  final String? modificationNote;
  final CatalogReview productReview;
  final CatalogReview scienceReview;
  final CatalogReview safetyReview;
  final CatalogReview equipmentReview;
  final CatalogReview licenseReview;
  final ExerciseAvailability availability;
  final String? disabledReason;

  bool get isSelectable =>
      availability == ExerciseAvailability.enabled &&
      reviews.every((review) => review.status == ReviewStatus.approved);

  List<CatalogReview> get reviews => <CatalogReview>[
    productReview,
    scienceReview,
    safetyReview,
    equipmentReview,
    licenseReview,
  ];
}
