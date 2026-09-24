import 'package:flutter/material.dart';

import 'data/repositories/sqlite_appearance_repository.dart';
import 'features/home/workout_home_page.dart';
import 'features/settings/appearance_controller.dart';
import 'ui/app_theme.dart';
import 'ui/app_haptics.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final appearance = AppearanceController(SqliteAppearanceRepository());
  final haptics = AppHaptics();
  await Future.wait([appearance.load(), haptics.load()]);
  runApp(AdaptiveWorkoutApp(appearance: appearance, haptics: haptics));
}

class AdaptiveWorkoutApp extends StatefulWidget {
  const AdaptiveWorkoutApp({
    super.key,
    this.home,
    this.appearance,
    this.haptics,
  });
  final Widget? home;
  final AppearanceController? appearance;
  final AppHaptics? haptics;

  @override
  State<AdaptiveWorkoutApp> createState() => _AdaptiveWorkoutAppState();
}

class _AdaptiveWorkoutAppState extends State<AdaptiveWorkoutApp> {
  late final AppearanceController _appearance =
      widget.appearance ?? AppearanceController(SqliteAppearanceRepository());

  late final AppHaptics _haptics = widget.haptics ?? AppHaptics();

  @override
  void initState() {
    super.initState();
    if (!_appearance.loaded) _appearance.load();
    if (!_haptics.loaded) _haptics.load();
  }

  @override
  void dispose() {
    if (widget.appearance == null) _appearance.dispose();
    if (widget.haptics == null) _haptics.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AppHapticsScope(
    haptics: _haptics,
    child: AppearanceScope(
      controller: _appearance,
      child: ListenableBuilder(
        listenable: _appearance,
        builder: (context, _) => MaterialApp(
          title: 'Adaptive Workout',
          debugShowCheckedModeBanner: false,
          themeMode: _appearance.themeMode,
          theme: AppTheme.build(Brightness.light),
          darkTheme: AppTheme.build(Brightness.dark),
          themeAnimationDuration: Duration.zero,
          home: widget.home ?? const WorkoutHomePage(),
        ),
      ),
    ),
  );
}
