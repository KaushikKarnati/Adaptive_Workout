import 'package:adaptive_workout/application/appearance_preferences.dart';

class FakeAppearanceRepository implements AppearancePreferencesRepository {
  AppAppearance stored = AppAppearance.system;
  bool failLoad = false;
  bool failSave = false;

  @override
  Future<AppAppearance> load() async {
    if (failLoad) throw StateError('unavailable');
    return stored;
  }

  @override
  Future<void> save(AppAppearance appearance) async {
    if (failSave) throw StateError('unavailable');
    stored = appearance;
  }

  @override
  Future<void> close() async {}
}
