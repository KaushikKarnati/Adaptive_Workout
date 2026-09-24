import 'package:adaptive_workout/application/saved_workout_service.dart';
import 'package:adaptive_workout/domain/logging/practice_repository.dart';
import 'package:adaptive_workout/domain/recommendations/recommendation_history.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/recommendation_fixture.dart';

class MemoryHistory implements RecommendationHistoryRepository {
  MemoryHistory(this.history);
  GeneratedHistory history;
  final receipts = <String, String>{};
  bool failRead = false, failWrite = false, loseAcknowledgement = false;
  @override
  Future<GeneratedHistory> load(String profile) async {
    if (failRead) throw const LoggingException('read_failed');
    return profile == history.profile
        ? history
        : GeneratedHistory(
            profile: profile,
            revision: 0,
            recommendations: [],
            occurrences: [],
          );
  }

  @override
  Future<void> saveOccurrence(
    GeneratedOccurrence occurrence, {
    required int expectedRevision,
    required int expectedHistoryRevision,
    required String actionId,
  }) async {
    final payload =
        '$expectedRevision/$expectedHistoryRevision/${occurrence.encode()}';
    if (receipts.containsKey(actionId)) {
      checkHistory(receipts[actionId] == payload, 'action_conflict');
      return;
    }
    if (failWrite) throw const LoggingException('write_failed');
    checkHistory(history.revision == expectedHistoryRevision, 'stale_history');
    final old = history.occurrences.singleWhere((s) => s.id == occurrence.id);
    checkHistory(old.revision == expectedRevision, 'stale_revision');
    validateOccurrenceTransition(
      old,
      occurrence,
      history.recommendations.singleWhere(
        (p) => p.id == occurrence.recommendationId,
      ),
    );
    history = generatedHistory(history.recommendations, [
      for (final s in history.occurrences)
        s.id == occurrence.id ? occurrence : s,
    ]);
    receipts[actionId] = payload;
    if (loseAcknowledgement) throw const LoggingException('ack_lost');
  }

  @override
  Future<void> saveRecommendation(
    RecommendationSnapshot r, {
    required String actionId,
  }) => throw UnimplementedError();
  @override
  Future<List<GeneratedOccurrence>> audit(
    String profile,
    String occurrenceId,
  ) => throw UnimplementedError();
  @override
  Future<void> close() async {}
}

