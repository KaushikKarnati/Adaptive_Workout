// Synthetic review records only; never bundled with the application.
import 'package:adaptive_workout/domain/exercises/catalog/catalog_integrity.dart';
import 'package:adaptive_workout/domain/exercises/catalog/exercise_catalog.dart';
import 'package:adaptive_workout/domain/exercises/eligibility/exercise_eligibility.dart';

ExerciseEligibilityRequest syntheticEligibility(
  List<ExerciseCatalogEntry> entries, {
  ExerciseCatalogManifest? manifest,
  String eligibilityRuleSetVersion = '1.0.0',
  String? requestSchemaVersion,
  String requestCatalogVersion = '2026.09.08.1',
  String? requestTaxonomyVersion,
  String? requestCatalogDigest,
  String? requestConstraintDigest,
  List<String>? candidateIds,
  List<EquipmentInventoryItem> inventory = const [],
  List<String> temporarilyUnavailable = const [],
  List<String> supportedCapabilities = const [],
  List<String> unsupportedCapabilities = const [],
  List<String> limitations = const [],
  List<String> persistentExclusions = const [],
  List<String> requestExclusions = const [],
  EligibilitySafetyState? safetyState,
  String? missingField,
}) {
  final actualManifest = manifest ?? syntheticManifest(entries);
  final actualConstraintDigest = eligibilityConstraintSnapshotSha256(
    equipmentInventory: inventory,
    temporarilyUnavailableEquipmentIds: temporarilyUnavailable,
    functionalCapabilityAssessment: FunctionalCapabilityAssessment(
      supportedIds: supportedCapabilities,
      unsupportedIds: unsupportedCapabilities,
    ),
    limitationAssessment: LimitationAssessment(ids: limitations),
    persistentExerciseExclusionIds: persistentExclusions,
    requestExerciseExclusionIds: requestExclusions,
  );
  return ExerciseEligibilityRequest(
    eligibilityRuleSetVersion: missingField == 'eligibilityRuleSetVersion'
        ? null
        : eligibilityRuleSetVersion,
    schemaVersion: missingField == 'schemaVersion'
        ? null
        : requestSchemaVersion ?? actualManifest.schemaVersion,
    catalogVersion: missingField == 'catalogVersion'
        ? null
        : requestCatalogVersion,
    taxonomyVersion: missingField == 'taxonomyVersion'
        ? null
        : requestTaxonomyVersion ?? actualManifest.taxonomyVersion,
    catalogContentSha256: missingField == 'catalogContentSha256'
        ? null
        : requestCatalogDigest ?? actualManifest.contentSha256,
    constraintSnapshotSha256: missingField == 'constraintSnapshotSha256'
        ? null
        : requestConstraintDigest ?? actualConstraintDigest,
    manifest: missingField == 'manifest' ? null : actualManifest,
    catalog: missingField == 'catalog' ? null : entries,
    candidateExerciseIds: missingField == 'candidateExerciseIds'
        ? null
        : candidateIds ?? entries.map((entry) => entry.id).toList(),
    equipmentInventory: missingField == 'equipmentInventory' ? null : inventory,
    temporarilyUnavailableEquipmentIds:
        missingField == 'temporarilyUnavailableEquipmentIds'
        ? null
        : temporarilyUnavailable,
    functionalCapabilityAssessment:
        missingField == 'functionalCapabilityAssessment'
        ? null
        : FunctionalCapabilityAssessment(
            supportedIds: supportedCapabilities,
            unsupportedIds: unsupportedCapabilities,
          ),
    limitationAssessment: missingField == 'limitationAssessment'
        ? null
        : LimitationAssessment(ids: limitations),
    persistentExerciseExclusionIds:
        missingField == 'persistentExerciseExclusionIds'
        ? null
        : persistentExclusions,
    requestExerciseExclusionIds: missingField == 'requestExerciseExclusionIds'
        ? null
        : requestExclusions,
    safetyState: missingField == 'safetyState'
        ? null
        : safetyState ??
              EligibilitySafetyState(
                version: '1.0.0',
                kind: EligibilitySafetyStateKind.clear,
              ),
  );
}

ExerciseCatalogManifest syntheticManifest(List<ExerciseCatalogEntry> entries) =>
    ExerciseCatalogManifest(
      schemaVersion: '1.0.0',
      catalogVersion: '2026.09.08.1',
      upstreamBaseUrl: Uri.parse('https://wger.de/api/v2/'),
      retrievedAt: DateTime.utc(2026, 9, 8, 12),
      sourceRevision: null,
      entryCount: entries.length,
      contentSha256: sha256Hex(canonicalCatalogEntriesBytes(entries)),
      importToolVersion: '1.0.0',
    );

ExerciseCatalogEntry syntheticEntry({
  required int seed,
  List<EquipmentRequirement> equipmentRequirements = const [],
  Set<String> capabilityIds = const {},
  Set<String> exclusionTagIds = const {},
  ExerciseAvailability availability = ExerciseAvailability.enabled,
  String? disabledReason,
  String? name,
  Laterality laterality = Laterality.bilateral,
  TrackingMode trackingMode = TrackingMode.loadReps,
}) {
  final approved = CatalogReview(
    status: ReviewStatus.approved,
    reviewerId: 'reviewer_one',
    reviewedAt: DateTime.utc(2026, 9, 8, 10),
    evidenceReference: 'docs/reviews/example.md',
  );
  final attribution = CatalogAttribution(
    licenseId: 'cc-by-4.0',
    licenseUrl: Uri.parse('https://creativecommons.org/licenses/by/4.0/'),
    licenseAuthor: 'Example author',
    licenseTitle: 'Example title',
    attributionSourceUrl: Uri.parse(
      'https://wger.de/api/v2/exerciseinfo/$seed/',
    ),
  );
  final suffix = seed.toString().padLeft(12, '0');
  final translationSuffix = (seed + 100).toString().padLeft(12, '0');
  return ExerciseCatalogEntry(
    id: 'exercise_${seed.toString().padLeft(2, '0')}',
    wgerBaseId: seed,
    wgerBaseUuid: '10000000-0000-4000-8000-$suffix',
    wgerTranslationId: seed + 100,
    wgerTranslationUuid: '20000000-0000-4000-8000-$translationSuffix',
    wgerApiUrl: Uri.parse('https://wger.de/api/v2/exerciseinfo/$seed/'),
    wgerPageUrl: Uri.parse('https://wger.de/en/exercise/${seed + 100}/view'),
    sourceModifiedAt: DateTime.utc(2026, 9, 8, 9),
    name: name ?? 'Synthetic exercise $seed',
    instructions: 'Synthetic test-only instructions.',
    movementPatternIds: const {'horizontal_push'},
    primaryMuscleIds: const {'chest'},
    equipmentRequirements: equipmentRequirements,
    laterality: laterality,
    trackingMode: trackingMode,
    capabilityIds: capabilityIds,
    exclusionTagIds: exclusionTagIds,
    variationGroupId: null,
    benchmark: null,
    baseAttribution: attribution,
    translationAttribution: attribution,
    wasModified: false,
    modificationNote: null,
    productReview: approved,
    scienceReview: approved,
    safetyReview: approved,
    equipmentReview: approved,
    licenseReview: approved,
    availability: availability,
    disabledReason: disabledReason,
  );
}
