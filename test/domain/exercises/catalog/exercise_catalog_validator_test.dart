import 'package:adaptive_workout/domain/exercises/catalog/exercise_catalog.dart';
import 'package:adaptive_workout/domain/exercises/catalog/exercise_catalog_validator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final importedAt = DateTime.utc(2026, 9, 7, 12);
  final validator = ExerciseCatalogValidator(importedAt: importedAt);

  test('fully reviewed enabled entry is valid and selectable', () {
    final entry = validEntry();

    expect(validator.validate(entry), isEmpty);
    expect(entry.isSelectable, isTrue);
  });

  test('enabled entry with a pending review is rejected', () {
    final entry = validEntry(
      safetyReview: const CatalogReview(status: ReviewStatus.pending),
    );

    expect(
      validator.validate(entry).map((issue) => issue.code),
      contains('enabled_without_approvals'),
    );
    expect(entry.isSelectable, isFalse);
  });

  test('unknown taxonomy values and overlapping muscles are rejected', () {
    final entry = validEntry(
      movementPatternIds: const {'made_up_pattern'},
      secondaryMuscleIds: const {'chest'},
    );

    final codes = validator.validate(entry).map((issue) => issue.code);
    expect(codes, contains('unknown_taxonomy_id'));
    expect(codes, contains('overlapping_muscles'));
  });

  test('license URL must match the declared allowlisted license', () {
    final entry = validEntry(
      baseAttribution: CatalogAttribution(
        licenseId: 'cc-by-sa-4.0',
        licenseUrl: Uri.parse('https://creativecommons.org/licenses/by/4.0/'),
        licenseAuthor: 'Example author',
        licenseTitle: 'Example title',
        attributionSourceUrl: Uri.parse(
          'https://wger.de/api/v2/exerciseinfo/1/',
        ),
      ),
    );

    expect(
      validator.validate(entry).map((issue) => issue.code),
      contains('license_url_mismatch'),
    );
  });

  test('HTML and control characters are rejected from presentation text', () {
    final entry = validEntry(
      name: '<b>Bench press</b>',
      instructions: 'Press\tthe bar.',
    );

    final issues = validator.validate(entry);
    expect(issues.where((issue) => issue.code == 'unsafe_text'), hasLength(2));
  });

  test('line feeds are allowed only in fields that explicitly permit them', () {
    final entry = validEntry(
      name: 'Bench\npress',
      instructions: 'Lower the bar.\nPress under control.',
    );

    final unsafeFields = validator
        .validate(entry)
        .where((issue) => issue.code == 'unsafe_text')
        .map((issue) => issue.field);

    expect(unsafeFields, contains('name'));
    expect(unsafeFields, isNot(contains('instructions')));
  });

  test('review evidence rejects markup and paths outside docs', () {
    final entry = validEntry(
      safetyReview: CatalogReview(
        status: ReviewStatus.approved,
        reviewerId: 'reviewer_one',
        reviewedAt: DateTime.utc(2026, 9, 7, 10),
        evidenceReference: '<script>alert(1)</script>',
      ),
    );

    final codes = validator.validate(entry).map((issue) => issue.code);
    expect(codes, contains('unsafe_text'));
    expect(codes, contains('invalid_evidence_reference'));
  });

  test('review evidence accepts an HTTPS URL only from an allowed host', () {
    const allowedHost = 'evidence.example.com';
    final review = CatalogReview(
      status: ReviewStatus.approved,
      reviewerId: 'reviewer_one',
      reviewedAt: DateTime.utc(2026, 9, 7, 10),
      evidenceReference: 'https://$allowedHost/reviews/bench-press',
    );
    final entry = validEntry(safetyReview: review);

    expect(
      validator.validate(entry).map((issue) => issue.code),
      contains('invalid_evidence_reference'),
    );
    expect(
      ExerciseCatalogValidator(
        importedAt: importedAt,
        allowedEvidenceHosts: const {allowedHost},
      ).validate(entry),
      isEmpty,
    );
  });

  test('disabled entry requires a reason and is never selectable', () {
    final entry = validEntry(
      availability: ExerciseAvailability.disabled,
      disabledReason: null,
    );

    expect(
      validator.validate(entry).map((issue) => issue.code),
      contains('required_when_disabled'),
    );
    expect(entry.isSelectable, isFalse);
  });
}

ExerciseCatalogEntry validEntry({
  String name = 'Barbell bench press',
  String? instructions = 'Lower the bar under control.',
  Set<String> movementPatternIds = const {'horizontal_push'},
  Set<String> secondaryMuscleIds = const {'triceps'},
  CatalogAttribution? baseAttribution,
  CatalogReview? safetyReview,
  ExerciseAvailability availability = ExerciseAvailability.enabled,
  String? disabledReason,
}) {
  final approved = CatalogReview(
    status: ReviewStatus.approved,
    reviewerId: 'reviewer_one',
    reviewedAt: DateTime.utc(2026, 9, 7, 10),
    evidenceReference: 'docs/reviews/example.md',
  );
  final attribution = CatalogAttribution(
    licenseId: 'cc-by-sa-4.0',
    licenseUrl: Uri.parse('https://creativecommons.org/licenses/by-sa/4.0/'),
    licenseAuthor: 'Example author',
    licenseTitle: 'Example title',
    attributionSourceUrl: Uri.parse('https://wger.de/api/v2/exerciseinfo/1/'),
  );
  return ExerciseCatalogEntry(
    id: 'wger_123e4567e89b42d3a456426614174000',
    wgerBaseId: 1,
    wgerBaseUuid: '123e4567-e89b-42d3-a456-426614174000',
    wgerTranslationId: 2,
    wgerTranslationUuid: '123e4567-e89b-42d3-a456-426614174001',
    wgerApiUrl: Uri.parse('https://wger.de/api/v2/exerciseinfo/1/'),
    wgerPageUrl: Uri.parse('https://wger.de/en/exercise/2/view'),
    sourceModifiedAt: DateTime.utc(2026, 9, 6),
    name: name,
    instructions: instructions,
    movementPatternIds: movementPatternIds,
    primaryMuscleIds: const {'chest'},
    secondaryMuscleIds: secondaryMuscleIds,
    equipmentRequirements: const [
      EquipmentRequirement(equipmentId: 'standard_barbell', quantity: 1),
      EquipmentRequirement(equipmentId: 'flat_bench', quantity: 1),
    ],
    laterality: Laterality.bilateral,
    trackingMode: TrackingMode.loadReps,
    variationGroupId: 'bench_press_variants',
    benchmark: Benchmark.flatBarbellBenchPress,
    baseAttribution: baseAttribution ?? attribution,
    translationAttribution: attribution,
    wasModified: false,
    modificationNote: null,
    productReview: approved,
    scienceReview: approved,
    safetyReview: safetyReview ?? approved,
    equipmentReview: approved,
    licenseReview: approved,
    availability: availability,
    disabledReason: disabledReason,
  );
}
