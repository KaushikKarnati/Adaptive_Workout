import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Semantic colors and shared controls for current and future screens.
abstract final class AppTheme {
  static ThemeData build(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final background = dark ? const Color(0xFF101114) : const Color(0xFFF5F5F7);
    final surface = dark ? const Color(0xFF1C1D22) : Colors.white;
    final ink = dark ? const Color(0xFFF5F5F7) : const Color(0xFF1A1C20);
    final secondary = dark ? const Color(0xFFABADB8) : const Color(0xFF60636F);
    final accent = dark ? const Color(0xFF91B7FF) : const Color(0xFF245BC1);
    final border = dark ? const Color(0xFF373941) : const Color(0xFFDFE1E7);
    final colors =
        ColorScheme.fromSeed(
          seedColor: accent,
          brightness: brightness,
        ).copyWith(
          primary: accent,
          onPrimary: dark ? const Color(0xFF102343) : Colors.white,
          primaryContainer: dark
              ? const Color(0xFF253550)
              : const Color(0xFFEAF0FC),
          onPrimaryContainer: dark
              ? const Color(0xFFBDD2FF)
              : const Color(0xFF244E95),
          surface: surface,
          onSurface: ink,
          onSurfaceVariant: secondary,
          surfaceContainerLowest: background,
          surfaceContainerLow: dark
              ? const Color(0xFF24262D)
              : const Color(0xFFEBEDF2),
          surfaceContainer: dark
              ? const Color(0xFF292B33)
              : const Color(0xFFE8EBF1),
          surfaceContainerHigh: dark
              ? const Color(0xFF30323B)
              : const Color(0xFFE1E5ED),
          surfaceContainerHighest: dark
              ? const Color(0xFF373A44)
              : const Color(0xFFD9DFEA),
          outline: secondary,
          outlineVariant: border,
          error: dark ? const Color(0xFFFFB4AC) : const Color(0xFFB3261E),
        );
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colors,
      scaffoldBackgroundColor: background,
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
    );
    final text = base.textTheme
        .merge(
          const TextTheme(
            displaySmall: TextStyle(
              fontSize: 34,
              height: 1.12,
              fontWeight: FontWeight.w700,
              letterSpacing: -1,
            ),
            headlineMedium: TextStyle(
              fontSize: 28,
              height: 1.18,
              fontWeight: FontWeight.w700,
              letterSpacing: -.6,
            ),
            headlineSmall: TextStyle(
              fontSize: 24,
              height: 1.2,
              fontWeight: FontWeight.w600,
              letterSpacing: -.4,
            ),
            titleLarge: TextStyle(
              fontSize: 22,
              height: 1.25,
              fontWeight: FontWeight.w600,
              letterSpacing: -.35,
            ),
            titleMedium: TextStyle(
              fontSize: 17,
              height: 1.3,
              fontWeight: FontWeight.w600,
            ),
            bodyLarge: TextStyle(fontSize: 17, height: 1.4),
            bodyMedium: TextStyle(fontSize: 15, height: 1.4),
            bodySmall: TextStyle(fontSize: 13, height: 1.4),
            labelLarge: TextStyle(
              fontSize: 15,
              height: 1.3,
              fontWeight: FontWeight.w600,
            ),
          ),
        )
        .apply(bodyColor: ink, displayColor: ink);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
    );
    return base.copyWith(
      textTheme: text,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
        },
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        titleTextStyle: text.titleMedium,
        systemOverlayStyle: dark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
          shape: shape,
          textStyle: text.titleMedium,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 48),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          shape: shape,
          side: BorderSide(color: border),
          textStyle: text.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(44, 48),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          textStyle: text.labelLarge,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.surfaceContainerLow,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 18,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: accent, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.error),
        ),
        helperMaxLines: 5,
        errorMaxLines: 5,
      ),
      dividerTheme: DividerThemeData(color: border, thickness: .5, space: 1),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        titleTextStyle: text.titleMedium,
        subtitleTextStyle: text.bodyMedium?.copyWith(color: secondary),
        iconColor: secondary,
      ),
      expansionTileTheme: ExpansionTileThemeData(
        tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        shape: const Border(),
        collapsedShape: const Border(),
        textColor: ink,
        collapsedTextColor: ink,
        iconColor: secondary,
        collapsedIconColor: secondary,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
