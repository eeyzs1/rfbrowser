import 'package:flutter/material.dart';
import '../../services/settings_service.dart';

class AppTheme {
  static ThemeData darkTheme(AppSettings settings) {
    final cs = ColorScheme.fromSeed(
      seedColor: settings.accentColor,
      brightness: Brightness.dark,
      surface: const Color(0xFF0F172A),
    );
    return _buildTheme(cs, Brightness.dark, settings);
  }

  static ThemeData lightTheme(AppSettings settings) {
    final cs = ColorScheme.fromSeed(
      seedColor: settings.accentColor,
      brightness: Brightness.light,
      surface: const Color(0xFFFAFCFF),
    );
    return _buildTheme(cs, Brightness.light, settings);
  }

  static ThemeData _buildTheme(
    ColorScheme cs,
    Brightness brightness,
    AppSettings s,
  ) {
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
    final br = s.effectiveBorderRadius;
    final iconSz = s.iconSize.toDouble();
    final fontSize = s.editorFontSize;

    return ThemeData(
      brightness: brightness,
      colorScheme: cs,
      scaffoldBackgroundColor: surface,
      visualDensity: s.effectiveVisualDensity,
      appBarTheme: AppBarTheme(
        backgroundColor: surfaceContainer,
        foregroundColor: onSurface,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: surfaceContainer,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(br)),
      ),
      dividerTheme: DividerThemeData(color: divider, thickness: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputBg,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(br),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(br),
          borderSide: BorderSide(color: cs.primary, width: 1),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        hintStyle: TextStyle(color: muted, fontSize: fontSize - 2),
      ),
      textTheme: TextTheme(
        headlineLarge: TextStyle(
          color: onSurface,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
          fontSize: fontSize * 2,
        ),
        headlineMedium: TextStyle(
          color: onSurface,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
          fontSize: fontSize * 1.5,
        ),
        titleMedium: TextStyle(
          color: onSurface,
          fontWeight: FontWeight.w500,
          fontSize: fontSize + 2,
        ),
        bodyLarge: TextStyle(
          color: onSurface,
          height: 1.6,
          fontSize: fontSize + 1,
        ),
        bodyMedium: TextStyle(
          color: onSurfaceVariant,
          height: 1.5,
          fontSize: fontSize,
        ),
        bodySmall: TextStyle(color: muted, height: 1.4, fontSize: fontSize - 2),
        labelSmall: TextStyle(
          color: muted,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.3,
          fontSize: fontSize - 3,
        ),
      ),
      iconTheme: IconThemeData(color: muted, size: iconSz),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(br)),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surfaceContainer,
        contentTextStyle: TextStyle(color: onSurface),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(br)),
        behavior: SnackBarBehavior.floating,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: cs.primary,
          foregroundColor: cs.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(br),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          textStyle: TextStyle(
            inherit: false,
            fontWeight: FontWeight.w600,
            fontSize: fontSize - 1,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: cs.primary,
          side: BorderSide(color: divider),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(br),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          textStyle: TextStyle(
            inherit: false,
            fontWeight: FontWeight.w500,
            fontSize: fontSize - 1,
          ),
        ),
      ),
      listTileTheme: ListTileThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(br)),
        visualDensity: s.effectiveVisualDensity,
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(br + 4),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(br)),
      ),
    );
  }
}
