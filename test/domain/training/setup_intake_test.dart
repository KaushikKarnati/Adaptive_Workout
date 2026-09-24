import 'dart:convert';

import 'package:adaptive_workout/domain/training/training_setup.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/setup_intake_fixture.dart';
import '../../support/training_setup_fixture.dart';

void main() {
  test('schema one stays unchanged; schema two round-trips immutable draft evidence', () {
    final old = fixtureProfile();
    expect(TrainingSetup.decode(old.encode()).encode(), old.encode());
    final current = withIntake(
      old,
      reports: [syntheticReport()],
      rehearsals: [syntheticRehearsal()],
    );
    final restored = TrainingSetup.decode(current.encode());
    expect(restored.encode(), current.encode());
    expect(restored.startingLoads, isEmpty);
    expect(restored.equipment, isEmpty);
    expect(restored.reportedWork.single.recommendationEligible, isFalse);
    expect(
      restored.rehearsalConfirmations.single.hasCompleteAttestation,
      isFalse,
    );
    expect(() => restored.reportedWork.clear(), throwsUnsupportedError);
    expect(
      () => restored.rehearsalConfirmations.clear(),
      throwsUnsupportedError,
    );
  });
  test('intake reports reject invalid numbers, units, slots, scope and duplicate IDs', () {
    final j = syntheticReport().toJson();
    for (final delta in [
      {'load': -1},
      {'loadIncrement': 0},
      {'sets': 0},
      {'minReps': 0},
      {'maxReps': 1},
      {'minRir': 1},
      {'eachSide': null},
      {'loadScope': 'totalAddedPlates'},
      {'sessionId': 'unknown'},
      {'variation': 'unknown'},
      {'convention': 'bodyweight'},
      {'id': '<unsafe>'},
      {'recordedAt': 'not-a-date'},
    ]) {
      expect(
        () => TrainingSetup.decode(
          jsonEncode({
            ...withIntake(fixtureProfile()).toJson(),
            'reportedWork': [
              {...j, ...delta},
            ],
          }),
        ),
        throwsA(isA<SetupException>()),
      );
    }
    expect(
      () => withIntake(
        fixtureProfile(),
        reports: [syntheticReport(), syntheticReport()],
      ),
      throwsA(isA<SetupException>()),
    );
    expect(
      () => withIntake(
        fixtureProfile(),
        reports: [syntheticReport(at: DateTime.utc(2027))],
      ),
      throwsA(isA<SetupException>()),
    );
  });
  test('rehearsal drafts retain unknown feedback and require exact paired references', () {
    expect(
      syntheticRehearsal(easy: null, symptoms: null).hasCompleteAttestation,
      isFalse,
    );
    for (final delta in [
      {'setupId': 'station'},
      {'setupRevision': 0},
      {'assistance': -1},
      {'workingRangeRef': 'range'},
      {'withinWorkingRange': true},
      {'variation': 'leg_press'},
    ]) {
      expect(
        () => RehearsalConfirmation.fromJson({
          ...syntheticRehearsal().toJson(),
          ...delta,
        }),
        throwsA(isA<SetupException>()),
      );
    }
    expect(
      () => withIntake(
        fixtureProfile(),
        rehearsals: [syntheticRehearsal(setupId: 'missing', setupRevision: 0)],
      ),
      throwsA(isA<SetupException>()),
    );
  });
  test('append preserves history and cannot delete or silently clear a symptom report', () {
    final old = withIntake(
      fixtureProfile(),
      reports: [syntheticReport()],
      rehearsals: [syntheticRehearsal(symptoms: true)],
    );
    final next = withIntake(
      old,
      revision: 1,
      reports: old.reportedWork,
      rehearsals: [
        ...old.rehearsalConfirmations,
        syntheticRehearsal(id: 'later'),
      ],
    );
    validateSetupTransition(old, next);
    expect(
      () => validateSetupTransition(old, withIntake(old, revision: 1)),
      throwsA(isA<SetupException>()),
    );
    expect(
      () => validateSetupTransition(
        old,
        withIntake(
          old,
          revision: 1,
          reports: old.reportedWork,
          rehearsals: [syntheticRehearsal(symptoms: false)],
        ),
      ),
      throwsA(isA<SetupException>()),
    );
    expect(
      () => validateSetupTransition(old, fixtureProfile(revision: 1)),
      throwsA(isA<SetupException>()),
    );
  });
  test('range confirmation never invents an endpoint relationship', () {
    final j = {
      ...syntheticRehearsal().toJson(),
      'sessionId': 'saturday',
      'slotId': 'ab_wheel_rollout',
      'variation': 'kneeling_ab_wheel',
      'assistance': null,
      'setupId': 'wheel',
      'setupRevision': 0,
      'workingRangeRef': 'far_mark',
      'rehearsalRangeRef': 'near_mark',
    };
    expect(RehearsalConfirmation.fromJson(j).hasCompleteAttestation, isFalse);
    expect(
      RehearsalConfirmation.fromJson({...j, 'withinWorkingRange': true})
          .hasCompleteAttestation,
      isTrue,
    );
    expect(
      () => RehearsalConfirmation.fromJson({
        ...j,
        'withinWorkingRange': true,
        'workingRangeRef': null,
      }),
      throwsA(isA<SetupException>()),
    );
  });
}
