import 'package:adaptive_workout/domain/logging/practice_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('pounds convert exactly without floating point rounding', () {
    expect(parsePounds('30.125001'), 30125001);
    expect(formatPounds(30125001), '30.125001');
    expect(formatPounds(parsePounds('30.000000')), '30');
    expect(parsePounds('0'), 0);
  });
  for (final value in [
    'NaN',
    'Infinity',
    '-1',
    '1e3',
    '30 kg',
    '1.0000001',
    '',
    '1000001',
  ]) {
    test('rejects invalid pounds $value', () {
      expect(() => parsePounds(value), throwsA(isA<LoggingException>()));
    });
  }
  test('record survives serialization with missing RIR distinct from zero', () {
    const record = PracticeSet(
      id: 'set_1',
      exerciseId: 'practice_press',
      index: 1,
      microPounds: 30000000,
      reps: 10,
      rir: null,
      working: false,
      validity: SetValidity.unknown,
    );
    expect(PracticeSet.fromJson(record.toJson()).toJson(), record.toJson());
    expect(PracticeSet.fromJson(record.toJson()).rir, isNull);
  });
  for (final change in <Map<String, dynamic>>[
    {'microPounds': -1},
    {'reps': -1},
    {'reps': 1.5},
    {'rir': -1},
    {'validity': 'invented'},
    {'exerciseId': 'unknown'},
    {'index': 0},
    {'working': null},
    {'microPounds': double.infinity},
    {'skipped': true},
  ]) {
    test('rejects malformed stored set $change', () {
      final data = const PracticeSet(
        id: 'set_1',
        exerciseId: 'practice_press',
        index: 1,
        microPounds: 30000000,
        reps: 10,
        rir: 2,
        working: true,
        validity: SetValidity.valid,
      ).toJson();
      expect(
        () => PracticeSet.fromJson({...data, ...change}),
        throwsA(isA<LoggingException>()),
      );
    });
  }
  test('skip preserves explicit missing actuals', () {
    const record = PracticeSet(
      id: 'set_1',
      exerciseId: 'practice_row',
      index: 1,
      microPounds: null,
      reps: null,
      rir: null,
      working: true,
      validity: SetValidity.unknown,
      skipped: true,
    );
    expect(record.validate, returnsNormally);
  });
}
