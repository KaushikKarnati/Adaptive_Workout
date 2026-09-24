import 'package:adaptive_workout/application/saved_workout_service.dart';
import 'package:adaptive_workout/data/repositories/sqlite_recommendation_history_repository.dart';
import 'package:adaptive_workout/domain/recommendations/recommendation_history.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sqflite/sqflite.dart';

import '../test/support/recommendation_fixture.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'saved sets survive reopen; terminal retry advances exactly once',
    (_) async {
      const path = 'saved_workout_lifecycle_fixture.sqlite';
      await deleteDatabase(path);
      var repo = await SqliteRecommendationHistoryRepository.open(path: path);
      try {
        final plan = generatedPlan();
        await repo.saveRecommendation(plan, actionId: 'plan');
        await repo.saveOccurrence(
          generatedStart(plan),
          expectedRevision: -1,
          expectedHistoryRevision: 0,
          actionId: 'start',
        );
        var service = SavedWorkoutService(repo);
        await service.commit(
          await service.prepareSet(
            profile: 'fixture',
            occurrenceId: 'session0',
            set: generatedActual(),
            at: generatedTime,
            actionId: 'set',
          ),
        );
        await repo.close();
        repo = await SqliteRecommendationHistoryRepository.open(path: path);
        service = SavedWorkoutService(repo);
        final resumed = await service.resume('fixture');
        expect(resumed!.prescription.encode(), plan.encode());
        expect(resumed.occurrence.sets.single.reps, 12);
        final finish = await service.prepareFinish(
          profile: 'fixture',
          occurrenceId: 'session0',
          endEarly: true,
          at: generatedTime,
          actionId: 'finish',
        );
        await service.commit(finish);
        await repo.close();
        repo = await SqliteRecommendationHistoryRepository.open(path: path);
        service = SavedWorkoutService(repo);
        await service.commit(finish);
        expect(await service.resume('fixture'), isNull);
        final history = await repo.load('fixture');
        expect(history.revision, 3);
        expect(history.occurrences.single.status, OccurrenceStatus.endedEarly);
        expect(history.occurrences.single.sets, hasLength(1));
        expect(
          (await repo.audit('fixture', 'session0')).map((s) => s.revision),
          [0, 1, 2],
        );
        final next = await service.nextSession(
          profile: 'fixture',
          programId: plan.programId,
          orderedSessionIds: ['session_a', 'session_b'],
          trainingWeekdays: [1, 2, 3, 4, 5, 6, 7],
          requestedDate: generatedTime,
          civilDateOfEnd: (_) => generatedTime,
        );
        expect(next.sessionId, 'session_b');
        expect(next.date, generatedTime.add(const Duration(days: 1)));
      } finally {
        await repo.close();
        await deleteDatabase(path);
      }
    },
  );
}
