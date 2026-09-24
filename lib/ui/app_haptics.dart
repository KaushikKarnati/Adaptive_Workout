import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Presentation feedback only. It must never decide or delay a workout action.
abstract interface class HapticsDriver {
  bool get supported;
  Future<bool> loadEnabled();
  Future<void> saveEnabled(bool enabled);
  Future<void> play(String kind);
}

class PlatformHapticsDriver implements HapticsDriver {
  const PlatformHapticsDriver();
  static const channel = MethodChannel('adaptive_workout/haptics');

  @override
  bool get supported => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
  @override
  Future<bool> loadEnabled() async =>
      await channel.invokeMethod<bool>('isEnabled') ?? false;
  @override
  Future<void> saveEnabled(bool enabled) =>
      channel.invokeMethod<void>('setEnabled', enabled);
  @override
  Future<void> play(String kind) => channel.invokeMethod<void>('play', kind);
}

class AppHaptics extends ChangeNotifier {
  AppHaptics({HapticsDriver? driver})
    : _driver = driver ?? const PlatformHapticsDriver();
  final HapticsDriver _driver;
  static final _silent = AppHaptics();
  bool enabled = false;
  bool available = false;
  bool loaded = false;
  bool busy = false;
  String? preferenceError;
  bool _disposed = false;

  static AppHaptics of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppHapticsScope>()?.notifier ??
      _silent;

  Future<void> load() async {
    if (busy || _disposed) return;
    busy = true;
    _changed();
    try {
      if (_driver.supported) {
        enabled = await _driver.loadEnabled();
        available = true;
      }
      preferenceError = null;
    } catch (_) {
      available = false;
      preferenceError = 'Haptic feedback could not be loaded. Try again.';
    } finally {
      loaded = true;
      busy = false;
      _changed();
    }
  }

  Future<bool> setEnabled(bool value) async {
    if (busy || !available || _disposed || value == enabled) return false;
    busy = true;
    preferenceError = null;
    _changed();
    try {
      await _driver.saveEnabled(value);
      enabled = value;
      return true;
    } catch (_) {
      preferenceError = 'Your haptic preference could not be saved. Try again.';
      return false;
    } finally {
      busy = false;
      _changed();
    }
  }

  void selection() => _play('selection');
  void impact() => _play('impact');
  void success() => _play('success');
  void warning() => _play('warning');
  void error() => _play('error');

  void _play(String kind) {
    if (_disposed || !available || !enabled || busy) return;
    unawaited(_playSafely(kind));
  }

  Future<void> _playSafely(String kind) async {
    try {
      await _driver.play(kind);
    } catch (_) {
      // A device may decline feedback. Never fail the user's actual action.
    }
  }

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}

class AppHapticsScope extends InheritedNotifier<AppHaptics> {
  const AppHapticsScope({
    super.key,
    required AppHaptics haptics,
    required super.child,
  }) : super(notifier: haptics);
}
