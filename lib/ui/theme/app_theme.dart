import 'package:flutter/material.dart';
import '../../services/settings_service.dart';
import 'design_tokens.dart';

class AppTheme {
  static ThemeData darkTheme(AppSettings settings) {
    final cs = ColorScheme.fromSeed(
      seedColor: settings.accentColor,
      brightness: Brightness.dark,
      surface: settings.scaffoldBgColor,
    );
    return _buildTheme(cs, settings);
  }

  static ThemeData lightTheme(AppSettings settings) {
    final cs = ColorScheme.fromSeed(
      seedColor: settings.accentColor,
      brightness: Brightness.light,
      surface: settings.scaffoldBgColor,
    );
    return _buildTheme(cs, settings);
  }

  static ThemeData highContrastTheme(AppSettings settings) {
    const cs = ColorScheme.highContrastDark(
      primary: Color(0xFF00E5FF),
      onPrimary: Color(0xFF000000),
      secondary: Color(0xFFFFF176),
      onSecondary: Color(0xFF000000),
      surface: Color(0xFF000000),
      onSurface: Color(0xFFFFFFFF),
      error: Color(0xFFFF5252),
      onError: Color(0xFF000000),
    );
    return _buildTheme(cs, settings, highContrast: true);
  }

  static bool _isLight(Color c) =>
      c.r * 0.299 + c.g * 0.587 + c.b * 0.114 > 128;

  static ThemeData _buildTheme(
    ColorScheme cs,
    AppSettings s, {
    bool highContrast = false,
  }) {
    final surface = s.scaffoldBgColor.withValues(alpha: s.backgroundOpacity);
    final surfaceC = highContrast
        ? const Color(0xFF1A1A1A)
        : s.surfaceColor.withValues(alpha: s.surfaceOpacity);
    final surfaceIsLight = !highContrast && _isLight(surfaceC);
    final tintAlpha = s.themeTintOpacity;
    final onSurface = highContrast
        ? const Color(0xFFFFFFFF)
        : (surfaceIsLight ? const Color(0xFF1E293B) : DesignColors.textPrimary);
    final onSurfaceVariant = highContrast
        ? const Color(0xFFE0E0E0)
        : cs.primary.withValues(alpha: tintAlpha);
    final muted = highContrast
        ? const Color(0xFFBDBDBD)
        : cs.primary.withValues(alpha: tintAlpha * 0.7);
    final divider = highContrast
        ? const Color(0xFF444444)
        : (surfaceIsLight ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B));
    final inputBg = highContrast ? const Color(0xFF1A1A1A) : surfaceC;
    final br = s.effectiveBorderRadius;
    final iconSz = s.iconSize.toDouble();
    final fontSize = s.editorFontSize;

    return ThemeData(
      brightness: s.isDarkMode ? Brightness.dark : Brightness.light,
      colorScheme: cs.copyWith(onSurfaceVariant: onSurfaceVariant),
      scaffoldBackgroundColor: surface,
      visualDensity: s.effectiveVisualDensity,
      hintColor: cs.primary.withValues(alpha: tintAlpha),
      appBarTheme: AppBarTheme(
        backgroundColor: surfaceC,
        foregroundColor: onSurface,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: surfaceC,
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
      iconTheme: IconThemeData(
        color: cs.primary.withValues(alpha: tintAlpha),
        size: iconSz,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(br)),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surfaceC,
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
        iconColor: cs.primary,
        selectedColor: cs.primary,
        selectedTileColor: cs.primary.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(br)),
        visualDensity: s.effectiveVisualDensity,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return cs.primary;
          return null;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return cs.primary.withValues(alpha: 0.5);
          }
          return null;
        }),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return cs.primary;
          return Colors.transparent;
        }),
        checkColor: WidgetStatePropertyAll(cs.onPrimary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(br * 0.5),
        ),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return cs.primary;
          return null;
        }),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: cs.primary,
        thumbColor: cs.primary,
        inactiveTrackColor: cs.primary.withValues(alpha: 0.3),
        overlayColor: cs.primary.withValues(alpha: 0.12),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: cs.primary,
        linearTrackColor: cs.primary.withValues(alpha: 0.2),
        circularTrackColor: cs.primary.withValues(alpha: 0.2),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: cs.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(br),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          textStyle: TextStyle(
            inherit: false,
            fontWeight: FontWeight.w500,
            fontSize: fontSize - 1,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
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
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return cs.primary;
            return surfaceC;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.selected)) return cs.onPrimary;
            return onSurfaceVariant;
          }),
          side: WidgetStatePropertyAll(BorderSide(color: divider)),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(br)),
          ),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: cs.primary,
        unselectedLabelColor: muted,
        indicatorColor: cs.primary,
        indicatorSize: TabBarIndicatorSize.label,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        selectedItemColor: cs.primary,
        unselectedItemColor: muted,
      ),
      navigationRailTheme: NavigationRailThemeData(
        selectedIconTheme: IconThemeData(color: cs.primary, size: iconSz),
        unselectedIconTheme: IconThemeData(color: muted, size: iconSz),
        selectedLabelTextStyle: TextStyle(
          color: cs.primary,
          fontWeight: FontWeight.w600,
          fontSize: fontSize - 2,
        ),
        unselectedLabelTextStyle: TextStyle(
          color: muted,
          fontSize: fontSize - 2,
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: surfaceC,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(br)),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: onSurface,
          borderRadius: BorderRadius.circular(br * 0.5),
        ),
        textStyle: TextStyle(color: surface, fontSize: fontSize - 2),
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
