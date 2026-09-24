import 'dart:convert';

import 'package:adaptive_workout/data/repositories/sqlite_recommendation_history_repository.dart';
import 'package:adaptive_workout/domain/logging/practice_repository.dart';
import 'package:adaptive_workout/domain/progression/load_progression_policy.dart';
import 'package:adaptive_workout/domain/recommendations/recommendation_history.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sqflite/sqflite.dart';

import '../test/support/recommendation_fixture.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const path = 'recommendation_history_fixture.sqlite';
  late SqliteRecommendationHistoryRepository repo;
  setUp(() async {
    await deleteDatabase(path);
    repo = await SqliteRecommendationHistoryRepository.open(path: path);
  });
  tearDown(() async {
    await repo.close();
    await deleteDatabase(path);
  });
  Future<void> write(GeneratedOccurrence s, String action) async {
    final history = await repo.load(s.profile);
    await repo.saveOccurrence(
      s,
      expectedRevision: s.revision - 1,
      expectedHistoryRevision: history.revision,
      actionId: action,
    );
  }

  Future<GeneratedOccurrence> complete(
    RecommendationSnapshot r,
    int sequence,
  ) async {
    await repo.saveRecommendation(r, actionId: 'plan_${r.id}');
    var s = generatedStart(r, id: 'session$sequence', sequence: sequence);
    await write(s, 'start${r.id}');
    for (var i = 1; i <= 2; i++) {
      s = s.record(
        generatedActual(index: i),
        s.updatedAt.add(const Duration(seconds: 1)),
        r,
      );
      await write(s, 'set${r.id}_$i');
    }
    s = s.finish(
      s.updatedAt.add(const Duration(seconds: 1)),
      OccurrenceStatus.completed,
      r,
    );
    await write(s, 'finish${r.id}');
    return s;
  }

  testWidgets(
    'reopen immutable historical recommendations, isolated profiles, receipts, conflicts',
    (_) async {
      final r = generatedPlan(program: 'historical_v0');
      await repo.saveRecommendation(r, actionId: 'plan');
      await repo.saveRecommendation(r, actionId: 'plan');
      await repo.saveRecommendation(
        generatedPlan(profile: 'second'),
        actionId: 'plan',
      );
      final s = generatedStart(r);
      await write(s, 'start');
      await repo.saveOccurrence(
        s,
        expectedRevision: -1,
        expectedHistoryRevision: 0,
        actionId: 'start',
      );
      await expectLater(
        repo.saveOccurrence(
          s,
          expectedRevision: -1,
          expectedHistoryRevision: 1,
          actionId: 'start',
        ),
        throwsA(isA<LoggingException>()),
      );
      await expectLater(
        repo.saveRecommendation(
          generatedPlan(program: 'changed'),
          actionId: 'plan',
        ),
        throwsA(isA<LoggingException>()),
      );
      await expectLater(
        repo.saveRecommendation(r, actionId: 'different'),
        throwsA(isA<LoggingException>()),
      );
      await repo.close();
      repo = await SqliteRecommendationHistoryRepository.open(path: path);
      final h = await repo.load('fixture');
      expect(h.recommendations.single.encode(), r.encode());
      expect(h.occurrences.single.encode(), s.encode());
      expect((await repo.load('second')).occurrences, isEmpty);
      expect((await repo.load('missing')).revision, 0);
      final db = await openDatabase(path);
      expect((await db.query('receipts')).length, 3);
    },
  );
  testWidgets(
    'two exposures increase; correction changes next calculation and invalidates future only',
    (_) async {
      final r0 = generatedPlan();
      final s0 = await complete(r0, 0);
      final r1 = generatedPlan(
        id: 'rec1',
        history: 4,
        at: generatedTime.add(const Duration(days: 1)),
        evidence: {s0.id: s0.revision},
      );
      final s1 = await complete(r1, 1);
      LoadProgressionResult evaluate(GeneratedHistory h) {
        final slot = generatedSlot();
        final context = progressionContext(
          'fixture',
          'fixture_program',
          'session_a',
          slot,
        );
        return const LoadProgressionPolicy().evaluate(
          LoadProgressionInput(
            context: context,
            gate: ProgressionGate.permitted,
            baseline: VerifiedLoadBaseline(
              context: context,
              microPounds: 100000000,
            ),
            availableLoadsMicroPounds: [95000000, 100000000, 105000000],
            history: h.progression(
              programId: 'fixture_program',
              programVersion: 'fixture_program_v1',
              sessionTemplate: 'session_a',
              current: slot,
            ),
          ),
        );
      }

      expect(
        evaluate(await repo.load('fixture')).action,
        ProgressionAction.increase,
      );
      final future = generatedPlan(
        id: 'rec2',
        history: 8,
        at: generatedTime.add(const Duration(days: 2)),
        evidence: {s0.id: s0.revision, s1.id: s1.revision},
      );
      await repo.saveRecommendation(future, actionId: 'future');
      final corrected = s1.record(
        generatedActual(rir: null),
        generatedTime.add(const Duration(days: 3)),
        r1,
      );
      await write(corrected, 'correct');
      await repo.close();
      repo = await SqliteRecommendationHistoryRepository.open(path: path);
      final h = await repo.load('fixture');
      expect(evaluate(h).action, ProgressionAction.hold);
      expect(h.isStale(future), isTrue);
      expect(
        h.recommendations.firstWhere((r) => r.id == r1.id).encode(),
        r1.encode(),
      );
      final audit = await repo.audit('fixture', s1.id);
      expect(audit.length, 5);
      expect(audit[3].encode(), s1.encode());
      expect(audit.last.sets.length, 2);
      await expectLater(
        write(
          generatedStart(future, id: 'session2', sequence: 2),
          'stale_start',
        ),
        throwsA(isA<LoggingException>()),
      );
      await expectLater(
        repo.saveRecommendation(
          generatedPlan(
            id: 'bad_evidence',
            history: 9,
            at: generatedTime.add(const Duration(days: 4)),
            evidence: {s1.id: 3},
          ),
          actionId: 'bad_evidence',
        ),
        throwsA(isA<LoggingException>()),
      );
      expect((await repo.load('fixture')).revision, 9);
    },
  );
  testWidgets(
    'active draft blocks another start; early end and intervening incomplete survive reopen',
    (_) async {
      final r = generatedPlan();
      final other = generatedPlan(id: 'other');
      await repo.saveRecommendation(r, actionId: 'plan');
      await repo.saveRecommendation(other, actionId: 'other');
      var s = generatedStart(r);
      await write(s, 'start');
      await expectLater(
        write(generatedStart(other, id: 'second', sequence: 1), 'second'),
        throwsA(isA<LoggingException>()),
      );
      await repo.close();
      repo = await SqliteRecommendationHistoryRepository.open(path: path);
      expect(
        (await repo.load('fixture')).occurrences.single.status,
        OccurrenceStatus.active,
      );
      s = s.finish(generatedTime, OccurrenceStatus.endedEarly, r);
      await write(s, 'end');
      final h = await repo.load('fixture');
      final exposure = h
          .progression(
            programId: 'fixture_program',
            programVersion: r.programVersion,
            sessionTemplate: r.sessionTemplate,
            current: r.slots.single,
          )
          .single;
      expect(exposure.completed, isFalse);
      expect(exposure.sets, isEmpty);
      await expectLater(
        repo.saveOccurrence(
          s,
          expectedRevision: 0,
          expectedHistoryRevision: 1,
          actionId: 'repeat_different',
        ),
        throwsA(isA<LoggingException>()),
      );
    },
  );
  testWidgets(
    'receipt failure rolls back session, audit, sequence and history revision together',
    (_) async {
      final r = generatedPlan();
      await repo.saveRecommendation(r, actionId: 'plan');
      final s = generatedStart(r);
      await write(s, 'start');
      final next = s.record(generatedActual(), generatedTime, r);
      final db = await openDatabase(path);
      await db.execute(
        "CREATE TRIGGER fail_receipt BEFORE INSERT ON receipts BEGIN SELECT RAISE(ABORT,'fixture failure'); END",
      );
      await expectLater(
        write(next, 'record'),
        throwsA(isA<DatabaseException>()),
      );
      final h = await repo.load('fixture');
      expect(h.revision, 1);
      expect(h.occurrences.single.sets, isEmpty);
      expect(await db.query('revisions'), isEmpty);
      await db.execute('DROP TRIGGER fail_receipt');
      await write(next, 'record');
      await repo.saveOccurrence(
        next,
        expectedRevision: 0,
        expectedHistoryRevision: 1,
        actionId: 'record',
      );
      expect((await repo.load('fixture')).revision, 2);
      expect((await repo.audit('fixture', s.id)).length, 2);
    },
  );
  testWidgets(
    'cross profile reference and replacement/deletion of actuals reject atomically',
    (_) async {
      final r = generatedPlan();
      await repo.saveRecommendation(r, actionId: 'plan');
      final alien = generatedStart(generatedPlan(profile: 'other'));
      await expectLater(
        write(alien, 'alien'),
        throwsA(isA<LoggingException>()),
      );
      var s = generatedStart(r);
      await write(s, 'start');
      s = s.record(generatedActual(), generatedTime, r);
      await write(s, 'set');
      final invalid = GeneratedOccurrence.decode(
        jsonEncode({...s.toJson(), 'revision': 2, 'sets': []}),
      );
      await expectLater(
        write(invalid, 'delete_set'),
        throwsA(isA<LoggingException>()),
      );
      expect((await repo.load('fixture')).occurrences.single.sets.length, 1);
    },
  );
  testWidgets(
    'corrupt relational revisions, snapshots and unsupported schema preserve bytes',
    (_) async {
      final r = generatedPlan();
      await repo.saveRecommendation(r, actionId: 'plan');
      final s = generatedStart(r);
      await write(s, 'start');
      final db = await openDatabase(path);
      await db.update('occurrences', {'revision': 42});
      await expectLater(repo.load('fixture'), throwsA(isA<LoggingException>()));
      await db.update('occurrences', {'revision': 0});
      await db.update('recommendations', {
        'payload': jsonEncode({...r.toJson(), 'schema': 2}),
      });
      await expectLater(repo.load('fixture'), throwsA(isA<LoggingException>()));
      await db.update('recommendations', {'payload': r.encode()});
      await db.execute('PRAGMA user_version=2');
      await repo.close();
      await expectLater(
        SqliteRecommendationHistoryRepository.open(path: path),
        throwsA(isA<LoggingException>()),
      );
      final inspect = await openDatabase(path);
      expect(
        (await inspect.query('recommendations')).single['payload'],
        r.encode(),
      );
      await inspect.close();
    },
  );
  testWidgets(
    'missing or tampered audit prevents history from becoming progression evidence',
    (_) async {
      final r = generatedPlan();
      await complete(r, 0);
      final db = await openDatabase(path);
      final rows = await db.query(
        'revisions',
        where: 'revision=?',
        whereArgs: [1],
      );
      final original = rows.single['payload'] as String;
      final j = jsonDecode(original) as Map<String, dynamic>;
      final sets = (j['sets'] as List).cast<Map<String, dynamic>>();
      sets.single['reps'] = 4;
      await db.update(
        'revisions',
        {
          'payload': jsonEncode({...j, 'sets': sets}),
        },
        where: 'revision=?',
        whereArgs: [1],
      );
      await expectLater(repo.load('fixture'), throwsA(isA<LoggingException>()));
      await db.update(
        'revisions',
        {'payload': original},
        where: 'revision=?',
        whereArgs: [1],
      );
      await db.delete('revisions', where: 'revision=?', whereArgs: [1]);
      await expectLater(repo.load('fixture'), throwsA(isA<LoggingException>()));
      expect((await db.query('occurrences')).length, 1);
    },
  );
}
