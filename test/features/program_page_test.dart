import 'package:adaptive_workout/features/program/program_page.dart';
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

  testWidgets('preview supports narrow screens and enlarged text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: const ProgramPage(),
      ),
    );
    await tester.scrollUntilVisible(find.text('Monday'), 250);
    await tester.tap(find.text('Monday'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
