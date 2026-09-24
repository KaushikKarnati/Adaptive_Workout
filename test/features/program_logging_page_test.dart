import 'package:adaptive_workout/features/program/program_log_controller.dart';
import 'package:adaptive_workout/ui/app_haptics.dart';
import 'package:adaptive_workout/ui/app_theme.dart';

import '../domain/logging/program_log_test.dart' show entry, filled;

import 'package:adaptive_workout/features/program/program_logging_page.dart';
import 'package:adaptive_workout/domain/logging/practice_repository.dart';
import 'package:adaptive_workout/domain/logging/program_log.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_program_log_repository.dart';
import '../support/fake_haptics_driver.dart';

Widget _withHaptics(ProgramLogRepository repository, AppHaptics haptics) =>
    AppHapticsScope(
      haptics: haptics,
      child: MaterialApp(home: ProgramLoggingPage(repository: repository)),
    );

Future<void> _configureIdentity(
  WidgetTester tester, {
  String convention = 'Pounds per dumbbell',
}) async {
  await tester.enterText(
    find.widgetWithText(TextField, 'Exact machine / setup'),
    'fixture setup',
  );
  await tester.tap(
    find.widgetWithText(
      DropdownButtonFormField<LoadConvention>,
      'How this load is measured',
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.text(convention).last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'inline history preserves draft, reloads corrections and filters',
    (tester) async {
      final repo = FakeProgramLogRepository();
      final c = ProgramLogController(repo);
      await c.start('monday');
      await c.record(entry());
      await c.finish(endEarly: true);
      final saved = c.selected!;
      await c.start('friday');
      final draft = c.selected!;
      c.dispose();
      final driver = FakeHapticsDriver();
      final haptics = AppHaptics(driver: driver);
      await haptics.load();
      addTearDown(haptics.dispose);
      await tester.pumpWidget(_withHaptics(repo, haptics));
      await tester.pumpAndSettle();
      expect(find.text('Friday'), findsOneWidget);
      await tester.tap(find.byKey(const Key('workout_history_view')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('history_search')), 'Upper');
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('workout_log_view')));
      await tester.pumpAndSettle();
      expect(find.text('Friday'), findsOneWidget);
      expect(repo.logs[draft.id], same(draft));
      expect(driver.events, ['selection', 'selection']);
      await tester.tap(find.byKey(const Key('workout_history_view')));
      await tester.pumpAndSettle();
      expect(find.text('Upper'), findsOneWidget);
      repo.logs[saved.id] = saved.record(entry(load: 40000000));
      await tester.ensureVisible(
        find.byKey(Key('history_workout_${saved.id}')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(Key('history_workout_${saved.id}')));
      await tester.pumpAndSettle();
      expect(find.text('Monday'), findsOneWidget);
      expect(
        Navigator.of(tester.element(find.byType(ProgramLoggingPage))).canPop(),
        isFalse,
      );
      await tester.ensureVisible(
        find.byKey(const Key('incline_dumbbell_press_false_1_both')),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('40 lb (perDumbbell)'), findsOneWidget);
      expect(driver.events, ['selection', 'selection', 'selection']);
    },
  );

  testWidgets('new workout feedback waits for the persisted reload', (
    tester,
  ) async {
    final repo = FakeProgramLogRepository();
    final driver = FakeHapticsDriver();
    final haptics = AppHaptics(driver: driver);
    await haptics.load();
    addTearDown(haptics.dispose);
    await tester.pumpWidget(_withHaptics(repo, haptics));
    await tester.pumpAndSettle();
    expect(driver.events, isEmpty);

    repo.failRead = true;
    await tester.tap(find.text('Start Monday'));
    await tester.pumpAndSettle();
    expect(repo.writes, 1);
    expect(driver.events, ['error']);
    expect(find.textContaining('Save not confirmed'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(repo.writes, 1);
    expect(driver.events, ['error', 'impact']);
    await tester.pump();
    expect(driver.events, ['error', 'impact']);
  });

  for (final complete in [false, true]) {
    testWidgets(
      'finish feedback reflects ${complete ? 'saved completion' : 'missing working sets'}',
      (tester) async {
        final repo = FakeProgramLogRepository();
        final c = ProgramLogController(repo);
        await c.start('monday');
        if (complete) repo.logs[c.selected!.id] = filled(c.selected!);
        c.dispose();
        final driver = FakeHapticsDriver();
        final haptics = AppHaptics(driver: driver);
        await haptics.load();
        addTearDown(haptics.dispose);
        await tester.pumpWidget(_withHaptics(repo, haptics));
        await tester.pumpAndSettle();
        expect(driver.events, isEmpty);
        await tester.scrollUntilVisible(find.text('Finish workout'), 500);
        await tester.tap(find.text('Finish workout'));
        await tester.pumpAndSettle();
        expect(repo.logs.values.single.completed, complete);
        expect(driver.events, [complete ? 'success' : 'error']);
      },
    );
  }

  testWidgets(
    'delete confirmation cancels safely and removes a finished history row',
    (tester) async {
      final repo = FakeProgramLogRepository();
      final driver = FakeHapticsDriver();
      final haptics = AppHaptics(driver: driver);
      await haptics.load();
      addTearDown(haptics.dispose);
      final c = ProgramLogController(repo);
      await c.start('monday');
      await c.record(entry());
      await c.finish(endEarly: true);
      c.dispose();
      await tester.pumpWidget(_withHaptics(repo, haptics));
      await tester.pumpAndSettle();
      await tester.tap(find.text('History'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.widgetWithText(ListTile, 'Upper chest + lats'),
        300,
        scrollable: find
            .descendant(
              of: find.byType(ListView),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Upper chest + lats'));
      await tester.pumpAndSettle();
      driver.events.clear();
      await tester.tap(find.byKey(const Key('delete_selected_workout')));
      await tester.pumpAndSettle();
      expect(find.textContaining('including corrections'), findsOneWidget);
      expect(driver.events, ['warning']);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(repo.logs, hasLength(1));
      expect(driver.events, ['warning']);
      await tester.tap(find.byKey(const Key('delete_selected_workout')));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Delete workout'));
      await tester.pumpAndSettle();
      expect(repo.logs, isEmpty);
      expect(find.byKey(const Key('delete_selected_workout')), findsNothing);
      expect(find.text('Workout deleted'), findsOneWidget);
      expect(driver.events, ['warning', 'warning', 'success']);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(_withHaptics(repo, haptics));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('delete_selected_workout')), findsNothing);
      expect(driver.events, ['warning', 'warning', 'success']);
    },
  );
  testWidgets('open draft deletion failure shows retry without success', (
    tester,
  ) async {
    final repo = FakeProgramLogRepository();
    final driver = FakeHapticsDriver();
    final haptics = AppHaptics(driver: driver);
    await haptics.load();
    addTearDown(haptics.dispose);
    final c = ProgramLogController(repo);
    await c.start('monday');
    c.dispose();
    await tester.pumpWidget(_withHaptics(repo, haptics));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('delete_selected_workout')));
    await tester.pumpAndSettle();
    repo.failWrite = true;
    await tester.tap(find.widgetWithText(FilledButton, 'Delete workout'));
    await tester.pumpAndSettle();
    expect(find.text('Deletion not confirmed. Retry safely.'), findsOneWidget);
    expect(find.text('Workout deleted'), findsNothing);
    expect(repo.logs, hasLength(1));
    expect(driver.events, ['warning', 'error']);
    repo.failWrite = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(repo.logs, isEmpty);
    expect(driver.events, ['warning', 'error', 'success']);
    expect(find.text('Workout'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('choose today starts Friday directly and survives reopening', (
    tester,
  ) async {
    final repo = FakeProgramLogRepository();
    final driver = FakeHapticsDriver();
    final haptics = AppHaptics(driver: driver);
    await haptics.load();
    addTearDown(haptics.dispose);
    await tester.pumpWidget(_withHaptics(repo, haptics));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('choose_today_workout')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('choose_today_friday')));
    await tester.pumpAndSettle();
    expect(repo.logs.values.single.programId, 'friday');
    expect(driver.events, ['impact']);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(_withHaptics(repo, haptics));
    await tester.pumpAndSettle();
    expect(find.text('Friday'), findsOneWidget);
    expect(repo.logs, hasLength(1));
    expect(driver.events, ['impact']);
  });
  testWidgets(
    'switching requires explicit early finish and preserves saved sets',
    (tester) async {
      final repo = FakeProgramLogRepository();
      final driver = FakeHapticsDriver();
      final haptics = AppHaptics(driver: driver);
      await haptics.load();
      addTearDown(haptics.dispose);
      final c = ProgramLogController(repo);
      await c.start('monday');
      await c.record(entry());
      c.dispose();
      await tester.pumpWidget(_withHaptics(repo, haptics));
      await tester.pumpAndSettle();
      Future<void> chooseFriday() async {
        await tester.tap(find.byKey(const Key('choose_today_workout')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('choose_today_friday')));
        await tester.pumpAndSettle();
      }

      await chooseFriday();
      await tester.tap(find.text('Keep current workout'));
      await tester.pumpAndSettle();
      expect(repo.logs.values.single.completed, isFalse);
      expect(driver.events, ['warning']);
      await chooseFriday();
      await tester.tap(find.text('Finish early and continue'));
      await tester.pumpAndSettle();
      final old = repo.logs.values.singleWhere((l) => l.programId == 'monday');
      expect(old.endedEarly, isTrue);
      expect(old.sets.single.reps, 10);
      expect(
        repo.logs.values.singleWhere((l) => !l.completed).programId,
        'friday',
      );
      expect(find.text('Friday'), findsOneWidget);
      expect(driver.events, ['warning', 'warning', 'impact']);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'same day resumes and a failed early finish never starts another day',
    (tester) async {
      final repo = FakeProgramLogRepository();
      final driver = FakeHapticsDriver();
      final haptics = AppHaptics(driver: driver);
      await haptics.load();
      addTearDown(haptics.dispose);
      final c = ProgramLogController(repo);
      await c.start('monday');
      c.dispose();
      await tester.pumpWidget(_withHaptics(repo, haptics));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('choose_today_workout')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('choose_today_monday')));
      await tester.pumpAndSettle();
      expect(repo.logs, hasLength(1));
      expect(driver.events, isEmpty);
      repo.failWrite = true;
      await tester.tap(find.byKey(const Key('choose_today_workout')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('choose_today_tuesday')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Finish early and continue'));
      await tester.pumpAndSettle();
      expect(repo.logs.values.single.completed, isFalse);
      expect(find.textContaining('Save not confirmed'), findsOneWidget);
      expect(driver.events, ['warning', 'error']);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'manual workout opens a saved draft and explicit skip survives reopening',
    (tester) async {
      final repo = FakeProgramLogRepository();
      await tester.pumpWidget(
        MaterialApp(home: ProgramLoggingPage(repository: repo)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start Monday'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const Key('incline_dumbbell_press_false_1_both')),
      );

      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('incline_dumbbell_press_false_1_both')),
      );
      await tester.pumpAndSettle();
      await _configureIdentity(tester);
      await tester.tap(find.text('Skip set'));
      await tester.pumpAndSettle();
      expect(find.text('Skipped'), findsOneWidget);
      expect(repo.logs.values.single.sets.single.skipped, isTrue);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(
        MaterialApp(home: ProgramLoggingPage(repository: repo)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Skipped'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'failed save keeps pending set visible and blocks leaving until retry',
    (tester) async {
      final repo = FakeProgramLogRepository();
      final driver = FakeHapticsDriver();
      final haptics = AppHaptics(driver: driver);
      await haptics.load();
      addTearDown(haptics.dispose);
      await tester.pumpWidget(_withHaptics(repo, haptics));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start Monday'));
      await tester.pumpAndSettle();
      repo.failWrite = true;
      await tester.ensureVisible(
        find.byKey(const Key('incline_dumbbell_press_false_1_both')),
      );

      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('incline_dumbbell_press_false_1_both')),
      );
      await tester.pumpAndSettle();
      await _configureIdentity(tester);
      expect(driver.events, ['impact', 'selection']);
      driver.events.clear();
      await tester.tap(find.text('Skip set'));
      await tester.pumpAndSettle();
      expect(tester.widget<PopScope>(find.byType(PopScope)).canPop, isFalse);
      await tester.scrollUntilVisible(
        find.textContaining('Unconfirmed entry:'),
        -250,
      );
      expect(find.textContaining('Unconfirmed entry:'), findsOneWidget);
      expect(driver.events, ['error']);
      expect(
        tester
            .widget<SegmentedButton<bool>>(find.byType(SegmentedButton<bool>))
            .onSelectionChanged,
        isNull,
      );
      repo.failWrite = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(tester.widget<PopScope>(find.byType(PopScope)).canPop, isTrue);
      expect(repo.logs.values.single.sets.length, 1);
      expect(driver.events, ['error', 'success']);
    },
  );
  testWidgets('saving pain immediately presents accessible stop guidance', (
    tester,
  ) async {
    final repo = FakeProgramLogRepository();
    final driver = FakeHapticsDriver();
    final haptics = AppHaptics(driver: driver);
    await haptics.load();
    addTearDown(haptics.dispose);
    await tester.pumpWidget(_withHaptics(repo, haptics));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start Monday'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const Key('incline_dumbbell_press_false_1_both')),
    );

    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const Key('incline_dumbbell_press_false_1_both')),
    );
    await tester.pumpAndSettle();
    await _configureIdentity(tester);
    driver.events.clear();
    await tester.enterText(
      find.widgetWithText(TextField, 'Actual load (lb)'),
      '30',
    );
    await tester.enterText(find.widgetWithText(TextField, 'Actual reps'), '8');
    expect(driver.events, isEmpty);
    await tester.ensureVisible(
      find.widgetWithText(DropdownButtonFormField<SetValidity>, 'Set quality'),
    );
    await tester.tap(
      find.widgetWithText(DropdownButtonFormField<SetValidity>, 'Set quality'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('pain').last);
    await tester.pumpAndSettle();
    expect(driver.events, ['warning']);
    await tester.tap(
      find.widgetWithText(DropdownButtonFormField<SetValidity>, 'Set quality'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('pain').last);
    await tester.pumpAndSettle();
    expect(driver.events, ['warning']);
    await tester.ensureVisible(find.text('Save set'));
    await tester.tap(find.text('Save set'));
    await tester.pumpAndSettle();

    final guidance = find.byKey(const Key('program_pain_stop'));
    await tester.scrollUntilVisible(guidance, -250);
    expect(guidance, findsOneWidget);
    expect(tester.getSemantics(guidance).flagsCollection.isLiveRegion, isTrue);
    expect(find.textContaining('Stop the affected exercise'), findsOneWidget);
    expect(driver.events, ['warning', 'success']);
  });

  testWidgets(
    'alternative slot requires a variation before it can be skipped',
    (tester) async {
      final repo = FakeProgramLogRepository();
      final driver = FakeHapticsDriver();
      final haptics = AppHaptics(driver: driver);
      await haptics.load();
      addTearDown(haptics.dispose);
      await tester.pumpWidget(_withHaptics(repo, haptics));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Start Wednesday'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start Wednesday'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const Key('shoulder_press_false_1_both')),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('shoulder_press_false_1_both')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Skip set'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Check the variation'), findsOneWidget);
      expect(repo.logs.values.single.sets, isEmpty);
      expect(driver.events, ['impact', 'error']);

      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('machine shoulder press').last);
      await tester.pumpAndSettle();
      await _configureIdentity(
        tester,
        convention: 'Displayed machine setting (lb)',
      );
      await tester.ensureVisible(find.text('Skip set'));
      await tester.tap(find.text('Skip set'));
      await tester.pumpAndSettle();
      expect(
        repo.logs.values.single.sets.single.variant,
        'machine_shoulder_press',
      );
      expect(driver.events, [
        'impact',
        'error',
        'selection',
        'selection',
        'success',
      ]);
    },
  );
  for (final brightness in Brightness.values) {
    testWidgets(
      'logging dialog supports enlarged text on a narrow phone in ${brightness.name}',
      (tester) async {
        tester.view.physicalSize = const Size(320, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.build(brightness),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: ProgramLoggingPage(repository: FakeProgramLogRepository()),
          ),
        );
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(find.text('Start Monday'), 250);
        await Scrollable.ensureVisible(
          tester.element(find.text('Start Monday')),
          alignment: 0.5,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Start Monday'));
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.byKey(const Key('incline_dumbbell_press_false_1_both')),
          250,
        );
        await Scrollable.ensureVisible(
          tester.element(
            find.byKey(const Key('incline_dumbbell_press_false_1_both')),
          ),
          alignment: 0.5,
        );
        await tester.pumpAndSettle();
        await tester.ensureVisible(
          find.byKey(const Key('incline_dumbbell_press_false_1_both')),
        );

        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const Key('incline_dumbbell_press_false_1_both')),
        );
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget);
        final quality = find.widgetWithText(
          DropdownButtonFormField<SetValidity>,
          'Set quality',
        );
        await tester.ensureVisible(quality);
        await tester.pumpAndSettle();
        await tester.tap(quality);
        await tester.pumpAndSettle();
        await tester.tap(find.text('unknown').last);
        await tester.pumpAndSettle();
        expect(
          tester.getSize(find.widgetWithText(FilledButton, 'Save set')).height,
          greaterThanOrEqualTo(44),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
