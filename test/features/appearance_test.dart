import 'dart:async';

import 'package:adaptive_workout/application/appearance_preferences.dart';
import 'package:adaptive_workout/features/settings/appearance_controller.dart';
import 'package:adaptive_workout/features/settings/appearance_page.dart';
import 'package:adaptive_workout/main.dart';
import 'package:adaptive_workout/ui/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_appearance_repository.dart';

void main() {
  test('custom type sizes preserve the iOS system font', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    final base = ThemeData().textTheme;
    final actual = AppTheme.build(Brightness.light).textTheme;
    expect(actual.bodyLarge!.fontFamily, base.bodyLarge!.fontFamily);
    expect(actual.displaySmall!.fontFamily, base.displaySmall!.fontFamily);
    expect(actual.bodyLarge!.fontFamily, isNotNull);
  });

  test('new preference follows system and saved preference reloads', () async {
    final repo = FakeAppearanceRepository();
    final first = AppearanceController(repo);
    await first.load();
    expect(first.themeMode, ThemeMode.system);
    await first.select(AppAppearance.dark);
    final restored = AppearanceController(repo);
    await restored.load();
    expect(restored.themeMode, ThemeMode.dark);
    first.dispose();
    restored.dispose();
  });

  test('failed read and save keep current mode and support retry', () async {
    final repo = FakeAppearanceRepository()..failLoad = true;
    final controller = AppearanceController(repo);
    await controller.load();
    expect(controller.preference, AppAppearance.system);
    expect(controller.error, isNotNull);
    repo.failLoad = false;
    await controller.load();
    expect(controller.error, isNull);
    repo.failSave = true;
    await controller.select(AppAppearance.dark);
    expect(controller.preference, AppAppearance.system);
    expect(controller.error, isNotNull);
    repo.failSave = false;
    await controller.select(AppAppearance.dark);
    expect(controller.preference, AppAppearance.dark);
    expect(controller.error, isNull);
    controller.dispose();
  });

  test(
    'preference changes only after save and concurrent taps are ignored',
    () async {
      final repo = _PendingRepository();
      final controller = AppearanceController(repo);
      await controller.load();
      final saving = controller.select(AppAppearance.dark);
      expect(controller.busy, isTrue);
      expect(controller.preference, AppAppearance.system);
      await controller.select(AppAppearance.light);
      expect(repo.saves, 1);
      repo.pending.complete();
      await saving;
      expect(controller.preference, AppAppearance.dark);
      expect(controller.busy, isFalse);
      controller.dispose();
    },
  );

  testWidgets(
    'automatic follows system changes and explicit choices override it',
    (tester) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      final controller = AppearanceController(FakeAppearanceRepository());
      await controller.load();
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        AdaptiveWorkoutApp(
          appearance: controller,
          home: const AppearancePage(),
        ),
      );
      Brightness brightness() =>
          Theme.of(tester.element(find.byType(AppearancePage))).brightness;
      expect(brightness(), Brightness.light);
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      await tester.pumpAndSettle();
      expect(brightness(), Brightness.dark);
      await tester.tap(find.byKey(const Key('appearance_light')));
      await tester.pumpAndSettle();
      expect(brightness(), Brightness.light);
      await tester.tap(find.byKey(const Key('appearance_dark')));
      await tester.pumpAndSettle();
      expect(brightness(), Brightness.dark);
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      await tester.pumpAndSettle();
      expect(brightness(), Brightness.dark);
      await tester.tap(find.byKey(const Key('appearance_system')));
      await tester.pumpAndSettle();
      expect(brightness(), Brightness.light);
    },
  );

  for (final appearance in [AppAppearance.light, AppAppearance.dark]) {
    testWidgets(
      'appearance remains accessible on small phone with large text: ${appearance.name}',
      (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        final repo = FakeAppearanceRepository()..stored = appearance;
        final controller = AppearanceController(repo);
        await controller.load();
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          AdaptiveWorkoutApp(
            appearance: controller,
            home: const AppearancePage(),
          ),
        );
        await tester.scrollUntilVisible(
          find.byKey(const Key('appearance_dark')),
          150,
        );
        expect(
          tester.getSize(find.byKey(const Key('appearance_dark'))).height,
          greaterThanOrEqualTo(44),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final brightness in Brightness.values) {
    test(
      'semantic text and action colors meet 4.5:1 contrast in ${brightness.name}',
      () {
        final theme = AppTheme.build(brightness);
        final colors = theme.colorScheme;
        for (final pair in [
          (colors.onSurface, colors.surface),
          (colors.onSurfaceVariant, colors.surface),
          (colors.onSurfaceVariant, colors.surfaceContainerLow),
          (colors.onSurfaceVariant, theme.scaffoldBackgroundColor),
          (colors.primary, colors.surface),
          (colors.onPrimary, colors.primary),
          (colors.onPrimaryContainer, colors.primaryContainer),
          (colors.onErrorContainer, colors.errorContainer),
        ]) {
          final a = pair.$1.computeLuminance(), b = pair.$2.computeLuminance();
          final ratio = a > b ? (a + .05) / (b + .05) : (b + .05) / (a + .05);
          expect(
            ratio,
            greaterThanOrEqualTo(4.5),
            reason: '$pair contrast: $ratio',
          );
        }
      },
    );
  }
}

class _PendingRepository extends FakeAppearanceRepository {
  final pending = Completer<void>();
  int saves = 0;
  @override
  Future<void> save(AppAppearance appearance) async {
    saves++;
    await pending.future;
    await super.save(appearance);
  }
}
