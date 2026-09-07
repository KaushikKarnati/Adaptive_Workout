import 'dart:convert';

import 'package:adaptive_workout/domain/exercises/catalog/catalog_integrity.dart';
import 'package:adaptive_workout/domain/exercises/catalog/exercise_catalog.dart';
import 'package:adaptive_workout/domain/exercises/catalog/exercise_catalog_manifest_validator.dart';
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

  group('catalog manifest validation', () {
    final manifestValidator = ExerciseCatalogManifestValidator(
      importedAt: importedAt,
    );

    test('accepts matching manifest, entry count, and integrity digest', () {
      final entries = <ExerciseCatalogEntry>[validEntry()];
      final manifest = validManifest(entries);

      expect(manifestValidator.validate(manifest, entries), isEmpty);
    });

    test('SHA-256 implementation matches a published test vector', () {
      expect(
        sha256Hex(utf8.encode('abc')),
        'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
      );
    });

    test('detects all catalog identity duplicates and benchmark reuse', () {
      final entry = validEntry();
      final entries = <ExerciseCatalogEntry>[entry, entry];
      final issues = manifestValidator.validate(
        validManifest(entries),
        entries,
      );
      final duplicateFields = issues
          .where((issue) => issue.code == 'duplicate_value')
          .map((issue) => issue.field);

      expect(duplicateFields, contains('entries.1.id'));
      expect(duplicateFields, contains('entries.1.wgerBaseId'));
      expect(duplicateFields, contains('entries.1.wgerBaseUuid'));
      expect(duplicateFields, contains('entries.1.wgerTranslationId'));
      expect(duplicateFields, contains('entries.1.wgerTranslationUuid'));
      expect(duplicateFields, contains('entries.1.benchmark'));
    });

    test('rejects entry-count mismatch and out-of-range count', () {
      final entries = <ExerciseCatalogEntry>[validEntry()];
      final manifest = validManifest(entries, entryCount: 0);
      final codes = manifestValidator
          .validate(manifest, entries)
          .map((issue) => issue.code);

      expect(codes, contains('entry_count_out_of_range'));
      expect(codes, contains('entry_count_mismatch'));
    });

    test('rejects a well-formed but incorrect digest', () {
      final entries = <ExerciseCatalogEntry>[validEntry()];
      final manifest = validManifest(entries, contentSha256: '0' * 64);

      expect(
        manifestValidator
            .validate(manifest, entries)
            .map((issue) => issue.code),
        contains('integrity_digest_mismatch'),
      );
    });

    test('rejects an impossible calendar date in the catalog version', () {
      final entries = <ExerciseCatalogEntry>[validEntry()];
      final manifest = validManifest(entries, catalogVersion: '2026.02.31.1');

      expect(
        manifestValidator
            .validate(manifest, entries)
            .map((issue) => issue.code),
        contains('invalid_catalog_version'),
      );
    });

    test('passes configured evidence hosts to entry validation', () {
      const allowedHost = 'evidence.example.com';
      final entry = validEntry(
        safetyReview: CatalogReview(
          status: ReviewStatus.approved,
          reviewerId: 'reviewer_one',
          reviewedAt: DateTime.utc(2026, 9, 7, 10),
          evidenceReference: 'https://$allowedHost/reviews/bench-press',
        ),
      );
      final entries = <ExerciseCatalogEntry>[entry];
      final validatorWithEvidenceHost = ExerciseCatalogManifestValidator(
        importedAt: importedAt,
        allowedEvidenceHosts: const {allowedHost},
      );

      expect(
        validatorWithEvidenceHost.validate(validManifest(entries), entries),
        isEmpty,
      );
    });

    test(
      'canonical digest is independent of entry and set iteration order',
      () {
        final first = validEntry(
          aliases: const {'Bench', 'Barbell bench'},
          secondaryMuscleIds: const {'front_deltoids', 'triceps'},
        );
        final second = validEntry(
          id: 'wger_223e4567e89b42d3a456426614174000',
          wgerBaseId: 3,
          wgerBaseUuid: '223e4567-e89b-42d3-a456-426614174000',
          wgerTranslationId: 4,
          wgerTranslationUuid: '223e4567-e89b-42d3-a456-426614174001',
          benchmark: null,
        );
        final forward = canonicalCatalogEntriesBytes([first, second]);
        final reversed = canonicalCatalogEntriesBytes([second, first]);

        expect(reversed, forward);
        expect(sha256Hex(reversed), sha256Hex(forward));
      },
    );
  });
}

ExerciseCatalogEntry validEntry({
  String id = 'wger_123e4567e89b42d3a456426614174000',
  int wgerBaseId = 1,
  String wgerBaseUuid = '123e4567-e89b-42d3-a456-426614174000',
  int wgerTranslationId = 2,
  String wgerTranslationUuid = '123e4567-e89b-42d3-a456-426614174001',
  String name = 'Barbell bench press',
  String? instructions = 'Lower the bar under control.',
  Set<String> aliases = const {},
  Set<String> movementPatternIds = const {'horizontal_push'},
  Set<String> secondaryMuscleIds = const {'triceps'},
  CatalogAttribution? baseAttribution,
  CatalogReview? safetyReview,
  ExerciseAvailability availability = ExerciseAvailability.enabled,
  String? disabledReason,
  Benchmark? benchmark = Benchmark.flatBarbellBenchPress,
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
    id: id,
    wgerBaseId: wgerBaseId,
    wgerBaseUuid: wgerBaseUuid,
    wgerTranslationId: wgerTranslationId,
    wgerTranslationUuid: wgerTranslationUuid,
    wgerApiUrl: Uri.parse('https://wger.de/api/v2/exerciseinfo/1/'),
    wgerPageUrl: Uri.parse('https://wger.de/en/exercise/2/view'),
    sourceModifiedAt: DateTime.utc(2026, 9, 6),
    name: name,
    aliases: aliases,
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
    benchmark: benchmark,
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

ExerciseCatalogManifest validManifest(
  List<ExerciseCatalogEntry> entries, {
  int? entryCount,
  String? contentSha256,
  String catalogVersion = '2026.09.07.1',
}) => ExerciseCatalogManifest(
  schemaVersion: '1.0.0',
  catalogVersion: catalogVersion,
  upstreamBaseUrl: Uri.parse('https://wger.de/api/v2/'),
  retrievedAt: DateTime.utc(2026, 9, 7, 11),
  sourceRevision: null,
  entryCount: entryCount ?? entries.length,
  contentSha256:
      contentSha256 ?? sha256Hex(canonicalCatalogEntriesBytes(entries)),
  importToolVersion: '1.0.0',
);
