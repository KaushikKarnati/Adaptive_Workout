import 'dart:convert';

import 'package:adaptive_workout/domain/training/training_setup.dart';
import 'package:adaptive_workout/domain/training/setup_variations.dart';
import 'package:adaptive_workout/domain/workout/owner_program.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/training_setup_fixture.dart';

void main() {
  test(
    'exact pounds parser rejects guessing rounding units and nonfinite values',
    () {
      expect(parsePounds('25.125001'), 25125001);
      expect(parsePounds('0.000001'), 1);
      expect(parsePounds('1000000'), 1000000000000);
      expect(displayPounds(25125001), '25.125001');
      for (final value in [
        '',
        'about 70',
        '25 lb',
        '-1',
        'NaN',
        'Infinity',
        '1e2',
        '0.0000001',
        '1000000.000001',
      ]) {
        expect(() => parsePounds(value), throwsA(isA<SetupException>()));
      }
    },
  );
  test('roundtrip keeps unassessed values unknown and never enables recommendations', () {
    final p = fixtureProfile(
      equipment: [fixtureEquipment()],
      baselines: [fixtureBaseline()],
    );
    final restored = TrainingSetup.decode(p.encode());
    expect(restored.encode(), p.encode());
    expect(restored.limitations, isNull);
    expect(restored.supportedCapabilities, isNull);
    expect(restored.recommendationEligible, isFalse);
    expect(restored.baselineIsCurrent(restored.startingLoads.single), isTrue);
  });
  test(
    'canonical serialization handles ordering and input list immutability',
    () {
      final days = [4, 2];
      final p = fixtureProfile(days: days);
      days.clear();
      expect(p.encode(), fixtureProfile().encode());
      expect(() => p.trainingDays.clear(), throwsUnsupportedError);
      expect(() => p.equipment.clear(), throwsUnsupportedError);
    },
  );
  test(
    'draft equipment is allowed but cannot carry a verified starting load',
    () {
      expect(
        fixtureProfile(equipment: [fixtureEquipment(confirmed: false)])
            .equipment
            .single
            .confirmed,
        isFalse,
      );
      expect(
        () => fixtureProfile(
          equipment: [fixtureEquipment(confirmed: false)],
          baselines: [fixtureBaseline()],
        ),
        throwsA(isA<SetupException>()),
      );
    },
  );
  test('settings revision invalidates earlier baseline without erasing it', () {
    final old = fixtureProfile(
      equipment: [fixtureEquipment()],
      baselines: [fixtureBaseline()],
    );
    final next = fixtureProfile(
      revision: 1,
      equipment: [
        fixtureEquipment(revision: 1, settings: [25000000]),
      ],
      baselines: old.startingLoads,
    );
    validateSetupTransition(old, next);
    expect(next.baselineIsCurrent(next.startingLoads.single), isFalse);
    final confirmed = fixtureProfile(
      revision: 2,
      equipment: next.equipment,
      baselines: [
        StartingLoad(
          id: 'baseline',
          sessionId: 'monday',
          slotId: 'incline_dumbbell_press',
          variation: 'incline_dumbbell_press',
          setupId: 'machine',
          setupRevision: 1,
          convention: SetupLoadConvention.perDumbbell,
          microPounds: 25000000,
          confirmedAt: DateTime.utc(2026, 1, 1, 0, 2),
        ),
      ],
    );
    validateSetupTransition(next, confirmed);
    expect(confirmed.baselineIsCurrent(confirmed.startingLoads.single), isTrue);
  });
  test(
    'missing machine unavailable load and duplicate identities are invalid',
    () {
      for (final make in <TrainingSetup Function()>[
        () => fixtureProfile(baselines: [fixtureBaseline()]),
        () => fixtureProfile(
          equipment: [fixtureEquipment()],
          baselines: [fixtureBaseline(value: 21000000)],
        ),
        () =>
            fixtureProfile(equipment: [fixtureEquipment(), fixtureEquipment()]),
        () => fixtureProfile(
          equipment: [fixtureEquipment()],
          baselines: [
            fixtureBaseline(),
            fixtureBaseline(id: 'second'),
          ],
        ),
        () => fixtureProfile(days: [1, 1]),
        () => fixtureProfile(days: [8]),
        () => fixtureProfile(minutes: 0),
      ]) {
        expect(make, throwsA(isA<SetupException>()));
      }
      expect(
        () => fixtureEquipment(settings: [20000000, 20000000]),
        throwsA(isA<SetupException>()),
      );
    },
  );
  test('units versions unknown fields invalid types duplicate keys and normalized dates rejected', () {
    final source = fixtureProfile().toJson();
    for (final entry in <String, Object?>{
      'unit': 'kg',
      'schema': 2,
      'programVersion': 'future',
      'trainingDays': null,
      'revision': 0.5,
      'updatedAt': '2026-01-32T00:00:00.000Z',
      'unknown': true,
    }.entries) {
      expect(
        () => TrainingSetup.decode(
          jsonEncode({...source, entry.key: entry.value}),
        ),
        throwsA(isA<SetupException>()),
      );
    }
    expect(
      () => TrainingSetup.decode(
        fixtureProfile().encode().replaceFirst(
          '"schema":1',
          '"schema":1,"schema":1',
        ),
      ),
      throwsA(isA<SetupException>()),
    );
  });
  test('capability contradictions and unknown taxonomy remain invalid', () {
    final source = fixtureProfile().toJson();
    expect(
      () => TrainingSetup.decode(
        jsonEncode({
          ...source,
          'supportedCapabilities': ['sustained_grip'],
          'unsupportedCapabilities': ['sustained_grip'],
        }),
      ),
      throwsA(isA<SetupException>()),
    );
    expect(
      () => TrainingSetup.decode(
        jsonEncode({
          ...source,
          'limitations': ['unknown'],
        }),
      ),
      throwsA(isA<SetupException>()),
    );
    final known = TrainingSetup.decode(
      jsonEncode({
        ...source,
        'supportedCapabilities': [],
        'unsupportedCapabilities': [],
        'limitations': [],
      }),
    );
    expect(known.limitations, isEmpty);
  });
  test('cross-profile and silent machine revision changes are rejected', () {
    final old = fixtureProfile(equipment: [fixtureEquipment()]);
    expect(
      () => validateSetupTransition(
        old,
        fixtureProfile(profile: 'other', revision: 1, equipment: old.equipment),
      ),
      throwsA(isA<SetupException>()),
    );
    expect(
      () => validateSetupTransition(
        old,
        fixtureProfile(
          revision: 1,
          equipment: [
            fixtureEquipment(settings: [25000000]),
          ],
        ),
      ),
      throwsA(isA<SetupException>()),
    );
    expect(
      () => validateSetupTransition(
        null,
        fixtureProfile(equipment: [fixtureEquipment(revision: 1)]),
      ),
      throwsA(isA<SetupException>()),
    );
  });
  test('all slots and approved alternatives have preparation keys without changing v1', () {
    final keys = ownerProgram
        .expand((s) => s.blocks)
        .expand((b) => b.exercises)
        .expand(setupVariantsFor)
        .toSet();
    expect(keys, setupVariationNames.keys.toSet());
    expect(keys.length, 25);
    expect(setupVariantsFor(ownerProgram[1].blocks[1].exercises[1]), [
      'seated_leg_curl',
      'lying_leg_curl',
    ]);
    expect(
      ownerProgram[2].blocks.last.exercises.single.id,
      'hanging_knee_raise',
    );
    expect(setupConventionsFor('unassisted_pull_up'), [
      SetupLoadConvention.bodyweight,
    ]);
    expect(setupConventionsFor('assisted_machine_pull_up'), [
      SetupLoadConvention.assistance,
    ]);
  });
}
