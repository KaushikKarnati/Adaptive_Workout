import 'dart:io';

import 'package:adaptive_workout/application/appearance_preferences.dart';
import 'package:adaptive_workout/data/repositories/sqlite_appearance_repository.dart';
import 'package:adaptive_workout/features/home/workout_home_page.dart';
import 'package:adaptive_workout/features/program/program_logging_page.dart';
import 'package:adaptive_workout/features/program/program_page.dart';
import 'package:adaptive_workout/features/settings/appearance_controller.dart';
import 'package:adaptive_workout/features/settings/appearance_page.dart';
import 'package:adaptive_workout/features/setup/training_setup_page.dart';
import 'package:adaptive_workout/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:sqflite/sqflite.dart';

import '../test/support/fake_appearance_repository.dart';
import '../test/support/fake_program_log_repository.dart';
import '../test/support/training_setup_fixture.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('appearance persists across native database reopen', (_) async {
    const path = 'appearance_test_fixture.sqlite';
    await deleteDatabase(path);
    var repo = SqliteAppearanceRepository(path: path);
    expect(await repo.load(), AppAppearance.system);
    for (final value in AppAppearance.values) {
      await repo.save(value);
      await repo.close();
      repo = SqliteAppearanceRepository(path: path);
      expect(await repo.load(), value);
    }
    await repo.close();
    await deleteDatabase(path);
  });

  testWidgets('light and dark UI renders on iPhone using isolated records', (
    tester,
  ) async {
    Future<void> capture(String name) async {
      if (!const bool.fromEnvironment('CAPTURE_UI')) return;
      final bytes = await binding.takeScreenshot(name);
      await File('${Directory.systemTemp.path}/ui-review-$name.png')
          .writeAsBytes(bytes);
    }

    for (final value in [AppAppearance.light, AppAppearance.dark]) {
      final repository = FakeAppearanceRepository()..stored = value;
      final appearance = AppearanceController(repository);
      await appearance.load();
      Future<void> show(Widget? home, String name) async {
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(
          AdaptiveWorkoutApp(appearance: appearance, home: home),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await capture('$name-${value.name}');
      }

      await show(
        WorkoutHomePage(workoutRepository: FakeProgramLogRepository()),
        'workout',
      );
      await tester.tap(find.byKey(const Key('tab_settings')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await capture('settings-${value.name}');
      await show(const AppearancePage(), 'appearance');
      await show(const ProgramPage(), 'program');
      await show(
        TrainingSetupPage(repository: MemoryTrainingSetupRepository()),
        'setup',
      );
      final logs = FakeProgramLogRepository();
      await show(ProgramLoggingPage(repository: logs), 'log');
      await tester.scrollUntilVisible(find.text('Start Monday'), 200);
      await tester.tap(find.text('Start Monday'));
      await tester.pumpAndSettle();
      await capture('session-${value.name}');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      appearance.dispose();
    }
  });
}
