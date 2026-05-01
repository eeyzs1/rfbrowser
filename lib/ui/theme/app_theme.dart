import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData darkTheme() {
    return ThemeData(
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF6C9FFF),
        secondary: Color(0xFF4ECDC4),
        surface: Color(0xFF1E1E2E),
        onSurface: Color(0xFFCDD6F4),
        error: Color(0xFFF38BA8),
        onPrimary: Color(0xFF1E1E2E),
      ),
      scaffoldBackgroundColor: const Color(0xFF1E1E2E),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF181825),
        foregroundColor: Color(0xFFCDD6F4),
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF313244),
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFF45475A),
        thickness: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF313244),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF6C9FFF)),
        ),
        hintStyle: const TextStyle(color: Color(0xFF6C7086)),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          color: Color(0xFFCDD6F4),
          fontWeight: FontWeight.bold,
        ),
        headlineMedium: TextStyle(
          color: Color(0xFFCDD6F4),
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: TextStyle(color: Color(0xFFCDD6F4)),
        bodyMedium: TextStyle(color: Color(0xFFBAC2DE)),
        bodySmall: TextStyle(color: Color(0xFF6C7086)),
      ),
      iconTheme: const IconThemeData(color: Color(0xFF6C7086)),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: Color(0xFF6C9FFF),
        foregroundColor: Color(0xFF1E1E2E),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF313244),
        contentTextStyle: const TextStyle(color: Color(0xFFCDD6F4)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  static ThemeData lightTheme() {
    return ThemeData(
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        primary: Color(0xFF3B82F6),
        secondary: Color(0xFF10B981),
        surface: Color(0xFFF8FAFC),
        onSurface: Color(0xFF1E293B),
        error: Color(0xFFEF4444),
        onPrimary: Colors.white,
      ),
      scaffoldBackgroundColor: const Color(0xFFF8FAFC),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: Color(0xFF1E293B),
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFFE2E8F0),
        thickness: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF1F5F9),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: Color(0xFF3B82F6)),
        ),
        hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          color: Color(0xFF1E293B),
          fontWeight: FontWeight.bold,
        ),
        headlineMedium: TextStyle(
          color: Color(0xFF1E293B),
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: TextStyle(color: Color(0xFF1E293B)),
        bodyMedium: TextStyle(color: Color(0xFF475569)),
        bodySmall: TextStyle(color: Color(0xFF94A3B8)),
      ),
      iconTheme: const IconThemeData(color: Color(0xFF64748B)),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: Color(0xFF3B82F6),
        foregroundColor: Colors.white,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: Colors.white,
        contentTextStyle: const TextStyle(color: Color(0xFF1E293B)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
