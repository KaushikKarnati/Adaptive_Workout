import '../../../domain/exercises/catalog/exercise_catalog.dart';

abstract final class BenchmarkCatalogSlice {
  static const schemaVersion = '1.0.0';
  static const catalogVersion = '2026.09.08.1';
  static const taxonomyVersion = 'v2';
  static const importToolVersion = '1.0.0';
  static const contentSha256 =
      '4bda4d4b43bba409c66585acb76d88c871cda97d9b13ca0fe732595488578eb4';

  static final retrievedAt = DateTime.utc(2026, 9, 8, 23, 14, 3);

  static final entries = List<ExerciseCatalogEntry>.unmodifiable(
    <ExerciseCatalogEntry>[_barbellBackSquat, _flatBenchPress, _deadlift],
  );

  static final manifest = ExerciseCatalogManifest(
    schemaVersion: schemaVersion,
    catalogVersion: catalogVersion,
    taxonomyVersion: taxonomyVersion,
    provider: 'wger',
    upstreamBaseUrl: Uri.parse('https://wger.de/api/v2/'),
    retrievedAt: retrievedAt,
    sourceRevision: null,
    entryCount: entries.length,
    contentSha256: contentSha256,
    importToolVersion: importToolVersion,
  );

  static const _pendingReview = CatalogReview(status: ReviewStatus.pending);

  static final _productReview = CatalogReview(
    status: ReviewStatus.approved,
    reviewerId: 'product_owner',
    reviewedAt: retrievedAt,
    evidenceReference: 'docs/SCIENCE.md',
  );

  static final _barbellBackSquat = ExerciseCatalogEntry(
    id: 'wger_a2f5b6efb78049c08d96fdaff23e27ce',
    wgerBaseId: 615,
    wgerBaseUuid: 'a2f5b6ef-b780-49c0-8d96-fdaff23e27ce',
    wgerTranslationId: 111,
    wgerTranslationUuid: 'c4856da3-8454-4857-8997-336d06df590f',
    wgerApiUrl: Uri.parse('https://wger.de/api/v2/exerciseinfo/615/'),
    wgerPageUrl: Uri.parse('https://wger.de/en/exercise/111/view'),
    sourceModifiedAt: DateTime.utc(2026, 4, 15, 20, 23, 56),
    name: 'Barbell Back Squat',
    aliases: const <String>{'Squats'},
    instructions: null,
    movementPatternIds: const <String>{'squat'},
    primaryMuscleIds: const <String>{'quadriceps'},
    secondaryMuscleIds: const <String>{'glutes'},
    equipmentRequirements: const <EquipmentRequirement>[
      EquipmentRequirement(equipmentId: 'standard_barbell', quantity: 1),
      EquipmentRequirement(equipmentId: 'weight_plates', quantity: 1),
      EquipmentRequirement(
        equipmentId: 'power_rack',
        quantity: 1,
        capabilityIds: <String>{'adjustable_height', 'safety_arms'},
      ),
    ],
    laterality: Laterality.bilateral,
    trackingMode: TrackingMode.loadReps,
    capabilityIds: const <String>{
      'bar_on_back_position',
      'deep_knee_flexion',
      'standing_unsupported',
      'sustained_grip',
    },
    exclusionTagIds: const <String>{
      'avoid_bar_on_back_position',
      'avoid_deep_knee_flexion',
      'avoid_sustained_grip',
    },
    variationGroupId: null,
    benchmark: Benchmark.barbellBackSquat,
    baseAttribution: _squatBaseAttribution,
    translationAttribution: _squatTranslationAttribution,
    wasModified: true,
    modificationNote: 'Display name normalized to the approved benchmark label; upstream instructions omitted pending science and safety review.',
    productReview: _productReview,
    scienceReview: _pendingReview,
    safetyReview: _pendingReview,
    equipmentReview: _pendingReview,
    licenseReview: _pendingReview,
    availability: ExerciseAvailability.disabled,
    disabledReason: 'Pending science, safety, equipment, and licensing review.',
  );

