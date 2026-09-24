import 'dart:async';

import 'package:flutter/material.dart';

import '../../application/appearance_preferences.dart';

class AppearanceController extends ChangeNotifier {
  AppearanceController(this.repository);
  final AppearancePreferencesRepository repository;
  AppAppearance preference = AppAppearance.system;
  bool loaded = false;
  bool busy = false;
  String? error;
  bool _disposed = false;

  ThemeMode get themeMode => switch (preference) {
    AppAppearance.system => ThemeMode.system,
    AppAppearance.light => ThemeMode.light,
    AppAppearance.dark => ThemeMode.dark,
  };

  Future<void> load() async {
    if (busy) return;
    busy = true;
    _changed();
    try {
      preference = await repository.load();
      error = null;
    } catch (_) {
      error = 'Your saved appearance could not be loaded. Try again.';
    } finally {
      loaded = true;
      busy = false;
      _changed();
    }
  }

  Future<void> select(AppAppearance value) async {
    if (busy) return;
    busy = true;
    error = null;
    _changed();
    try {
      await repository.save(value);
      preference = value;
    } catch (_) {
      error = 'Appearance could not be saved. Please try again.';
    } finally {
      busy = false;
      _changed();
    }
  }

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(repository.close());
    super.dispose();
  }
}

class AppearanceScope extends InheritedNotifier<AppearanceController> {
  const AppearanceScope({
    super.key,
    required AppearanceController controller,
    required super.child,
  }) : super(notifier: controller);

  static AppearanceController of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppearanceScope>()!.notifier!;
}
