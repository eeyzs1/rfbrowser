import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData darkTheme({Color seed = const Color(0xFF0EA5E9)}) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.dark,
      surface: const Color(0xFF0F172A),
    );
    return _buildTheme(colorScheme, Brightness.dark);
  }

  static ThemeData lightTheme({Color seed = const Color(0xFF0EA5E9)}) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.light,
      surface: const Color(0xFFFAFCFF),
    );
    return _buildTheme(colorScheme, Brightness.light);
  }

  static ThemeData _buildTheme(ColorScheme cs, Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF0F172A) : const Color(0xFFFAFCFF);
    final surfaceContainer = isDark ? const Color(0xFF1E293B) : Colors.white;
    final onSurface = isDark
        ? const Color(0xFFE2E8F0)
        : const Color(0xFF1E293B);
    final onSurfaceVariant = isDark
        ? const Color(0xFFCBD5E1)
        : const Color(0xFF475569);
    final muted = isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8);
    final divider = isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
    final inputBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);

    return ThemeData(
      brightness: brightness,
      colorScheme: cs,
      scaffoldBackgroundColor: surface,
      appBarTheme: AppBarTheme(
        backgroundColor: surfaceContainer,
        foregroundColor: onSurface,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: surfaceContainer,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      dividerTheme: DividerThemeData(color: divider, thickness: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputBg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: cs.primary, width: 1),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        hintStyle: TextStyle(color: muted),
      ),
      textTheme: TextTheme(
        headlineLarge: TextStyle(
          color: onSurface,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
        headlineMedium: TextStyle(
          color: onSurface,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
        ),
        titleMedium: TextStyle(color: onSurface, fontWeight: FontWeight.w500),
        bodyLarge: TextStyle(color: onSurface, height: 1.6),
        bodyMedium: TextStyle(color: onSurfaceVariant, height: 1.5),
        bodySmall: TextStyle(color: muted, height: 1.4),
        labelSmall: TextStyle(
          color: muted,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.3,
        ),
      ),
      iconTheme: IconThemeData(color: muted, size: 18),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surfaceContainer,
        contentTextStyle: TextStyle(color: onSurface),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        behavior: SnackBarBehavior.floating,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: cs.primary,
          foregroundColor: cs.onPrimary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: cs.primary,
          side: BorderSide(color: divider),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        ),
      ),
    );
  }
}
