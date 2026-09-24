import 'dart:io';
import 'dart:ui' as ui;

import 'package:adaptive_workout/application/appearance_preferences.dart';
import 'package:adaptive_workout/features/home/workout_home_page.dart';
import 'package:adaptive_workout/features/settings/appearance_controller.dart';
import 'package:adaptive_workout/main.dart';
import 'package:adaptive_workout/ui/app_haptics.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_appearance_repository.dart';
import '../support/fake_haptics_driver.dart';
import '../support/fake_program_log_repository.dart';

void main() {
  testWidgets('optional two-screen visual review using isolated records', (
    tester,
  ) async {
    if (!const bool.fromEnvironment('CAPTURE_TWO_SCREEN')) return;
    await tester.runAsync(() async {
      for (final family in [
        'Ahem',
        'Roboto',
        '.SF UI Text',
        '.SF UI Display',
        'CupertinoSystemText',
        'CupertinoSystemDisplay',
      ]) {
        await (FontLoader(family)..addFont(
              File('/System/Library/Fonts/SFNS.ttf')
                  .readAsBytes()
                  .then(ByteData.sublistView),
            ))
            .load();
      }
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
      await (FontLoader('packages/cupertino_icons/CupertinoIcons')..addFont(
            rootBundle.load(
              'packages/cupertino_icons/assets/CupertinoIcons.ttf',
            ),
          ))
          .load();
    });
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final driver = FakeHapticsDriver();
    final haptics = AppHaptics(driver: driver);
    await haptics.load();
    addTearDown(haptics.dispose);
    for (final mode in [AppAppearance.light, AppAppearance.dark]) {
      final appearance = AppearanceController(
        FakeAppearanceRepository()..stored = mode,
      );
      await appearance.load();
      await tester.pumpWidget(const SizedBox());
      final boundaryKey = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundaryKey,
          child: AdaptiveWorkoutApp(
            appearance: appearance,
            haptics: haptics,
            home: WorkoutHomePage(
              workoutRepository: FakeProgramLogRepository(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      Future<void> capture(String screen) async {
        expect(tester.takeException(), isNull);
        final boundary =
            boundaryKey.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final bitmap = await boundary.toImage();
          final bytes = await bitmap.toByteData(format: ui.ImageByteFormat.png);
          final file = File(
            'build/ui-review/two-screen-$screen-${mode.name}.png',
          );
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes!.buffer.asUint8List());
          bitmap.dispose();
        });
      }

      await capture('workout');
      await tester.tap(find.byKey(const Key('tab_settings')));
      await tester.pumpAndSettle();
      await capture('settings');
      await tester.tap(find.text('Appearance & feedback'));
      await tester.pumpAndSettle();
      await capture('appearance');
      await tester.pumpWidget(const SizedBox());
      appearance.dispose();
    }
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
}
