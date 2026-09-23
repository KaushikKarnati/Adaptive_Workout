import 'package:adaptive_workout/domain/logging/program_log.dart';
import 'package:adaptive_workout/domain/logging/practice_repository.dart';
import 'package:flutter_test/flutter_test.dart';

ProgramLog fixture({String day = 'monday'}) => ProgramLog(
  id: 'test',
  profile: 'owner',
  programId: day,
  startedAt: DateTime.utc(2026),
  revision: 0,
  completedAt: null,
  sets: [],
);
ProgramSet entry({
  String slot = 'incline_dumbbell_press',
  int index = 1,
  LoggedSide side = LoggedSide.both,
  int? load = 30000000,
  int? reps = 10,
  int? rir = 2,
  bool skipped = false,
  bool warmup = false,
  String? variant,
  String setup = 'machine_a',
  LoadConvention convention = LoadConvention.perDumbbell,
  SetValidity validity = SetValidity.valid,
}) => ProgramSet(
  slot: slot,
  index: index,
  side: side,
  variant: variant ?? slot,
  setup: setup,
  convention: convention,
  load: load,
  reps: reps,
  rir: rir,
  validity: validity,
  warmup: warmup,
  skipped: skipped,
);
ProgramLog filled(ProgramLog log) {
  for (final e in log.exercises) {
    final variant = e.alternatives.isEmpty ? e.id : e.alternatives.first;
    final convention = switch (variant) {
      'incline_dumbbell_press' ||
      'dumbbell_shoulder_press' => LoadConvention.perDumbbell,
      'unassisted_pull_up' ||
      'hanging_knee_raise' ||
      'ab_wheel_rollout' => LoadConvention.bodyweight,
      'assisted_machine_pull_up' => LoadConvention.assistance,
      _ => LoadConvention.machineSetting,
    };
    for (var i = 1; i <= e.sets; i++) {
      for (final side
          in e.eachSide
              ? [LoggedSide.left, LoggedSide.right]
              : [LoggedSide.both]) {
        log = log.record(
          entry(
            slot: e.id,
            index: i,
            side: side,
            load: null,
            reps: null,
            rir: null,
            skipped: true,
            validity: SetValidity.unknown,
            variant: variant,
            convention: convention,
          ),
        );
      }
    }
  }
  return log;
}

