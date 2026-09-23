import 'package:adaptive_workout/data/repositories/sqlite_practice_repository.dart';
import 'package:adaptive_workout/domain/logging/practice_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sqflite/sqflite.dart';

final at = DateTime.utc(2026, 9, 23);
PracticeSet record(
  String id,
  int index, {
  String exercise = 'practice_press',
  int load = 30000000,
  bool working = true,
}) => PracticeSet(
  id: id,
  exerciseId: exercise,
  index: index,
  microPounds: load,
  reps: 10,
  rir: 2,
  working: working,
  validity: SetValidity.valid,
);
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  late String path;
  late SqlitePracticeRepository repo;
  setUp(() async {
    path = '${await getDatabasesPath()}/practice_repository_fixture.sqlite';
    await deleteDatabase(path);
    repo = await SqlitePracticeRepository.open(path: path);
    await repo.start(
      profileId: 'fixture_a',
      sessionId: 'session_a',
      actionId: 'start_a',
      at: at,
    );
  });
  tearDown(() async {
    await repo.close();
    await deleteDatabase(path);
  });
  Future<void> save(
    PracticeSet set,
    int revision,
    String action, {
    bool correction = false,
    String profile = 'fixture_a',
  }) => repo.saveSet(
    profileId: profile,
    sessionId: 'session_a',
    actionId: action,
    expectedRevision: revision,
    record: set,
    correction: correction,
    at: at,
  );

  testWidgets(
    'actual SQLite preserves multiple exercises, skips, warmups and corrections across reopen',
    (_) async {
      await save(record('one', 1), 0, 'add_1');
      await save(record('two', 2, working: false), 1, 'add_2');
      await save(record('three', 1, exercise: 'practice_row'), 2, 'add_3');
      await save(
        const PracticeSet(
          id: 'skip',
          exerciseId: 'practice_row',
          index: 2,
          microPounds: null,
          reps: null,
          rir: null,
          working: true,
          validity: SetValidity.unknown,
          skipped: true,
        ),
        3,
        'skip_1',
      );
      await save(
        record('one', 1, load: 25000000),
        4,
        'correct_1',
        correction: true,
      );
      await repo.close();
      repo = await SqlitePracticeRepository.open(path: path);
      final session = (await repo.load('fixture_a')).single;
      expect(session.revision, 5);
      expect(session.sets, hasLength(4));
      expect(session.sets.first.microPounds, 25000000);
      expect(session.sets[1].working, isFalse);
      expect(session.sets.last.skipped, isTrue);
      final db = await openDatabase(path);
      expect(
        Sqflite.firstIntValue(
          await db.rawQuery('SELECT count(*) FROM set_revisions'),
        ),
        1,
      );
    },
  );
  testWidgets(
    'idempotent retries and repeated completion never duplicate data',
    (_) async {
      await save(record('one', 1), 0, 'add_1');
      await save(record('one', 1), 0, 'add_1');
      await expectLater(
        save(record('one', 1, load: 25000000), 0, 'add_1'),
        throwsA(isA<LoggingException>()),
      );
      await repo.complete(
        profileId: 'fixture_a',
        sessionId: 'session_a',
        actionId: 'complete',
        expectedRevision: 1,
        at: at,
      );
      await repo.complete(
        profileId: 'fixture_a',
        sessionId: 'session_a',
        actionId: 'complete',
        expectedRevision: 1,
        at: at,
      );
      await repo.complete(
        profileId: 'fixture_a',
        sessionId: 'session_a',
        actionId: 'complete_again',
        expectedRevision: 1,
        at: at,
      );
      final session = (await repo.load('fixture_a')).single;
      expect(session.sets, hasLength(1));
      expect(session.revision, 2);
      expect(session.completed, isTrue);
      await expectLater(
        save(record('two', 2), 2, 'late_add'),
        throwsA(isA<LoggingException>()),
      );
      await save(
        record('one', 1, load: 25000000),
        2,
        'after_completion_correction',
        correction: true,
      );
      expect(
        (await repo.load('fixture_a')).single.sets.single.microPounds,
        25000000,
      );
    },
  );
  testWidgets('receipt failure rolls back every part of the action', (_) async {
    final db = await openDatabase(path);
    await db.execute(
      "CREATE TRIGGER fail_receipt BEFORE INSERT ON actions WHEN NEW.id = 'fail_action' BEGIN SELECT RAISE(ABORT, 'fixture failure'); END",
    );
    await expectLater(
      save(record('one', 1), 0, 'fail_action'),
      throwsA(isA<DatabaseException>()),
    );
    final before = (await repo.load('fixture_a')).single;
    expect(before.sets, isEmpty);
    expect(before.revision, 0);
    await db.execute('DROP TRIGGER fail_receipt');
    await save(record('one', 1), 0, 'fail_action');
    expect((await repo.load('fixture_a')).single.sets, hasLength(1));
  });
  testWidgets('profiles, set uniqueness and revision checks fail closed', (
    _,
  ) async {
    await repo.start(
      profileId: 'fixture_b',
      sessionId: 'session_b',
      actionId: 'start_b',
      at: at,
    );
    await expectLater(
      save(record('one', 1), 0, 'cross_profile', profile: 'fixture_b'),
      throwsA(isA<LoggingException>()),
    );
    await save(record('one', 1), 0, 'first');
    await expectLater(
      save(record('two', 2), 0, 'stale'),
      throwsA(isA<LoggingException>()),
    );
    await expectLater(
      save(record('duplicate_slot', 1), 1, 'duplicate'),
      throwsA(isA<DatabaseException>()),
    );
    await expectLater(
      save(record('bad', 2, load: -1), 1, 'invalid'),
      throwsA(isA<LoggingException>()),
    );
    expect((await repo.load('fixture_a')).single.sets, hasLength(1));
    expect((await repo.load('fixture_b')).single.sets, isEmpty);
  });
  testWidgets('future schema is refused without deleting records', (_) async {
    await repo.close();
    final db = await openDatabase(
      path,
      version: 2,
      onUpgrade: (_, _, _) async {},
    );
    await db.close();
    await expectLater(
      SqlitePracticeRepository.open(path: path),
      throwsA(anything),
    );
    final verify = await openDatabase(path, version: 2);
    expect(
      Sqflite.firstIntValue(
        await verify.rawQuery('SELECT count(*) FROM sessions'),
      ),
      1,
    );
    await verify.close();
  });
  testWidgets('seed separate database for next-process restart verification', (
    _,
  ) async {
    final restartPath =
        '${await getDatabasesPath()}/practice_restart_fixture.sqlite';
    await deleteDatabase(restartPath);
    final restart = await SqlitePracticeRepository.open(path: restartPath);
    await restart.start(
      profileId: 'restart_fixture',
      sessionId: 'restart_session',
      actionId: 'restart_start',
      at: at,
    );
    for (var i = 1; i <= 3; i++) {
      await restart.saveSet(
        profileId: 'restart_fixture',
        sessionId: 'restart_session',
        actionId: 'action_$i',
        expectedRevision: i - 1,
        record: record('set_$i', i),
        correction: false,
        at: at,
      );
    }
    await restart.close();
  });
}
