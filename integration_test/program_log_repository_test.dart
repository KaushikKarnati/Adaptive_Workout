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
  testWidgets('early finish preserves records and permits another chosen day', (
    _,
  ) async {
    final original = seed('early');
    await repo.write(original, expectedRevision: -1, actionId: 'start');
    final recorded = original.record(set());
    await repo.write(recorded, expectedRevision: 0, actionId: 'set');
    final ended = recorded.finish(DateTime.utc(2026, 1, 2), endEarly: true);
    await repo.write(ended, expectedRevision: 1, actionId: 'early');
    await repo.write(ended, expectedRevision: 1, actionId: 'early');
    final friday = ProgramLog(
      id: 'friday_session',
      profile: 'early',
      programId: 'friday',
      startedAt: DateTime.utc(2026, 1, 2),
      revision: 0,
      completedAt: null,
      sets: [],
    );
    await repo.write(friday, expectedRevision: -1, actionId: 'friday');
    await repo.close();
    repo = await SqliteProgramLogRepository.open(path: path);
    final logs = await repo.load('early');
    expect(logs, hasLength(2));
    expect(logs.singleWhere((l) => !l.completed).programId, 'friday');
    final old = logs.singleWhere((l) => l.completed);
    expect(old.endedEarly, isTrue);
    expect(old.sets.single.reps, 10);
    final corrected = old.record(set(reps: 9));
    await repo.write(corrected, expectedRevision: 2, actionId: 'correct');
    expect(
      (await repo.load('early')).singleWhere((l) => l.completed).endedEarly,
      isTrue,
    );
  });
  testWidgets(
    'program revisions coexist without rewriting two-set shoulder history',
    (_) async {
      final old = ProgramLog.fromJson({
        ...seed('legacy').toJson(),
        'programId': 'wednesday',
        'version': 'owner-program-v1',
      });
      final current = ProgramLog.fromJson({
        ...seed('current').toJson(),
        'programId': 'wednesday',
      });
      await repo.write(old, expectedRevision: -1, actionId: 'old');
      await repo.write(current, expectedRevision: -1, actionId: 'new');
      await repo.close();
      repo = await SqliteProgramLogRepository.open(path: path);
      final loadedOld = (await repo.load('legacy')).single;
      final loadedNew = (await repo.load('current')).single;
      expect(loadedOld.toJson(), old.toJson());
      expect(loadedOld.plan.blocks.first.exercises.single.sets, 2);
      expect(loadedNew.plan.blocks.first.exercises.single.sets, 3);
      final changedVersion = ProgramLog.fromJson({
        ...old.toJson(),
        'version': 'owner-program-v2',
        'revision': 1,
      });
      await expectLater(
        repo.write(
          changedVersion,
          expectedRevision: 0,
          actionId: 'invalid_change',
        ),
        throwsA(isA<LoggingException>()),
      );
      expect((await repo.load('legacy')).single.toJson(), old.toJson());
    },
  );
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
      await db.execute('PRAGMA user_version=3');
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
  testWidgets(
    'v1 upgrade and deletion remove records, audits and receipts without resurrection',
    (_) async {
      final original = seed('delete_me');
      await repo.write(original, expectedRevision: -1, actionId: 'start');
      final recorded = original.record(set());
      await repo.write(recorded, expectedRevision: 0, actionId: 'set');
      await repo.write(seed('other'), expectedRevision: -1, actionId: 'start');
      await repo.close();
      final legacy = await openDatabase(path);
      await legacy.execute('DROP TABLE deletions');
      await legacy.execute('PRAGMA user_version=1');
      final before = await legacy.query('logs');
      await legacy.close();
      repo = await SqliteProgramLogRepository.open(path: path);
      final db = await openDatabase(path);
      expect(await db.query('logs'), before);
      expect(await db.getVersion(), 2);
      await expectLater(
        repo.delete(
          'delete_me',
          original.id,
          expectedRevision: 0,
          actionId: 'delete',
        ),
        throwsA(isA<LoggingException>()),
      );
      await expectLater(
        repo.delete(
          'missing',
          original.id,
          expectedRevision: 1,
          actionId: 'delete',
        ),
        throwsA(isA<LoggingException>()),
      );
      await expectLater(
        repo.delete(
          'delete_me',
          original.id,
          expectedRevision: 1,
          actionId: 'set',
        ),
        throwsA(isA<LoggingException>()),
      );
      // Failure late in deletion must restore receipts and revisions too.
      await db.execute(
        "CREATE TRIGGER reject_delete BEFORE DELETE ON logs BEGIN SELECT RAISE(ABORT, 'fixture'); END",
      );
      await expectLater(
        repo.delete(
          'delete_me',
          original.id,
          expectedRevision: 1,
          actionId: 'delete',
        ),
        throwsA(isA<DatabaseException>()),
      );
      expect((await repo.load('delete_me')).single.sets.single.reps, 10);
      expect(
        await db.query(
          'receipts',
          where: 'profile=?',
          whereArgs: ['delete_me'],
        ),
        hasLength(2),
      );
      expect(
        await db.query(
          'revisions',
          where: 'profile=?',
          whereArgs: ['delete_me'],
        ),
        hasLength(1),
      );
      await db.execute('DROP TRIGGER reject_delete');
      await repo.delete(
        'delete_me',
        original.id,
        expectedRevision: 1,
        actionId: 'delete',
      );
      for (final table in ['logs', 'revisions', 'receipts']) {
        expect(
          await db.query(table, where: 'profile=?', whereArgs: ['delete_me']),
          isEmpty,
        );
      }
      await repo.close();
      repo = await SqliteProgramLogRepository.open(path: path);
      await repo.delete(
        'delete_me',
        original.id,
        expectedRevision: 1,
        actionId: 'delete',
      );
      await expectLater(
        repo.delete(
          'delete_me',
          original.id,
          expectedRevision: 1,
          actionId: 'different',
        ),
        throwsA(isA<LoggingException>()),
      );
      await expectLater(
        repo.write(original, expectedRevision: -1, actionId: 'start'),
        throwsA(isA<LoggingException>()),
      );
      await expectLater(
        repo.write(original, expectedRevision: -1, actionId: 'new_start'),
        throwsA(isA<LoggingException>()),
      );
      expect(await repo.load('delete_me'), isEmpty);
      expect(await repo.load('other'), hasLength(1));
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
