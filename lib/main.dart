import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

import 'features/practice/practice_page.dart';

void main() => runApp(const AdaptiveWorkoutApp());

class AdaptiveWorkoutApp extends StatelessWidget {
  const AdaptiveWorkoutApp({super.key, this.home});

  final Widget? home;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Adaptive Workout',
    debugShowCheckedModeBanner: false,
    themeMode: ThemeMode.system,
    theme: _appTheme(Brightness.light),
    darkTheme: _appTheme(Brightness.dark),
    home: home ?? const PracticeBootstrap(),
  );

  ThemeData _appTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final background = isDark
        ? const Color(0xFF090D10)
        : const Color(0xFFF2F2F7);
    final surface = isDark ? const Color(0xFF141A1F) : Colors.white;
    final accent = isDark ? const Color(0xFFB8F36B) : const Color(0xFF477A16);
    final colors =
        ColorScheme.fromSeed(
          seedColor: accent,
          brightness: brightness,
          surface: surface,
        ).copyWith(
          primary: accent,
          onPrimary: isDark ? const Color(0xFF122000) : Colors.white,
          surface: surface,
          onSurface: isDark ? const Color(0xFFF4F7F2) : const Color(0xFF171A1C),
          outline: isDark ? const Color(0xFF566169) : const Color(0xFF74777A),
        );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colors,
      scaffoldBackgroundColor: background,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      textTheme: const TextTheme(
        displaySmall: TextStyle(
          fontSize: 38,
          height: 1.05,
          fontWeight: FontWeight.w800,
          letterSpacing: -1.2,
        ),
        headlineMedium: TextStyle(
          fontSize: 28,
          height: 1.1,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.6,
        ),
        titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
        bodyLarge: TextStyle(fontSize: 17, height: 1.45),
        bodyMedium: TextStyle(fontSize: 15, height: 1.4),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(22)),
          side: BorderSide(
            color: isDark ? const Color(0xFF303940) : const Color(0xFFD5D8DB),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
    );
  }
}
