/// Appearance is a device preference, separate from workout/profile records.
enum AppAppearance { system, light, dark }

abstract interface class AppearancePreferencesRepository {
  Future<AppAppearance> load();
  Future<void> save(AppAppearance appearance);
  Future<void> close();
}
