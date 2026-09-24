import 'package:adaptive_workout/features/home/workout_home_page.dart';
import 'package:adaptive_workout/features/program/program_logging_page.dart';
import 'package:adaptive_workout/main.dart';
import 'package:adaptive_workout/ui/app_haptics.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_haptics_driver.dart';
import '../support/fake_program_log_repository.dart';

void main() {
  testWidgets(
    'two tabs retain a workout and settings edits with changed-only feedback',
    (tester) async {
      final driver = FakeHapticsDriver();
      final haptics = AppHaptics(driver: driver);
      await haptics.load();
      addTearDown(haptics.dispose);
      final logs = FakeProgramLogRepository();
      await tester.pumpWidget(
        AdaptiveWorkoutApp(
          haptics: haptics,
          home: WorkoutHomePage(
            workoutRepository: logs,
            settings: const Scaffold(
              body: TextField(key: Key('settings_draft')),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<CupertinoTabBar>(find.byType(CupertinoTabBar))
            .items
            .length,
        2,
      );
      expect(find.byKey(const Key('settings_draft')), findsNothing);
      await tester.scrollUntilVisible(find.text('Start Monday'), 200);
      await tester.tap(find.text('Start Monday'));
      await tester.pumpAndSettle();
      expect(logs.logs.length, 1);
      driver.events.clear();
      await tester.tap(find.byKey(const Key('tab_settings')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const Key('settings_draft')),
        'Keep this edit',
      );
      await tester.tap(find.byKey(const Key('tab_settings')));
      await tester.pump();
      expect(driver.events, ['selection']);
      await tester.tap(find.byKey(const Key('tab_workout')));
      await tester.pumpAndSettle();
      expect(find.byType(ProgramLoggingPage), findsOneWidget);
      expect(find.byTooltip('Delete workout'), findsOneWidget);
      expect(logs.logs.length, 1);
      await haptics.setEnabled(false);
      await tester.tap(find.byKey(const Key('tab_settings')));
      await tester.pumpAndSettle();
      expect(find.text('Keep this edit'), findsOneWidget);
      expect(driver.events, ['selection', 'selection']);
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final brightness in Brightness.values) {
    testWidgets(
      'two destinations remain reachable with enlarged text in $brightness',
      (tester) async {
        tester.view.physicalSize = const Size(320, 700);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        tester.platformDispatcher.platformBrightnessTestValue = brightness;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
        await tester.pumpWidget(
          AdaptiveWorkoutApp(
            home: WorkoutHomePage(
              workoutRepository: FakeProgramLogRepository(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('tab_workout')), findsOneWidget);
        expect(find.byKey(const Key('tab_settings')), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.byKey(const Key('tab_settings')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('settings_program')), findsOneWidget);
        expect(find.byKey(const Key('home_practice')), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
