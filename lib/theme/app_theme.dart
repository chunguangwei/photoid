import 'package:flutter/material.dart';

/// Shared content surfaces; glass is reserved for navigation/controls.
ThemeData photoIdTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF2868CC),
    brightness: brightness,
  ).copyWith(
    primary: dark ? const Color(0xFF9EC5FF) : const Color(0xFF215FBF),
    onPrimary: dark ? const Color(0xFF0B2C58) : Colors.white,
    surface: dark ? const Color(0xFF111A28) : const Color(0xFFF4F7FB),
  );
  final base = ThemeData(colorScheme: scheme, useMaterial3: true);
  final text = base.textTheme.copyWith(
    headlineMedium: base.textTheme.headlineMedium?.copyWith(
        fontSize: 32,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.1,
        height: 1.14),
    titleLarge: base.textTheme.titleLarge
        ?.copyWith(fontWeight: FontWeight.w600, letterSpacing: -0.4),
    titleMedium:
        base.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
  );
  final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(22));
  return base.copyWith(
    scaffoldBackgroundColor: scheme.surface,
    textTheme: text,
    appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: text.titleLarge?.copyWith(color: scheme.onSurface)),
    cardTheme: CardThemeData(
        elevation: 0,
        color: dark ? const Color(0xFF1B2636) : Colors.white,
        margin: EdgeInsets.zero,
        shape: shape.copyWith(
            side: BorderSide(
                color: scheme.outlineVariant.withValues(alpha: 0.35)))),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? const Color(0xFF1B2636) : Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.outlineVariant)),
    ),
    filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
            minimumSize: const Size(48, 52),
            shape: const StadiumBorder(),
            textStyle:
                const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
    outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
            minimumSize: const Size(48, 48),
            shape: const StadiumBorder(),
            textStyle:
                const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.transparent,
      elevation: 0,
      indicatorColor: scheme.primary.withValues(alpha: dark ? 0.2 : 0.10),
      labelTextStyle: WidgetStatePropertyAll(
          text.labelMedium?.copyWith(fontWeight: FontWeight.w600)),
    ),
  );
}
