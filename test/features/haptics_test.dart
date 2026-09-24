import 'package:adaptive_workout/features/settings/appearance_controller.dart';
import 'package:adaptive_workout/features/settings/appearance_page.dart';
import 'package:adaptive_workout/main.dart';
import 'package:adaptive_workout/ui/app_haptics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_appearance_repository.dart';
import '../support/fake_haptics_driver.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'semantic feedback is quiet until loaded and respects saved mute',
    () async {
      final driver = FakeHapticsDriver();
      final haptics = AppHaptics(driver: driver);
      haptics.success();
      expect(driver.events, isEmpty);
      await haptics.load();
      haptics.selection();
      haptics.impact();
      haptics.success();
      haptics.warning();
      haptics.error();
      expect(driver.events, [
        'selection',
        'impact',
        'success',
        'warning',
        'error',
      ]);
      await haptics.setEnabled(false);
      driver.events.clear();
      haptics.selection();
      haptics.success();
      haptics.error();
      expect(driver.events, isEmpty);
      final restored = AppHaptics(driver: driver);
      await restored.load();
      expect(restored.enabled, isFalse);
      restored.warning();
      expect(driver.events, isEmpty);
      haptics.dispose();
      restored.dispose();
    },
  );

  test(
    'unavailable feedback and platform errors never fail actual actions',
    () async {
      final driver = FakeHapticsDriver()..failLoad = true;
      final haptics = AppHaptics(driver: driver);
      await haptics.load();
      expect(haptics.available, isFalse);
      haptics.success();
      expect(driver.events, isEmpty);
      driver.failLoad = false;
      await haptics.load();
      driver.failPlay = true;
      haptics.success();
      await Future<void>.delayed(Duration.zero);
      expect(haptics.enabled, isTrue);
      driver.failSave = true;
      expect(await haptics.setEnabled(false), isFalse);
      expect(haptics.enabled, isTrue);
      expect(haptics.preferenceError, isNotNull);
      driver.failSave = false;
      expect(await haptics.setEnabled(false), isTrue);
      expect(haptics.preferenceError, isNull);
      haptics.dispose();
    },
  );

  test('unsupported devices and disposed services remain silent', () async {
    final driver = FakeHapticsDriver()..supported = false;
    final haptics = AppHaptics(driver: driver);
    await haptics.load();
    expect(haptics.available, isFalse);
    expect(await haptics.setEnabled(true), isFalse);
    haptics.impact();
    expect(driver.events, isEmpty);
    haptics.dispose();
    haptics.error();
    expect(driver.events, isEmpty);
  });

  test(
    'native channel uses semantic UIKit requests and scalar preferences',
    () async {
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(PlatformHapticsDriver.channel, (
            call,
          ) async {
            calls.add(call);
            return call.method == 'isEnabled' ? true : null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(PlatformHapticsDriver.channel, null),
      );
      const driver = PlatformHapticsDriver();
      expect(await driver.loadEnabled(), isTrue);
      await driver.saveEnabled(false);
      await driver.play('success');
      expect(calls.map((c) => c.method), ['isEnabled', 'setEnabled', 'play']);
      expect(calls[1].arguments, isFalse);
      expect(calls[2].arguments, 'success');
    },
  );

  testWidgets(
    'settings persist mute and only changed, saved appearances tick',
    (tester) async {
      final systemHaptics = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'HapticFeedback.vibrate') {
              systemHaptics.add(call);
            }
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null),
      );
      final driver = FakeHapticsDriver();
      final haptics = AppHaptics(driver: driver);
      await haptics.load();
      final repository = FakeAppearanceRepository();
      final appearance = AppearanceController(repository);
      await appearance.load();
      addTearDown(haptics.dispose);
      addTearDown(appearance.dispose);
      await tester.pumpWidget(
        AdaptiveWorkoutApp(
          appearance: appearance,
          haptics: haptics,
          home: const AppearancePage(),
        ),
      );
      expect(driver.events, isEmpty);
      await tester.tap(find.byKey(const Key('appearance_system')));
      await tester.pumpAndSettle();
      expect(driver.events, isEmpty);
      await tester.tap(find.byKey(const Key('appearance_light')));
      await tester.pumpAndSettle();
      expect(driver.events, ['selection']);
      repository.failSave = true;
      await tester.tap(find.byKey(const Key('appearance_dark')));
      await tester.pumpAndSettle();
      expect(driver.events, ['selection', 'error']);
      await tester.scrollUntilVisible(
        find.byKey(const Key('haptic_feedback_toggle')),
        200,
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('haptic_feedback_toggle')),
          matching: find.byType(Switch),
        ),
      );
      await tester.pumpAndSettle();
      expect(haptics.enabled, isFalse);
      expect(driver.storedEnabled, isFalse);
      expect(driver.events, ['selection', 'error']);
      await tester.tap(
        find.descendant(
          of: find.byKey(const Key('haptic_feedback_toggle')),
          matching: find.byType(Switch),
        ),
      );
      await tester.pumpAndSettle();
      expect(haptics.enabled, isTrue);
      expect(driver.events, ['selection', 'error', 'selection']);
      expect(
        systemHaptics,
        isEmpty,
        reason: 'Control must not bypass the app haptic preference.',
      );
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'feedback switch stays reachable with large text on small phone',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final haptics = AppHaptics(driver: FakeHapticsDriver());
      final appearance = AppearanceController(FakeAppearanceRepository());
      await Future.wait([haptics.load(), appearance.load()]);
      addTearDown(haptics.dispose);
      addTearDown(appearance.dispose);
      await tester.pumpWidget(
        AdaptiveWorkoutApp(
          appearance: appearance,
          haptics: haptics,
          home: const AppearancePage(),
        ),
      );
      await tester.scrollUntilVisible(
        find.byKey(const Key('haptic_feedback_toggle')),
        200,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