void main() {
  test(
    'actuals remain separate, immutable and ineligible for recommendations',
    () {
      final log = fixture().record(entry());
      expect(log.sets.single.load, 30000000);
      expect(log.exercises.first.minReps, 6);
      expect(log.recommendationEligible, isFalse);
      expect(() => log.sets.clear(), throwsUnsupportedError);
      expect(ProgramLog.fromJson(log.toJson()).toJson(), log.toJson());
    },
  );
  test('same set key corrects rather than duplicates', () {
    final log = fixture().record(entry()).record(entry(reps: 9));
    expect(log.sets.length, 1);
    expect(log.sets.single.reps, 9);
    expect(log.revision, 2);
  });
  test('warmups never fill prescribed work and cannot finish an incomplete workout', () {
    final log = fixture().record(entry(warmup: true));
    expect(log.allWorkingSetsRecorded, isFalse);
    expect(
      () => log.finish(DateTime.utc(2026, 2)),
      throwsA(isA<LoggingException>()),
    );
  });
  test('explicit skips finish without claiming all work performed; completion idempotent', () {
    final log = filled(fixture()).finish(DateTime.utc(2026, 2));
    expect(log.hasSkips, isTrue);
    expect(log.completed, isTrue);
    expect(log.finish(DateTime.utc(2026, 3)), same(log));
    expect(log.record(entry()).sets.where((s) => !s.skipped).length, 1);
    expect(
      () => log.record(entry(warmup: true)),
      throwsA(isA<LoggingException>()),
    );
  });
  test('both unilateral sides required; unsupported side rejected', () {
    final log = fixture(day: 'friday');
    expect(
      () => log.record(
        entry(
          slot: 'single_arm_cable_pulldown',
          convention: LoadConvention.machineSetting,
        ),
      ),
      throwsA(isA<LoggingException>()),
    );
    final left = log.record(
      entry(
        slot: 'single_arm_cable_pulldown',
        side: LoggedSide.left,
        convention: LoadConvention.machineSetting,
      ),
    );
    final both = left.record(
      entry(
        slot: 'single_arm_cable_pulldown',
        side: LoggedSide.right,
        convention: LoadConvention.machineSetting,
      ),
    );
    expect(both.sets.length, 2);
    expect(filled(log).sets.length, 21);
  });
  test('pain stops new sets but permits skipping and correction', () {
    final log = fixture().record(entry(validity: SetValidity.pain));
    expect(() => log.record(entry(index: 2)), throwsA(isA<LoggingException>()));
    expect(
      log
          .record(
            entry(
              index: 2,
              skipped: true,
              load: null,
              reps: null,
              rir: null,
              validity: SetValidity.unknown,
            ),
          )
          .sets
          .length,
      2,
    );
    expect(
      log.record(entry(reps: 8, validity: SetValidity.pain)).sets.single.reps,
      8,
    );
  });
  test('missing invalid and boundary actuals', () {
    for (final s in [
      entry(load: -1),
      entry(load: 1000000000001),
      entry(reps: -1),
      entry(reps: 10001),
      entry(rir: -1),
      entry(rir: 10001),
      entry(index: 0),
      entry(index: 4),
      entry(setup: ''),
      entry(setup: 'x' * 121),
      entry(variant: 'unknown'),
      entry(slot: 'unknown'),
      entry(convention: LoadConvention.assistance),
      entry(convention: LoadConvention.bodyweight, load: null),
      entry(skipped: true),
    ]) {
      expect(() => fixture().record(s), throwsA(isA<LoggingException>()));
    }
    expect(
      fixture().record(entry(load: 0, reps: 0, rir: null)).sets.single.rir,
      isNull,
    );
    expect(
      fixture()
          .record(entry(load: 1000000000000, reps: 10000, rir: 10000))
          .sets
          .length,
      1,
    );
  });
  test('skips still require an approved variation setup and convention', () {
    ProgramSet skipped({
      String variant = 'incline_dumbbell_press',
      String setup = 'dumbbell_area',
      LoadConvention convention = LoadConvention.perDumbbell,
    }) => entry(
      load: null,
      reps: null,
      rir: null,
      skipped: true,
      validity: SetValidity.unknown,
      variant: variant,
      setup: setup,
      convention: convention,
    );

    expect(fixture().record(skipped()).sets.single.skipped, isTrue);
    for (final invalid in [
      skipped(variant: 'unknown'),
      skipped(setup: ' '),
      skipped(convention: LoadConvention.machineSetting),
    ]) {
      expect(() => fixture().record(invalid), throwsA(isA<LoggingException>()));
    }
  });
  test('completion rejects non-UTC and pre-start timestamps immediately', () {
    final log = filled(fixture());
    for (final timestamp in [
      DateTime(2026, 2),
      DateTime.utc(2025, 12, 31, 23, 59, 59),
    ]) {
      expect(
        () => log.finish(timestamp),
        throwsA(
          isA<LoggingException>().having(
            (error) => error.code,
            'code',
            'invalid_completion_time',
          ),
        ),
      );
    }
  });
  test('bodyweight and assistance are distinct conventions', () {
    final log = fixture(day: 'friday');
    expect(
      log
          .record(
            entry(
              slot: 'pull_up',
              variant: 'unassisted_pull_up',
              load: null,
              convention: LoadConvention.bodyweight,
            ),
          )
          .sets
          .length,
      1,
    );
    expect(
      log
          .record(
            entry(
              slot: 'pull_up',
              variant: 'assisted_machine_pull_up',
              convention: LoadConvention.assistance,
            ),
          )
          .sets
          .length,
      1,
    );
    expect(
      () => log.record(
        entry(
          slot: 'pull_up',
          variant: 'assisted_machine_pull_up',
          convention: LoadConvention.machineSetting,
        ),
      ),
      throwsA(isA<LoggingException>()),
    );
  });
  test('unknown versions, sessions, duplicate keys and invalid timestamps fail closed', () {
    final j = fixture().record(entry()).toJson();
    for (final bad in [
      {...j, 'version': 'future'},
      {...j, 'programId': 'unknown'},
      {...j, 'revision': -1},
      {
        ...j,
        'sets': [entry().toJson(), entry().toJson()],
      },
      {...j, 'completedAt': '2025-01-01T00:00:00.000Z'},
    ]) {
      expect(() => ProgramLog.fromJson(bad), throwsA(isA<LoggingException>()));
    }
  });
}
