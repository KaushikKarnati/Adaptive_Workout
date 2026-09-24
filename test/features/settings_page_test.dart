import 'package:adaptive_workout/domain/gyms/gym_profile.dart';
import 'package:adaptive_workout/features/gyms/gym_profile_page.dart';
import 'package:adaptive_workout/features/program/program_page.dart';
import 'package:adaptive_workout/features/settings/appearance_controller.dart';
import 'package:adaptive_workout/features/settings/appearance_page.dart';
import 'package:adaptive_workout/features/settings/settings_page.dart';
import 'package:adaptive_workout/features/setup/training_setup_page.dart';
import 'package:adaptive_workout/main.dart';
import 'package:adaptive_workout/ui/app_haptics.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_appearance_repository.dart';
import '../support/fake_gym_profile_repository.dart';
import '../support/fake_haptics_driver.dart';
import '../support/training_setup_fixture.dart';

Future<void> toggleSection(WidgetTester tester, String title) async {
  final header = find.widgetWithText(ListTile, title).first;
  await tester.ensureVisible(header);
  await tester.pumpAndSettle();
  await tester.tap(header);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'settings keeps all four sections on one route and loads lazily',
    (tester) async {
      final appearance = AppearanceController(FakeAppearanceRepository());
      final driver = FakeHapticsDriver();
      final haptics = AppHaptics(driver: driver);
      await Future.wait([appearance.load(), haptics.load()]);
      addTearDown(appearance.dispose);
      addTearDown(haptics.dispose);
      await tester.pumpWidget(
        AdaptiveWorkoutApp(
          appearance: appearance,
          haptics: haptics,
          home: SettingsPage(
            trainingSetupRepository: MemoryTrainingSetupRepository(),
            gymRepository: FakeGymProfileRepository()
              ..stored = GymProfiles(profiles: []).select(homewoodProfile()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(TrainingSetupPage), findsNothing);
      expect(find.byType(GymProfilePage), findsNothing);
      for (final key in [
        'settings_appearance',
        'settings_program',
        'settings_setup',
        'settings_gym',
      ]) {
        expect(find.byKey(Key(key)), findsOneWidget);
      }
      for (final (title, type) in [
        ('Appearance & feedback', AppearancePage),
        ('Your program', ProgramPage),
        ('Training setup', TrainingSetupPage),
        ('My gym', GymProfilePage),
      ]) {
        await toggleSection(tester, title);
        expect(find.byType(type), findsOneWidget);
        expect(find.byType(Scaffold), findsOneWidget);
        expect(find.byType(AppBar), findsOneWidget);
        expect(
          Navigator.of(tester.element(find.byType(type))).canPop(),
          isFalse,
        );
        expect(find.text('Log workouts / history'), findsNothing);
        expect(find.text('Training setup / starting loads'), findsNothing);
        expect(
          find.text('Choose a location and confirm its equipment'),
          findsNothing,
        );
        await toggleSection(tester, title);
      }
      expect(driver.events, isEmpty, reason: 'Disclosures are quiet.');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('collapsed settings retain unsaved training choices and text', (
    tester,
  ) async {
    final repo = MemoryTrainingSetupRepository();
    await tester.pumpWidget(
      MaterialApp(
        home: SettingsPage(
          trainingSetupRepository: repo,
          gymRepository: FakeGymProfileRepository(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await toggleSection(tester, 'Training setup');
    final minutes = find.widgetWithText(TextField, 'Preferred workout minutes');
    final monday = find.widgetWithText(FilterChip, 'Mon');
    await tester.ensureVisible(monday);
    await tester.tap(monday);
    await tester.enterText(minutes, '55');
    await toggleSection(tester, 'Training setup');
    expect(find.byType(TrainingSetupPage), findsNothing);
    await toggleSection(tester, 'My gym');
    await toggleSection(tester, 'My gym');
    await toggleSection(tester, 'Training setup');
    expect(tester.widget<FilterChip>(monday).selected, isTrue);
    expect(tester.widget<TextField>(minutes).controller!.text, '55');
    expect(repo.writes, 0);
    expect(tester.takeException(), isNull);
  });

  for (final brightness in Brightness.values) {
    testWidgets('inline sections fit narrow large text in ${brightness.name}', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      tester.platformDispatcher.platformBrightnessTestValue = brightness;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      final appearance = AppearanceController(FakeAppearanceRepository());
      final haptics = AppHaptics(driver: FakeHapticsDriver());
      await Future.wait([appearance.load(), haptics.load()]);
      addTearDown(appearance.dispose);
      addTearDown(haptics.dispose);
      await tester.pumpWidget(
        AdaptiveWorkoutApp(
          appearance: appearance,
          haptics: haptics,
          home: SettingsPage(
            trainingSetupRepository: MemoryTrainingSetupRepository(),
            gymRepository: FakeGymProfileRepository(),
          ),
        ),
      );
      for (final title in [
        'Appearance & feedback',
        'Your program',
        'Training setup',
        'My gym',
      ]) {
        await toggleSection(tester, title);
        if (title == 'Your program') {
          await toggleSection(tester, 'Monday');
        }
        expect(tester.takeException(), isNull);
        await toggleSection(tester, title);
      }
    });
  }
}
