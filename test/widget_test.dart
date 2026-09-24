import 'package:adaptive_workout/features/home/workout_home_page.dart';
import 'package:adaptive_workout/features/settings/settings_page.dart';
import 'package:adaptive_workout/features/practice/practice_page.dart';
import 'package:adaptive_workout/main.dart';
import 'package:adaptive_workout/features/workout/sample_workout_flow.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('default app opens Workout with exactly two main destinations', (
    tester,
  ) async {
    await tester.pumpWidget(const AdaptiveWorkoutApp());
    await tester.pumpAndSettle();
    expect(find.byType(WorkoutHomePage), findsOneWidget);
    expect(find.byKey(const Key('tab_workout')), findsOneWidget);
    expect(find.byKey(const Key('tab_settings')), findsOneWidget);
    expect(find.byType(PracticeBootstrap), findsNothing);
    await tester.tap(find.byKey(const Key('tab_settings')));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsPage), findsOneWidget);
    expect(find.byKey(const Key('settings_program')), findsOneWidget);
    expect(find.byKey(const Key('home_practice')), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('completes sample flow and preserves logged values', (
    tester,
  ) async {
    await tester.pumpWidget(
      const AdaptiveWorkoutApp(home: SampleWorkoutFlow()),
    );
    expect(find.text('Your next workout, made clear.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('get_started')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('preview_workout')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('start_workout')),
      200,
    );
    await tester.drag(find.byType(Scrollable).last, const Offset(0, -300));
    await tester.pump();
    tester
        .widget<FilledButton>(find.byKey(const Key('start_workout')))
        .onPressed!();
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('load_plus')));
    await tester.tap(find.byKey(const Key('reps_plus')));
    await tester.tap(find.byKey(const Key('rir_minus')));
    await tester.tap(find.byKey(const Key('log_set')));
    await tester.pump();
    expect(find.text('Logged: 170 lb × 7 @ 1 RIR'), findsOneWidget);
    expect(find.byKey(const Key('rest_timer')), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const Key('finish_workout')),
      150,
    );
    await tester.drag(find.byType(Scrollable).last, const Offset(0, -150));
    await tester.pump();
    await tester.tap(find.byKey(const Key('finish_workout')));
    await tester.pumpAndSettle();
    expect(find.text('Workout complete'), findsOneWidget);
    expect(find.text('Last set: 170 lb × 7 @ 1 RIR'), findsOneWidget);
  });

  testWidgets('back navigation keeps mock session values', (tester) async {
    await tester.pumpWidget(
      const AdaptiveWorkoutApp(home: SampleWorkoutFlow()),
    );
    await tester.tap(find.byKey(const Key('get_started')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('preview_workout')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('start_workout')),
      200,
    );
    await tester.tap(find.byKey(const Key('start_workout')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('load_plus')));
    await tester.pump();
    expect(find.text('170 lb'), findsOneWidget);

    await tester.tap(find.byKey(const Key('flow_back')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('start_workout')),
      200,
    );
    await tester.tap(find.byKey(const Key('start_workout')));
    await tester.pumpAndSettle();
    expect(find.text('170 lb'), findsOneWidget);
  });

  testWidgets('returning to Today resets the temporary sample session', (
    tester,
  ) async {
    await tester.pumpWidget(
      const AdaptiveWorkoutApp(home: SampleWorkoutFlow()),
    );
    await tester.tap(find.byKey(const Key('get_started')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('preview_workout')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('start_workout')),
      200,
    );
    await tester.tap(find.byKey(const Key('start_workout')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('load_plus')));
    await tester.tap(find.byKey(const Key('log_set')));
    await tester.pump();
    await tester.scrollUntilVisible(
      find.byKey(const Key('finish_workout')),
      150,
    );
    await tester.tap(find.byKey(const Key('finish_workout')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('return_today')),
      150,
      scrollable: find
          .descendant(
            of: find.byType(SingleChildScrollView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(find.byKey(const Key('return_today')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('preview_workout')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('start_workout')),
      200,
    );
    await tester.tap(find.byKey(const Key('start_workout')));
    await tester.pumpAndSettle();

    expect(find.text('165 lb'), findsOneWidget);
    expect(find.textContaining('Logged:'), findsNothing);
  });

  testWidgets('secondary navigation shows labeled placeholders', (
    tester,
  ) async {
    await tester.pumpWidget(
      const AdaptiveWorkoutApp(home: SampleWorkoutFlow()),
    );
    await tester.tap(find.byKey(const Key('get_started')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();
    expect(
      find.text('This area is a placeholder for a later milestone.'),
      findsOneWidget,
    );
  });

  testWidgets('welcome and today screens fit a narrow phone viewport', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const AdaptiveWorkoutApp(home: SampleWorkoutFlow()),
    );
    await tester.scrollUntilVisible(find.byKey(const Key('get_started')), 100);
    await tester.tap(find.byKey(const Key('get_started')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('preview_workout')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('critical flow remains usable with large Dynamic Type', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await tester.pumpWidget(
      const AdaptiveWorkoutApp(home: SampleWorkoutFlow()),
    );
    await tester.scrollUntilVisible(find.byKey(const Key('get_started')), 150);
    await tester.tap(find.byKey(const Key('get_started')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('preview_workout')),
      150,
    );
    await tester.tap(find.byKey(const Key('preview_workout')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('start_workout')),
      200,
    );
    await tester.drag(find.byType(Scrollable).last, const Offset(0, -300));
    await tester.pump();
    await tester.tap(find.byKey(const Key('start_workout')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('finish_workout')),
      150,
    );
    await tester.drag(find.byType(Scrollable).last, const Offset(0, -150));
    await tester.pump();
    await tester.tap(find.byKey(const Key('finish_workout')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('return_today')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sample set logging stops at the displayed four sets', (
    tester,
  ) async {
    await tester.pumpWidget(
      const AdaptiveWorkoutApp(home: SampleWorkoutFlow()),
    );
    await _openActiveWorkout(tester);

    final logSet = tester
        .widget<FilledButton>(find.byKey(const Key('log_set')))
        .onPressed!;
    for (var set = 0; set < 4; set++) {
      logSet();
      await tester.pump();
    }

    await tester.scrollUntilVisible(find.byKey(const Key('log_set')), 150);
    expect(find.text('All sample sets logged'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byKey(const Key('log_set'))).onPressed,
      isNull,
    );
  });

  testWidgets('sample notes survive completion back navigation', (
    tester,
  ) async {
    await tester.pumpWidget(
      const AdaptiveWorkoutApp(home: SampleWorkoutFlow()),
    );
    await _openActiveWorkout(tester);
    await tester.scrollUntilVisible(
      find.byKey(const Key('finish_workout')),
      150,
    );
    await tester.drag(find.byType(Scrollable).last, const Offset(0, -150));
    await tester.pump();
    await tester.tap(find.byKey(const Key('finish_workout')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Felt steady');
    await tester.tap(find.byKey(const Key('flow_back')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('finish_workout')),
      150,
    );
    await tester.drag(find.byType(Scrollable).last, const Offset(0, -150));
    await tester.pump();
    await tester.tap(find.byKey(const Key('finish_workout')));
    await tester.pumpAndSettle();

    expect(find.text('Felt steady'), findsOneWidget);
  });

  testWidgets('rest timer recomputes from its deadline after iOS resumes', (
    tester,
  ) async {
    var now = DateTime.utc(2026, 9, 7, 12);
    await tester.pumpWidget(
      MaterialApp(home: SampleWorkoutFlow(now: () => now)),
    );
    await _openActiveWorkout(tester);
    await tester.tap(find.byKey(const Key('log_set')));
    await tester.pump();
    expect(find.text('Rest 01:30'), findsOneWidget);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    now = now.add(const Duration(seconds: 30));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(find.text('Rest 01:00'), findsOneWidget);
  });
}

Future<void> _openActiveWorkout(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('get_started')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('preview_workout')));
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(find.byKey(const Key('start_workout')), 200);
  await tester.drag(find.byType(Scrollable).last, const Offset(0, -150));
  await tester.pump();
  tester
      .widget<FilledButton>(find.byKey(const Key('start_workout')))
      .onPressed!();
  await tester.pumpAndSettle();
}
