import 'package:adaptive_workout/features/setup/training_setup_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/training_setup_fixture.dart';

void main() {
  testWidgets('preferences save and reload with unknown equipment untouched', (
    tester,
  ) async {
    final repo = MemoryTrainingSetupRepository();
    await tester.pumpWidget(
      MaterialApp(home: TrainingSetupPage(repository: repo)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tue'));
    await tester.enterText(
      find.widgetWithText(TextField, 'Preferred workout minutes'),
      '50',
    );
    await tester.tap(find.text('Save preferences'));
    await tester.pumpAndSettle();
    expect(repo.profiles['local_owner']!.trainingDays, [2]);
    expect(repo.profiles['local_owner']!.equipment, isEmpty);
    expect(find.text('Preferences saved on this device.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(
      MaterialApp(home: TrainingSetupPage(repository: repo)),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilterChip>(find.widgetWithText(FilterChip, 'Tue'))
          .selected,
      isTrue,
    );
    expect(find.text('50'), findsOneWidget);
  });
  testWidgets(
    'equipment form stays open on invalid confirmation and has a draft path',
    (tester) async {
      final repo = MemoryTrainingSetupRepository();
      await tester.pumpWidget(
        MaterialApp(home: TrainingSetupPage(repository: repo)),
      );
      await tester.pumpAndSettle();
      final add = find.text('Add equipment / starting load');
      await tester.ensureVisible(add);
      await tester.tap(add);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save unverified setup'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(repo.profiles, isEmpty);
      await tester.enterText(
        find.widgetWithText(TextField, 'Machine / setup label'),
        'fixture setup',
      );
      await tester.tap(find.text('Save unverified setup'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(repo.profiles['local_owner']!.equipment.single.confirmed, isFalse);
      expect(repo.profiles['local_owner']!.startingLoads, isEmpty);
    },
  );
}
