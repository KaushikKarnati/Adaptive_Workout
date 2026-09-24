import 'package:adaptive_workout/features/setup/training_setup_page.dart';
import 'package:adaptive_workout/ui/app_haptics.dart';
import 'package:adaptive_workout/ui/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_haptics_driver.dart';
import '../support/training_setup_fixture.dart';

void main() {
  testWidgets('setup cues only changed selections and confirmed save results', (
    tester,
  ) async {
    final repo = MemoryTrainingSetupRepository();
    final driver = FakeHapticsDriver();
    final haptics = AppHaptics(driver: driver);
    await haptics.load();
    addTearDown(haptics.dispose);
    await tester.pumpWidget(
      AppHapticsScope(
        haptics: haptics,
        child: MaterialApp(home: TrainingSetupPage(repository: repo)),
      ),
    );
    await tester.pumpAndSettle();
    expect(driver.events, isEmpty);
    await tester.tap(find.text('Tue'));
    await tester.pump();
    expect(driver.events, ['selection']);
    tester
        .widget<FilterChip>(find.widgetWithText(FilterChip, 'Tue'))
        .onSelected!(true);
    await tester.pump();
    expect(driver.events, ['selection']);
    await tester.enterText(
      find.widgetWithText(TextField, 'Preferred workout minutes'),
      '50',
    );
    await tester.pump();
    expect(driver.events, ['selection']);

    // A committed write without a confirmed read must not celebrate success.
    repo.failNextRead = true;
    await tester.ensureVisible(find.text('Save preferences'));
    await tester.tap(find.text('Save preferences'));
    await tester.pumpAndSettle();
    expect(repo.profiles['local_owner']!.trainingDays, [2]);
    expect(driver.events, ['selection', 'error']);
    await tester.scrollUntilVisible(
      find.text('Retry save'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Retry save'));
    await tester.pumpAndSettle();
    expect(driver.events, ['selection', 'error', 'success']);
    await tester.pumpAndSettle();
    expect(driver.events, ['selection', 'error', 'success']);
  });

  testWidgets('equipment choices use one cue and cancel stays quiet', (
    tester,
  ) async {
    final driver = FakeHapticsDriver();
    final haptics = AppHaptics(driver: driver);
    await haptics.load();
    addTearDown(haptics.dispose);
    await tester.pumpWidget(
      AppHapticsScope(
        haptics: haptics,
        child: MaterialApp(
          home: TrainingSetupPage(repository: MemoryTrainingSetupRepository()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Add equipment / starting load'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Add equipment / starting load'));
    await tester.pumpAndSettle();
    expect(driver.events, isEmpty);
    final categories = find.byWidgetPredicate(
      (widget) =>
          widget is DropdownButtonFormField<String> &&
          widget.decoration.labelText == 'Equipment category',
    );
    tester.widget<DropdownButtonFormField<String>>(categories).onChanged!(
      'dumbbells',
    );
    await tester.pump();
    expect(driver.events, ['selection']);
    tester.widget<DropdownButtonFormField<String>>(categories).onChanged!(
      'dumbbells',
    );
    await tester.pump();
    expect(driver.events, ['selection']);
    final confirmation = find.widgetWithText(
      CheckboxListTile,
      'I checked this exact setup, its settings and my starting load.',
    );
    tester.widget<CheckboxListTile>(confirmation).onChanged!(true);
    await tester.pump();
    expect(driver.events, ['selection', 'selection']);
    tester.widget<CheckboxListTile>(confirmation).onChanged!(true);
    await tester.pump();
    expect(driver.events, ['selection', 'selection']);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(driver.events, ['selection', 'selection']);
  });

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
    await tester.ensureVisible(find.text('Save preferences'));
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
      final driver = FakeHapticsDriver();
      final haptics = AppHaptics(driver: driver);
      await haptics.load();
      addTearDown(haptics.dispose);
      await tester.pumpWidget(
        AppHapticsScope(
          haptics: haptics,
          child: MaterialApp(home: TrainingSetupPage(repository: repo)),
        ),
      );
      await tester.pumpAndSettle();
      final add = find.text('Add equipment / starting load');
      await tester.scrollUntilVisible(
        add,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(add);
      await tester.pumpAndSettle();
      expect(driver.events, isEmpty);
      await tester.tap(find.text('Save unverified setup'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(repo.profiles, isEmpty);
      expect(driver.events, ['error']);
      await tester.enterText(
        find.widgetWithText(TextField, 'Machine / setup label'),
        'fixture setup',
      );
      await tester.tap(find.text('Save unverified setup'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      expect(repo.profiles['local_owner']!.equipment.single.confirmed, isFalse);
      expect(repo.profiles['local_owner']!.startingLoads, isEmpty);
      expect(driver.events, ['error', 'success']);
    },
  );
  for (final brightness in Brightness.values) {
    testWidgets('setup supports large text in ${brightness.name} appearance', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
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
          home: TrainingSetupPage(repository: MemoryTrainingSetupRepository()),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      final add = find.text('Add equipment / starting load');
      await tester.scrollUntilVisible(
        add,
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(add);
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(
        find.text(
          'I checked this exact setup, its settings and my starting load.',
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
