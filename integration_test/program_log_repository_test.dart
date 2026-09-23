import 'dart:convert';

import 'package:adaptive_workout/data/repositories/sqlite_program_log_repository.dart';
import 'package:adaptive_workout/domain/logging/program_log.dart';
import 'package:adaptive_workout/domain/logging/practice_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sqflite/sqflite.dart';

ProgramLog seed(String profile) => ProgramLog(
  id: 'session',
  profile: profile,
  programId: 'monday',
  startedAt: DateTime.utc(2026),
  revision: 0,
  completedAt: null,
  sets: [],
);
ProgramSet set({int reps = 10}) => ProgramSet(
  slot: 'incline_dumbbell_press',
  index: 1,
  side: LoggedSide.both,
  variant: 'incline_dumbbell_press',
  setup: 'fixture_dumbbell',
  convention: LoadConvention.perDumbbell,
  load: 30000000,
  reps: reps,
  rir: 2,
  validity: SetValidity.valid,
  warmup: false,
  skipped: false,
);
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const path = 'program_logging_fixture.sqlite';
  late SqliteProgramLogRepository repo;
  setUp(() async {
    await deleteDatabase(path);
    repo = await SqliteProgramLogRepository.open(path: path);
  });
  tearDown(() async {
    await repo.close();
    await deleteDatabase(path);
  });
  testWidgets('native receipts corrections isolation and reopen', (_) async {
    var log = seed('a');
    await repo.write(log, expectedRevision: -1, actionId: 'start');
    await repo.write(seed('b'), expectedRevision: -1, actionId: 'start');
    log = log.record(set());
    await repo.write(log, expectedRevision: 0, actionId: 'set');
    await repo.write(log, expectedRevision: 0, actionId: 'set');
    await expectLater(
      repo.write(log, expectedRevision: 0, actionId: 'stale'),
      throwsA(isA<LoggingException>()),
    );
    final corrected = log.record(set(reps: 9));
    await repo.write(corrected, expectedRevision: 1, actionId: 'correct');
    final identical = corrected.record(set(reps: 9));
    await repo.write(identical, expectedRevision: 2, actionId: 'identical');
    await repo.close();
    repo = await SqliteProgramLogRepository.open(path: path);
    expect((await repo.load('a')).single.sets.single.reps, 9);
    expect((await repo.load('b')).single.sets, isEmpty);
    final db = await openDatabase(path);
    expect((await db.rawQuery('PRAGMA foreign_keys')).single.values.single, 1);
    expect((await db.query('revisions')).length, 3);
    final old = jsonDecode(
      (await db.query(
            'revisions',
            where: 'revision=?',
            whereArgs: [1],
          )).single['payload']
          as String,
    );
    expect(old['sets'][0]['reps'], 10);
  });
  testWidgets('receipt failure rolls back and retry succeeds', (_) async {
    final initial = seed('a');
    await repo.write(initial, expectedRevision: -1, actionId: 'start');
    final db = await openDatabase(path);
    await db.execute(
      "CREATE TRIGGER fail_receipt BEFORE INSERT ON receipts BEGIN SELECT RAISE(ABORT, 'fixture failure'); END",
    );
    final next = initial.record(set());
    await expectLater(
      repo.write(next, expectedRevision: 0, actionId: 'set'),
      throwsA(isA<DatabaseException>()),
    );
    expect((await repo.load('a')).single.revision, 0);
    expect(await db.query('revisions'), isEmpty);
    await db.execute('DROP TRIGGER fail_receipt');
    await repo.write(next, expectedRevision: 0, actionId: 'set');
    expect((await repo.load('a')).single.sets.length, 1);
  });
  testWidgets(
    'one draft future schema and prescription corruption fail safely',
    (_) async {
      await repo.write(seed('a'), expectedRevision: -1, actionId: 'start');
      final second = ProgramLog(
        id: 'second',
        profile: 'a',
        programId: 'tuesday',
        startedAt: DateTime.utc(2026),
        revision: 0,
        completedAt: null,
        sets: [],
      );
      await expectLater(
        repo.write(second, expectedRevision: -1, actionId: 'second'),
        throwsA(isA<DatabaseException>()),
      );
      final db = await openDatabase(path);
      await db.update('logs', {'prescription': '{}'});
      await expectLater(repo.load('a'), throwsA(isA<LoggingException>()));
      await db.execute('PRAGMA user_version=2');
      await repo.close();
      await expectLater(
        SqliteProgramLogRepository.open(path: path),
        throwsA(isA<LoggingException>()),
      );
      final inspect = await openDatabase(path);
      expect((await inspect.query('logs')).length, 1);
      await inspect.close();
    },
  );
  testWidgets('completed sessions retain corrections without duplicate work', (
    _,
  ) async {
    var log = seed('a');
    await repo.write(log, expectedRevision: -1, actionId: 'start');
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
          final previous = log.revision;
          log = log.record(
            ProgramSet(
              slot: e.id,
              index: i,
              side: side,
              variant: variant,
              setup: 'fixture_setup',
              convention: convention,
              load: null,
              reps: null,
              rir: null,
              validity: SetValidity.unknown,
              warmup: false,
              skipped: true,
            ),
          );
          await repo.write(
            log,
            expectedRevision: previous,
            actionId: 'skip_$previous',
          );
        }
      }
    }
    final prior = log.revision;
    log = log.finish(DateTime.utc(2026, 2));
    await repo.write(log, expectedRevision: prior, actionId: 'finish');
    await repo.write(log, expectedRevision: prior, actionId: 'finish');
    final corrected = log.record(set());
    await repo.write(
      corrected,
      expectedRevision: log.revision,
      actionId: 'correction',
    );
    final result = (await repo.load('a')).single;
    expect(result.completed, isTrue);
    expect(result.sets.length, 18);
    expect(result.sets.where((s) => !s.skipped).length, 1);
  });
}
