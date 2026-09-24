import 'package:adaptive_workout/features/home/workout_home_page.dart';
import 'package:adaptive_workout/features/program/program_page.dart';
import 'package:adaptive_workout/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('home leads with manual logging and opens program preview', (
    tester,
  ) async {
    await tester.pumpWidget(const AdaptiveWorkoutApp(home: WorkoutHomePage()));
    await tester.pumpAndSettle();

    expect(find.text('Training'), findsOneWidget);
    expect(find.text('Choose your workout'), findsOneWidget);
    expect(find.byKey(const Key('home_practice')), findsNothing);
    expect(find.text('Open workout log'), findsOneWidget);
    expect(find.byTooltip('Appearance and feedback'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('home_workout_log'))).height,
      greaterThanOrEqualTo(44),
    );
    expect(
      tester.getSize(find.byKey(const Key('home_appearance'))).height,
      greaterThanOrEqualTo(44),
    );

    await tester.scrollUntilVisible(find.byKey(const Key('home_program')), 250);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('home_program')));
    await tester.pumpAndSettle();
    expect(find.byType(ProgramPage), findsOneWidget);
    expect(find.text('Approved plan · Preview'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final brightness in Brightness.values) {
    testWidgets('home is usable with enlarged text in $brightness', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      tester.platformDispatcher.platformBrightnessTestValue = brightness;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);

      await tester.pumpWidget(
        const AdaptiveWorkoutApp(home: WorkoutHomePage()),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const Key('home_workout_log')),
        200,
      );
      expect(find.text('Open workout log'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.byKey(const Key('home_training_setup')),
        250,
      );
      expect(find.text('Training setup'), findsOneWidget);
      expect(find.byKey(const Key('home_practice')), findsNothing);
      expect(find.text('Practice logging'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
