import 'dart:convert';
import 'dart:io';

import 'package:adaptive_workout/data/catalog/wger/wger_source_mapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const mapper = WgerSourceMapper();
  late String fixture;

  setUpAll(() {
    fixture = File('test/fixtures/wger/pinned_snapshot.json')
        .readAsStringSync();
  });

  test('maps a pinned record deterministically into a disabled candidate', () {
    final first = mapper.mapPinnedSnapshot(fixture);
    final second = mapper.mapPinnedSnapshot(fixture);
    final result = first.first;
    final candidate = result.candidate!;

    expect(result.outcome, WgerImportOutcome.acceptedDisabled);
    expect(
      result.reasonCodes,
      orderedEquals(<String>[
        'bench_requirement_confirmation_required',
        'manual_classification_required',
        'manual_reviews_required',
      ]),
    );
    expect(candidate.id, 'wger_123e4567e89b42d3a456426614174000');
    expect(candidate.wgerBaseId, 101);
    expect(candidate.wgerTranslationId, 201);
    expect(candidate.name, 'Fixture bench press');
    expect(candidate.aliases, <String>{'Fixture press'});
    expect(candidate.instructions, 'Lower the bar under control.');
    expect(candidate.primaryMuscleIds, <String>{'chest'});
    expect(candidate.secondaryMuscleIds, <String>{'triceps'});
    expect(
      candidate.equipmentCandidates.map((value) => value.equipmentId),
      orderedEquals(<String>['flat_bench', 'standard_barbell']),
    );
    expect(candidate.sourceCategoryId, 11);
    expect(candidate.baseAttribution.licenseId, 'cc-by-sa-4.0');
    expect(candidate.translationAttribution.licenseId, 'cc-by-sa-4.0');
    expect(second.first.reasonCodes, first.first.reasonCodes);
    expect(second.first.candidate!.id, candidate.id);
  });

  test('rejects an exercise that references an unsupported muscle', () {
    final result = mapper.mapPinnedSnapshot(fixture)[1];

    expect(result.sourceBaseId, 102);
    expect(result.outcome, WgerImportOutcome.rejected);
    expect(result.reasonCodes, <String>['unsupported_muscle_3']);
    expect(result.candidate, isNull);
  });

  test('fails the pinned snapshot when an exact dictionary name changes', () {
    final snapshot = _fixtureObject(fixture);
    final muscles = snapshot['muscles']! as List<dynamic>;
    (muscles.first as Map<String, dynamic>)['name'] = 'Changed upstream name';

    expect(
      () => mapper.mapPinnedSnapshot(jsonEncode(snapshot)),
      throwsA(
        isA<WgerSnapshotValidationException>()
            .having((error) => error.code, 'code', 'dictionary_mismatch')
            .having((error) => error.field, 'field', 'muscles'),
      ),
    );
  });

  test('reports malformed JSON as a snapshot failure', () {
    expect(
      () => mapper.mapPinnedSnapshot('{'),
      throwsA(
        isA<WgerSnapshotValidationException>()
            .having((error) => error.code, 'code', 'invalid_json')
            .having((error) => error.field, 'field', 'root'),
      ),
    );
  });

  test('does not import rendered HTML or unsafe source instructions', () {
    final snapshot = _fixtureObject(fixture);
    final translation = _firstTranslation(snapshot);
    translation['description_source'] = '<p>Do not import this</p>';

    final result = mapper.mapPinnedSnapshot(jsonEncode(snapshot)).first;

    expect(result.candidate!.instructions, isNull);
    expect(result.reasonCodes, contains('instructions_manual_review_required'));
  });

  test('rejects records without exactly one English translation', () {
    final snapshot = _fixtureObject(fixture);
    final exercise = _firstExercise(snapshot);
    exercise['translations'] = <Object?>[];

    final result = mapper.mapPinnedSnapshot(jsonEncode(snapshot)).first;

    expect(result.outcome, WgerImportOutcome.rejected);
    expect(result.reasonCodes, <String>['english_translation_cardinality']);
  });

  test('rejects a conflicting English language label on a translation', () {
    final snapshot = _fixtureObject(fixture);
    _firstTranslation(snapshot)['language'] = <String, Object?>{
      'id': 2,
      'short_name': 'fr',
    };

    final result = mapper.mapPinnedSnapshot(jsonEncode(snapshot)).first;

    expect(result.outcome, WgerImportOutcome.rejected);
    expect(result.reasonCodes, <String>['language_name_mismatch']);
  });

  test('fails the snapshot when language short names are duplicated', () {
    final snapshot = _fixtureObject(fixture);
    final languages = snapshot['languages']! as List<dynamic>;
    languages.add(<String, Object?>{'id': 99, 'short_name': 'en'});

    expect(
      () => mapper.mapPinnedSnapshot(jsonEncode(snapshot)),
      throwsA(
        isA<WgerSnapshotValidationException>()
            .having((error) => error.code, 'code', 'duplicate_dictionary_name')
            .having((error) => error.field, 'field', 'languages'),
      ),
    );
  });

  test('rejects ODbL independently at the base or translation level', () {
    final snapshot = _fixtureObject(fixture);
    _firstExercise(snapshot)['license'] = <String, Object?>{
      'id': 5,
      'name': 'ODbL',
    };

    final result = mapper.mapPinnedSnapshot(jsonEncode(snapshot)).first;

    expect(result.outcome, WgerImportOutcome.rejected);
    expect(result.reasonCodes, <String>['unsupported_license_5']);
  });

  test('an empty equipment list stays disabled and never means bodyweight', () {
    final snapshot = _fixtureObject(fixture);
    final exercise = _firstExercise(snapshot);
    exercise['equipment'] = <Object?>[];

    final result = mapper.mapPinnedSnapshot(jsonEncode(snapshot)).first;

    expect(result.outcome, WgerImportOutcome.acceptedDisabled);
    expect(result.candidate!.equipmentCandidates, isEmpty);
    expect(result.reasonCodes, contains('equipment_review_empty_source'));
  });
}

Map<String, dynamic> _fixtureObject(String fixture) =>
    jsonDecode(fixture) as Map<String, dynamic>;

Map<String, dynamic> _firstExercise(Map<String, dynamic> snapshot) =>
    (snapshot['exercises']! as List<dynamic>).first as Map<String, dynamic>;

Map<String, dynamic> _firstTranslation(Map<String, dynamic> snapshot) =>
    (_firstExercise(snapshot)['translations']! as List<dynamic>).first
        as Map<String, dynamic>;