  static final _flatBenchPress = ExerciseCatalogEntry(
    id: 'wger_3717d14478154a979a56956fb889c996',
    wgerBaseId: 73,
    wgerBaseUuid: '3717d144-7815-4a97-9a56-956fb889c996',
    wgerTranslationId: 192,
    wgerTranslationUuid: '5da6340b-22ec-4c1b-a443-eef2f59f92f0',
    wgerApiUrl: Uri.parse('https://wger.de/api/v2/exerciseinfo/73/'),
    wgerPageUrl: Uri.parse('https://wger.de/en/exercise/192/view'),
    sourceModifiedAt: DateTime.utc(2026, 6, 19, 16, 46, 21),
    name: 'Flat Barbell Bench Press',
    aliases: const <String>{'Bench Press'},
    instructions: null,
    movementPatternIds: const <String>{'horizontal_push'},
    primaryMuscleIds: const <String>{'chest'},
    secondaryMuscleIds: const <String>{'front_deltoids', 'triceps'},
    equipmentRequirements: const <EquipmentRequirement>[
      EquipmentRequirement(equipmentId: 'standard_barbell', quantity: 1),
      EquipmentRequirement(equipmentId: 'weight_plates', quantity: 1),
      EquipmentRequirement(equipmentId: 'flat_bench', quantity: 1),
      EquipmentRequirement(
        equipmentId: 'power_rack',
        quantity: 1,
        capabilityIds: <String>{'adjustable_height', 'safety_arms'},
      ),
    ],
    laterality: Laterality.bilateral,
    trackingMode: TrackingMode.loadReps,
    capabilityIds: const <String>{'supine_position', 'sustained_grip'},
    exclusionTagIds: const <String>{'avoid_sustained_grip'},
    variationGroupId: null,
    benchmark: Benchmark.flatBarbellBenchPress,
    baseAttribution: _benchBaseAttribution,
    translationAttribution: _benchTranslationAttribution,
    wasModified: true,
    modificationNote: 'Display name normalized to the approved benchmark label; upstream instructions omitted pending science and safety review.',
    productReview: _productReview,
    scienceReview: _pendingReview,
    safetyReview: _pendingReview,
    equipmentReview: _pendingReview,
    licenseReview: _pendingReview,
    availability: ExerciseAvailability.disabled,
    disabledReason: 'Pending science, safety, equipment, and licensing review.',
  );

  static final _deadlift = ExerciseCatalogEntry(
    id: 'wger_ee8e8db42d8249e1ab7f891e9a354934',
    wgerBaseId: 184,
    wgerBaseUuid: 'ee8e8db4-2d82-49e1-ab7f-891e9a354934',
    wgerTranslationId: 105,
    wgerTranslationUuid: '22cca8fc-cfaf-4941-b0f7-faf9f2937c52',
    wgerApiUrl: Uri.parse('https://wger.de/api/v2/exerciseinfo/184/'),
    wgerPageUrl: Uri.parse('https://wger.de/en/exercise/105/view'),
    sourceModifiedAt: DateTime.utc(2026, 6, 19, 17, 55, 7),
    name: 'Conventional Barbell Deadlift',
    aliases: const <String>{'Deadlifts'},
    instructions: null,
    movementPatternIds: const <String>{'hinge'},
    primaryMuscleIds: const <String>{'lats'},
    secondaryMuscleIds: const <String>{'glutes'},
    equipmentRequirements: const <EquipmentRequirement>[
      EquipmentRequirement(equipmentId: 'standard_barbell', quantity: 1),
      EquipmentRequirement(equipmentId: 'weight_plates', quantity: 1),
    ],
    laterality: Laterality.bilateral,
    trackingMode: TrackingMode.loadReps,
    capabilityIds: const <String>{
      'loaded_hip_hinge',
      'standing_unsupported',
      'sustained_grip',
    },
    exclusionTagIds: const <String>{
      'avoid_loaded_hip_hinge',
      'avoid_sustained_grip',
    },
    variationGroupId: null,
    benchmark: Benchmark.conventionalBarbellDeadlift,
    baseAttribution: _deadliftBaseAttribution,
    translationAttribution: _deadliftTranslationAttribution,
    wasModified: true,
    modificationNote: 'Display name normalized to the approved benchmark label; upstream instructions omitted pending science and safety review.',
    productReview: _productReview,
    scienceReview: _pendingReview,
    safetyReview: _pendingReview,
    equipmentReview: _pendingReview,
    licenseReview: _pendingReview,
    availability: ExerciseAvailability.disabled,
    disabledReason: 'Pending science, safety, equipment, and licensing review.',
  );

  static final _squatBaseAttribution = _attribution(
    sourceId: 615,
    author: 'wger.de',
    isTranslation: false,
  );
  static final _squatTranslationAttribution = _attribution(
    sourceId: 111,
    author: 'wger.de',
    isTranslation: true,
  );
  static final _benchBaseAttribution = _attribution(
    sourceId: 73,
    author: 'sistab2',
    isTranslation: false,
  );
  static final _benchTranslationAttribution = _attribution(
    sourceId: 192,
    author: 'sistab2',
    isTranslation: true,
  );
  static final _deadliftBaseAttribution = _attribution(
    sourceId: 184,
    author: 'wger.de',
    isTranslation: false,
  );
  static final _deadliftTranslationAttribution = _attribution(
    sourceId: 105,
    author: 'wger.de',
    isTranslation: true,
  );

  static CatalogAttribution _attribution({
    required int sourceId,
    required String author,
    required bool isTranslation,
  }) => CatalogAttribution(
    licenseId: 'cc-by-sa-3.0',
    licenseUrl: Uri.parse('https://creativecommons.org/licenses/by-sa/3.0/'),
    licenseAuthor: author,
    licenseTitle: null,
    attributionSourceUrl: Uri.parse(
      isTranslation
          ? 'https://wger.de/en/exercise/$sourceId/view'
          : 'https://wger.de/api/v2/exerciseinfo/$sourceId/',
    ),
  );
}
