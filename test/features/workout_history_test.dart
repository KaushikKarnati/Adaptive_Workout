import 'package:adaptive_workout/domain/history/workout_history.dart';
import 'package:adaptive_workout/domain/logging/program_log.dart';
import 'package:adaptive_workout/domain/logging/practice_repository.dart';
import 'package:adaptive_workout/features/history/workout_history_page.dart';
import 'package:adaptive_workout/ui/app_theme.dart';
import 'package:adaptive_workout/ui/app_haptics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../domain/logging/program_log_test.dart' show entry;
import '../support/fake_program_log_repository.dart';
import '../support/fake_haptics_driver.dart';

ProgramLog log(
  String id, {
  List<ProgramSet>? sets,
  String profile = 'local_owner',
  bool finished = true,
}) => ProgramLog(
  id: id,
  profile: profile,
  programId: 'monday',
  startedAt: DateTime.utc(2026, 9, 20),
  revision: 1,
  completedAt: finished ? DateTime.utc(2026, 9, 20, 1) : null,
  endedEarly: true,
  sets: sets ?? [entry()],
);
void main() {
  testWidgets('history controls cue only changed selections and respect mute', (
    tester,
  ) async {
    final repo = FakeProgramLogRepository();
    repo.logs['a'] = log('a');
    final driver = FakeHapticsDriver();
    final haptics = AppHaptics(driver: driver);
    await haptics.load();
    addTearDown(haptics.dispose);
    await tester.pumpWidget(
      AppHapticsScope(
        haptics: haptics,
        child: MaterialApp(home: WorkoutHistoryPage(repository: repo)),
      ),
    );
    await tester.pumpAndSettle();
    expect(driver.events, isEmpty);
    await tester.tap(find.widgetWithText(ChoiceChip, 'History'));
    await tester.tap(find.widgetWithText(ChoiceChip, 'All time'));
    await tester.enterText(find.byKey(const Key('history_search')), 'incline');
    await tester.pumpAndSettle();
    expect(driver.events, isEmpty);
    await tester.tap(find.widgetWithText(ChoiceChip, '90 days'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, '90 days'));
    await tester.tap(find.widgetWithText(ChoiceChip, 'All time'));
    await tester.tap(find.widgetWithText(ChoiceChip, 'Graphs'));
    await tester.pumpAndSettle();
    expect(driver.events, ['selection', 'selection', 'selection']);
    await tester.ensureVisible(find.widgetWithText(ChoiceChip, 'Reps'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Reps'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ChoiceChip, 'Reps'));
    expect(driver.events, hasLength(4));
    await haptics.setEnabled(false);
    await tester.tap(find.widgetWithText(ChoiceChip, 'Load'));
    await tester.pumpAndSettle();
    expect(driver.events, hasLength(4));
    expect(repo.writes, 0);
  });

  testWidgets('embedded history opens its source without pushing a route', (
    tester,
  ) async {
    final repo = FakeProgramLogRepository();
    repo.logs['a'] = log('a');
    String? opened;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WorkoutHistoryPage(
            repository: repo,
            embedded: true,
            onOpenLog: (value) async => opened = value.id,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('history_workout_a')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('history_workout_a')));
    await tester.pumpAndSettle();
    expect(opened, 'a');
    expect(find.byType(Scaffold), findsOneWidget);
    expect(
      Navigator.of(tester.element(find.byType(WorkoutHistoryPage))).canPop(),
      isFalse,
    );
    expect(repo.writes, 0);
  });

  test('history scopes profile, completion, search, dates and stable ties', () {
    final logs = [
      log('b'),
      log('a'),
      log('private', profile: 'other'),
      log('draft', finished: false),
    ];
    expect(
      filterWorkoutHistory(logs, profile: 'local_owner').map((l) => l.id),
      ['a', 'b'],
    );
    expect(
      filterWorkoutHistory(logs, profile: 'local_owner', query: 'no match'),
      isEmpty,
    );
    expect(
      filterWorkoutHistory(logs, profile: 'local_owner', query: 'INCLINE'),
      hasLength(2),
    );
    expect(
      filterWorkoutHistory(
        logs,
        profile: 'local_owner',
        since: DateTime.utc(2026, 9, 21),
      ),
      isEmpty,
    );
    expect(
      filterWorkoutHistory(
        logs,
        profile: 'local_owner',
        since: DateTime.utc(2026, 9, 20),
      ),
      hasLength(2),
    );
  });
  test('graphs exclude missing, skipped, warmup, pain and invalid actuals', () {
    final result = exerciseHistory([
      log(
        'a',
        sets: [
          entry(),
          entry(warmup: true),
          entry(skipped: true),
          entry(validity: SetValidity.pain),
          entry(validity: SetValidity.unknown),
          entry(validity: SetValidity.invalid),
          entry(reps: null),
          entry(reps: 0),
          entry(load: null),
        ],
      ),
      log('draft', finished: false),
    ]);
    expect(result.single.points, hasLength(1));
    expect(exerciseHistory([]), isEmpty);
  });
  test(
    'set corrections replace points and exact setups and sides stay separate',
    () {
      final original = log('a');
      final corrected = original.record(entry(load: 40000000));
      expect(
        exerciseHistory([corrected]).single.points.single.set.load,
        40000000,
      );
      final groups = exerciseHistory([
        log(
          'a',
          sets: [
            entry(),
            entry(setup: 'other'),
            entry(side: LoggedSide.left),
            entry(convention: LoadConvention.totalLoad),
          ],
        ),
      ]);
      expect(groups, hasLength(4));
    },
  );
  testWidgets('history searches and graph values navigate to saved workout', (
    tester,
  ) async {
    final repo = FakeProgramLogRepository();
    repo.logs['a'] = log('a');
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.build(Brightness.light),
        home: WorkoutHistoryPage(repository: repo),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('1 finished workouts'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('history_search')), 'missing');
    await tester.pumpAndSettle();
    expect(find.text('0 finished workouts'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('history_search')), '');
    await tester.tap(find.widgetWithText(ChoiceChip, 'Graphs'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Recorded sets'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Recorded sets'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('10 reps × 30 lb per dumbbell'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('10 reps × 30 lb per dumbbell'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('delete_selected_workout')), findsOneWidget);
    expect(repo.writes, 0);
  });
  testWidgets('graphs fit narrow large-text light and dark screens', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = FakeProgramLogRepository();
    repo.logs['a'] = log('a');
    for (final theme in [
      AppTheme.build(Brightness.light),
      AppTheme.build(Brightness.dark),
    ]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: child!,
          ),
          home: WorkoutHistoryPage(repository: repo, graphs: true),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Recorded sets'),
        250,
        scrollable: find
            .descendant(
              of: find.byType(ListView).first,
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });
  testWidgets('failed read retries without fabricated empty data', (
    tester,
  ) async {
    final repo = FakeProgramLogRepository()..failRead = true;
    await tester.pumpWidget(
      MaterialApp(home: WorkoutHistoryPage(repository: repo)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Could not open workouts. Try again.'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('0 finished workouts'), findsOneWidget);
  });
}