void main() {
  late MemoryHistory repo;
  late SavedWorkoutService service;
  setUp(() {
    final plan = generatedPlan();
    repo = MemoryHistory(generatedHistory([plan], [generatedStart(plan)]));
    service = SavedWorkoutService(repo);
  });
  Future<SavedWorkoutAction> setAction({
    int index = 1,
    String action = 'set',
  }) => service.prepareSet(
    profile: 'fixture',
    occurrenceId: 'session0',
    set: generatedActual(index: index),
    at: generatedTime,
    actionId: action,
  );
  Future<SavedWorkoutAction> finish(bool early) => service.prepareFinish(
    profile: 'fixture',
    occurrenceId: 'session0',
    endEarly: early,
    at: generatedTime,
    actionId: 'finish',
  );
  Future<dynamic> next({
    String program = 'fixture_program',
    DateTime? date,
    List<int> weekdays = const [1, 2, 3, 4, 5, 6, 7],
    List<String> order = const ['session_a', 'session_b'],
    DateTime Function(DateTime)? civil,
  }) => service.nextSession(
    profile: 'fixture',
    programId: program,
    orderedSessionIds: order,
    trainingWeekdays: weekdays,
    requestedDate: date ?? generatedTime,
    civilDateOfEnd: civil ?? (_) => generatedTime,
  );

  test(
    'recreated service resumes exact prescription and recorded actuals',
    () async {
      await service.commit(await setAction());
      final resumed = await SavedWorkoutService(repo).resume('fixture');
      expect(resumed!.prescription.encode(), generatedPlan().encode());
      expect(resumed.occurrence.sets.single.reps, 12);
      expect((await next()).reasonCode, 'resume_session');
      expect(await service.resume('other'), isNull);
    },
  );
  test('completion requires work; early end retains partial work and advances once', () async {
    await expectLater(finish(false), throwsA(isA<LoggingException>()));
    await service.commit(await setAction());
    final action = await finish(true);
    await service.commit(action);
    await service.commit(action);
    expect(repo.history.revision, 3);
    expect(repo.history.occurrences.single.sets, hasLength(1));
    expect(await service.resume('fixture'), isNull);
    final result = await next();
    expect(result.sessionId, 'session_b');
    expect(result.date, generatedTime.add(const Duration(days: 1)));
    await expectLater(finish(true), throwsA(isA<LoggingException>()));
  });
  test('complete advances and wraps; misses and schedule changes do not consume sessions', () async {
    await service.commit(await setAction());
    await service.commit(await setAction(index: 2, action: 'set2'));
    await service.commit(await finish(false));
    expect(repo.history.occurrences.single.status, OccurrenceStatus.completed);
    expect((await next(order: ['session_a'])).sessionId, 'session_a');
    expect(
      (await next(date: DateTime.utc(2026, 10, 20))).sessionId,
      'session_b',
    );
    expect((await next(weekdays: [])).reasonCode, 'schedule_required');
    expect((await next(weekdays: [1])).date, DateTime.utc(2026, 9, 28));
  });
  test('lost acknowledgement retries exact receipt; stale concurrent action rejects', () async {
    final first = await setAction();
    final stale = await setAction(index: 2, action: 'stale');
    repo.loseAcknowledgement = true;
    await expectLater(service.commit(first), throwsA(isA<LoggingException>()));
    repo.loseAcknowledgement = false;
    await service.commit(first);
    expect(repo.history.revision, 2);
    await expectLater(service.commit(stale), throwsA(isA<LoggingException>()));
    expect(repo.history.occurrences.single.sets, hasLength(1));
  });
  test(
    'write and read failures never acknowledge success; retry remains usable',
    () async {
      final action = await setAction();
      repo.failWrite = true;
      await expectLater(
        service.commit(action),
        throwsA(isA<LoggingException>()),
      );
      expect(repo.history.revision, 1);
      repo.failWrite = false;
      repo.failRead = true;
      await expectLater(
        service.commit(action),
        throwsA(isA<LoggingException>()),
      );
      repo.failRead = false;
      await service.commit(action);
      expect(repo.history.revision, 2);
    },
  );
  test('invalid identities, dates, sequence and foreign active program are blocked', () async {
    await expectLater(
      service.prepareSet(
        profile: 'other',
        occurrenceId: 'session0',
        set: generatedActual(),
        at: generatedTime,
        actionId: 'x',
      ),
      throwsA(isA<LoggingException>()),
    );
    expect((await next(program: 'other')).reasonCode, 'other_program_active');
    expect((await next(order: ['wrong'])).reasonCode, 'invalid_history');
    expect(
      (await next(date: generatedTime.add(const Duration(hours: 1))))
          .reasonCode,
      'invalid_input',
    );
    await service.commit(await finish(true));
    await expectLater(
      next(civil: (_) => DateTime(2026, 9, 25)),
      throwsA(isA<LoggingException>()),
    );
  });
  test(
    'corrections retain safety stops and do not advance the queue again',
    () async {
      await service.commit(
        await service.prepareSet(
          profile: 'fixture',
          occurrenceId: 'session0',
          set: generatedActual(validity: SetValidity.pain),
          at: generatedTime,
          actionId: 'pain',
        ),
      );
      await service.commit(
        await service.prepareSet(
          profile: 'fixture',
          occurrenceId: 'session0',
          set: generatedActual(rir: null),
          at: generatedTime,
          actionId: 'correction',
        ),
      );
      await expectLater(setAction(index: 2), throwsA(isA<LoggingException>()));
      await service.commit(await finish(true));
      await service.commit(
        await service.prepareSet(
          profile: 'fixture',
          occurrenceId: 'session0',
          set: generatedActual(reps: 9, rir: null),
          at: generatedTime,
          actionId: 'later_correction',
        ),
      );
      expect(repo.history.occurrences.single.stoppedSlots, ['press']);
      expect(repo.history.occurrences.single.sets.single.rir, isNull);
      expect((await next()).sessionId, 'session_b');
    },
  );

  test('local end date, not UTC date, bounds next opportunity', () async {
    await service.commit(await finish(true));
    final result = await next(
      civil: (_) => DateTime.utc(2026, 9, 24),
      date: DateTime.utc(2026, 9, 24),
    );
    expect(result.date, DateTime.utc(2026, 9, 25));
  });
}
