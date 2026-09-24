import 'package:adaptive_workout/features/program/program_page.dart';
import 'package:adaptive_workout/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('program preview expands Monday without prescribing a load', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: ProgramPage()));
    expect(find.text('Approved plan · Preview'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Monday'), 250);
    await tester.tap(find.text('Monday'));
    await tester.pumpAndSettle();
    expect(find.text('Incline Dumbbell Press\n3 × 6–10'), findsOneWidget);
    expect(find.text('Rest 90 sec after both exercises.'), findsOneWidget);
    expect(find.text('Cable Chest Fly\n3 × 12–15'), findsOneWidget);
    expect(find.byType(TextField), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final brightness in Brightness.values) {
    testWidgets(
      'preview supports narrow screens and enlarged text in $brightness',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        tester.platformDispatcher.platformBrightnessTestValue = brightness;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
        await tester.pumpWidget(const AdaptiveWorkoutApp(home: ProgramPage()));
        await tester.scrollUntilVisible(find.text('Monday'), 250);
        await tester.tap(find.text('Monday'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }
}
