import 'package:adaptive_workout/features/program/program_logging_page.dart';
import 'package:adaptive_workout/domain/logging/practice_repository.dart';
import 'package:adaptive_workout/domain/logging/program_log.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_program_log_repository.dart';

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
    'manual workout opens a saved draft and explicit skip survives reopening',
    (tester) async {
      final repo = FakeProgramLogRepository();
      await tester.pumpWidget(
        MaterialApp(home: ProgramLoggingPage(repository: repo)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start Monday'));
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
      await tester.pumpWidget(
        MaterialApp(home: ProgramLoggingPage(repository: repo)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start Monday'));
      await tester.pumpAndSettle();
      repo.failWrite = true;
      await tester.tap(
        find.byKey(const Key('incline_dumbbell_press_false_1_both')),
      );
      await tester.pumpAndSettle();
      await _configureIdentity(tester);
      await tester.tap(find.text('Skip set'));
      await tester.pumpAndSettle();
      expect(tester.widget<PopScope>(find.byType(PopScope)).canPop, isFalse);
      expect(find.textContaining('Unconfirmed entry:'), findsOneWidget);
      repo.failWrite = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(tester.widget<PopScope>(find.byType(PopScope)).canPop, isTrue);
      expect(repo.logs.values.single.sets.length, 1);
    },
  );
  testWidgets('saving pain immediately presents accessible stop guidance', (
    tester,
  ) async {
    final repo = FakeProgramLogRepository();
    await tester.pumpWidget(
      MaterialApp(home: ProgramLoggingPage(repository: repo)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start Monday'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const Key('incline_dumbbell_press_false_1_both')),
    );
    await tester.pumpAndSettle();
    await _configureIdentity(tester);
    await tester.enterText(
      find.widgetWithText(TextField, 'Actual load (lb)'),
      '30',
    );
    await tester.enterText(find.widgetWithText(TextField, 'Actual reps'), '8');
    await tester.tap(
      find.widgetWithText(DropdownButtonFormField<SetValidity>, 'Set quality'),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('pain').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Save set'));
    await tester.tap(find.text('Save set'));
    await tester.pumpAndSettle();

    final guidance = find.byKey(const Key('program_pain_stop'));
    expect(guidance, findsOneWidget);
    expect(tester.getSemantics(guidance).flagsCollection.isLiveRegion, isTrue);
    expect(find.textContaining('Stop the affected exercise'), findsOneWidget);
  });

  testWidgets(
    'alternative slot requires a variation before it can be skipped',
    (tester) async {
      final repo = FakeProgramLogRepository();
      await tester.pumpWidget(
        MaterialApp(home: ProgramLoggingPage(repository: repo)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start Wednesday'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('shoulder_press_false_1_both')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Skip set'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Check the variation'), findsOneWidget);
      expect(repo.logs.values.single.sets, isEmpty);

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
    },
  );
  testWidgets('logging dialog supports enlarged text on a narrow phone', (
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
        home: ProgramLoggingPage(repository: FakeProgramLogRepository()),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Start Monday'), 250);
    await tester.tap(find.text('Start Monday'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const Key('incline_dumbbell_press_false_1_both')),
      250,
    );
    await tester.tap(
      find.byKey(const Key('incline_dumbbell_press_false_1_both')),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
