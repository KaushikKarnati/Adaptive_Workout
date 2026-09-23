import 'dart:io';

import 'package:adaptive_workout/data/catalog/wger/benchmark_catalog_slice.dart';
import 'package:adaptive_workout/data/catalog/wger/wger_source_mapper.dart';
import 'package:adaptive_workout/domain/exercises/catalog/catalog_integrity.dart';
import 'package:adaptive_workout/domain/exercises/catalog/exercise_catalog.dart';
import 'package:adaptive_workout/domain/exercises/catalog/exercise_catalog_manifest_validator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final validator = ExerciseCatalogManifestValidator(
    importedAt: BenchmarkCatalogSlice.retrievedAt,
  );

  test('pinned source maps the three real wger records deterministically', () {
    final source = File('test/fixtures/wger/benchmark_snapshot_2026_09_08.json')
        .readAsStringSync();
    final first = const WgerSourceMapper().mapPinnedSnapshot(source);
    final second = const WgerSourceMapper().mapPinnedSnapshot(source);

    expect(first.map((result) => result.sourceBaseId), <int>[73, 184, 615]);
    expect(
      first.map((result) => result.outcome),
      everyElement(WgerImportOutcome.acceptedDisabled),
    );
    expect(
      first.map((result) => result.candidate!.id),
      second.map((result) => result.candidate!.id),
    );
  });

  test('reviewed projection preserves source identity and attribution', () {
    final source = File('test/fixtures/wger/benchmark_snapshot_2026_09_08.json')
        .readAsStringSync();
    final mappedByBaseId = <int, WgerMappedExerciseCandidate>{
      for (final result in const WgerSourceMapper().mapPinnedSnapshot(source))
        result.sourceBaseId!: result.candidate!,
    };

    for (final entry in BenchmarkCatalogSlice.entries) {
      final sourceEntry = mappedByBaseId[entry.wgerBaseId]!;
      expect(entry.id, sourceEntry.id);
      expect(entry.wgerBaseUuid, sourceEntry.wgerBaseUuid);
      expect(entry.wgerTranslationId, sourceEntry.wgerTranslationId);
      expect(entry.wgerTranslationUuid, sourceEntry.wgerTranslationUuid);
      expect(entry.sourceModifiedAt, sourceEntry.sourceModifiedAt);
      expect(
        entry.baseAttribution.licenseId,
        sourceEntry.baseAttribution.licenseId,
      );
      expect(
        entry.baseAttribution.licenseAuthor,
        sourceEntry.baseAttribution.licenseAuthor,
      );
      expect(
        entry.translationAttribution.licenseId,
        sourceEntry.translationAttribution.licenseId,
      );
      expect(
        entry.translationAttribution.licenseAuthor,
        sourceEntry.translationAttribution.licenseAuthor,
      );
    }
  });

  test('slice contains exactly one record for each approved benchmark', () {
    expect(BenchmarkCatalogSlice.entries, hasLength(3));
    expect(
      BenchmarkCatalogSlice.entries.map((entry) => entry.benchmark).toSet(),
      Benchmark.values.toSet(),
    );
    expect(
      BenchmarkCatalogSlice.entries.map((entry) => entry.name).toSet(),
      <String>{
        'Barbell Back Squat',
        'Flat Barbell Bench Press',
        'Conventional Barbell Deadlift',
      },
    );
  });

  test('manifest and every disabled review record validate as a whole', () {
    expect(
      validator.validate(
        BenchmarkCatalogSlice.manifest,
        BenchmarkCatalogSlice.entries,
      ),
      isEmpty,
    );
    expect(
      BenchmarkCatalogSlice.entries,
      everyElement(
        isA<ExerciseCatalogEntry>()
            .having((entry) => entry.isSelectable, 'isSelectable', isFalse)
            .having(
              (entry) => entry.availability,
              'availability',
              ExerciseAvailability.disabled,
            )
            .having(
              (entry) => entry.scienceReview.status,
              'science review',
              ReviewStatus.pending,
            )
            .having(
              (entry) => entry.safetyReview.status,
              'safety review',
              ReviewStatus.pending,
            )
            .having(
              (entry) => entry.equipmentReview.status,
              'equipment review',
              ReviewStatus.pending,
            )
            .having(
              (entry) => entry.licenseReview.status,
              'license review',
              ReviewStatus.pending,
            ),
      ),
    );
  });

  test('pinned raw fixture matches its documented SHA-256', () {
    final bytes = File('test/fixtures/wger/benchmark_snapshot_2026_09_08.json')
        .readAsBytesSync();

    expect(
      sha256Hex(bytes),
      'ddd51de5e62e43fb768085840173b77c6f392ba28459d02a4a5f481fd8aa5721',
    );
  });

  test('catalog version pins the canonical entry payload digest', () {
    final actual = sha256Hex(
      canonicalCatalogEntriesBytes(BenchmarkCatalogSlice.entries),
    );

    expect(actual, BenchmarkCatalogSlice.contentSha256);
    expect(BenchmarkCatalogSlice.manifest.contentSha256, actual);
  });
}
