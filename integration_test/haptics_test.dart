import 'package:adaptive_workout/ui/app_haptics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('native haptics accepts semantic cues and persists mute', (
    _,
  ) async {
    const driver = PlatformHapticsDriver();
    expect(driver.supported, isTrue);
    final original = await driver.loadEnabled();
    try {
      await driver.saveEnabled(false);
      expect(await const PlatformHapticsDriver().loadEnabled(), isFalse);
      await driver.play(
        'success',
      ); // Native bridge must safely ignore muted cues.
      await driver.saveEnabled(true);
      expect(await const PlatformHapticsDriver().loadEnabled(), isTrue);
      for (final kind in [
        'selection',
        'impact',
        'success',
        'warning',
        'error',
      ]) {
        await driver.play(kind);
      }
      await expectLater(
        driver.play('unknown'),
        throwsA(isA<PlatformException>()),
      );
      await expectLater(
        PlatformHapticsDriver.channel.invokeMethod<void>('setEnabled', 1),
        throwsA(isA<PlatformException>()),
      );
      expect(await driver.loadEnabled(), isTrue);
    } finally {
      await driver.saveEnabled(original);
    }
  });
}
