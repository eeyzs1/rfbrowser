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
        : (surfaceIsLight
            ? DesignColors.lightSurfaceText
            : DesignColors.darkSurfaceText);
    final onSurfaceVariant = highContrast
        ? const Color(0xFFE0E0E0)
        : (surfaceIsLight
            ? DesignColors.lightSurfaceTextSecondary
            : DesignColors.darkSurfaceTextSecondary);
    final muted = highContrast
        ? const Color(0xFFBDBDBD)
        : (surfaceIsLight
            ? DesignColors.lightSurfaceTextSecondary
            : DesignColors.textMuted);
    final divider = highContrast
        ? const Color(0xFF444444)
        : (surfaceIsLight ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B));
    final inputBg = highContrast ? const Color(0xFF1A1A1A) : surfaceC;
    final br = s.effectiveBorderRadius;
    final iconSz = s.iconSize.toDouble();
    final fs = s.editorFontSize;

    return ThemeData(
      brightness: s.isDarkMode ? Brightness.dark : Brightness.light,
      colorScheme: cs.copyWith(onSurfaceVariant: onSurfaceVariant),
      scaffoldBackgroundColor: surface,
      visualDensity: s.effectiveVisualDensity,
      hintColor: muted,
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
          borderSide: BorderSide(color: cs.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: DesignSpacing.md,
          vertical: DesignSpacing.sm,
        ),
        hintStyle: TextStyle(color: muted, fontSize: fs * 0.875),
      ),
      textTheme: TextTheme(
        headlineLarge: TextStyle(
          color: onSurface,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
          fontSize: fs * 2.25,
        ),
        headlineMedium: TextStyle(
          color: onSurface,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
          fontSize: fs * 1.75,
        ),
        headlineSmall: TextStyle(
          color: onSurface,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
          fontSize: fs * 1.375,
        ),
        titleLarge: TextStyle(
          color: onSurface,
          fontWeight: FontWeight.w600,
          fontSize: fs * 1.25,
        ),
        titleMedium: TextStyle(
          color: onSurface,
          fontWeight: FontWeight.w500,
          fontSize: fs * 1.125,
        ),
        titleSmall: TextStyle(
          color: onSurface,
          fontWeight: FontWeight.w500,
          fontSize: fs,
        ),
        bodyLarge: TextStyle(
          color: onSurface,
          height: 1.6,
          fontSize: fs * 1.0625,
        ),
        bodyMedium: TextStyle(
          color: onSurfaceVariant,
          height: 1.5,
          fontSize: fs,
        ),
        bodySmall: TextStyle(
          color: muted,
          height: 1.4,
          fontSize: fs * 0.875,
        ),
        labelLarge: TextStyle(
          color: onSurface,
          fontWeight: FontWeight.w500,
          fontSize: fs * 0.9375,
        ),
        labelMedium: TextStyle(
          color: onSurfaceVariant,
          fontWeight: FontWeight.w500,
          fontSize: fs * 0.8125,
        ),
        labelSmall: TextStyle(
          color: muted,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.3,
          fontSize: fs * 0.75,
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
          minimumSize: const Size(0, DesignTouchTarget.minSize),
          padding: const EdgeInsets.symmetric(
            horizontal: DesignSpacing.lg,
            vertical: 10,
          ),
          textStyle: TextStyle(
            inherit: false,
            fontWeight: FontWeight.w600,
            fontSize: fs * 0.9375,
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
          minimumSize: const Size(0, DesignTouchTarget.minSize),
          padding: const EdgeInsets.symmetric(
            horizontal: DesignSpacing.lg,
            vertical: 10,
          ),
          textStyle: TextStyle(
            inherit: false,
            fontWeight: FontWeight.w500,
            fontSize: fs * 0.9375,
          ),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: cs.primary,
        selectedColor: cs.primary,
        selectedTileColor: DesignColors.primarySubtle,
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
          minimumSize: const Size(0, DesignTouchTarget.minSize),
          padding: const EdgeInsets.symmetric(
            horizontal: DesignSpacing.md,
            vertical: DesignSpacing.sm,
          ),
          textStyle: TextStyle(
            inherit: false,
            fontWeight: FontWeight.w500,
            fontSize: fs * 0.9375,
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
          minimumSize: const Size(0, DesignTouchTarget.minSize),
          padding: const EdgeInsets.symmetric(
            horizontal: DesignSpacing.lg,
            vertical: 10,
          ),
          textStyle: TextStyle(
            inherit: false,
            fontWeight: FontWeight.w600,
            fontSize: fs * 0.9375,
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
          fontSize: fs * 0.875,
        ),
        unselectedLabelTextStyle: TextStyle(
          color: muted,
          fontSize: fs * 0.875,
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
        textStyle: TextStyle(color: surface, fontSize: fs * 0.875),
        waitDuration: const Duration(milliseconds: 500),
      ),
      dialogTheme: DialogThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(br + 4),
        ),
      ),
      chipTheme: ChipThemeData(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(br)),
      ),
      focusColor: cs.primary.withValues(alpha: 0.12),
      hoverColor: cs.primary.withValues(alpha: 0.08),
      highlightColor: cs.primary.withValues(alpha: 0.12),
      splashColor: cs.primary.withValues(alpha: 0.12),
      splashFactory: InkRipple.splashFactory,
    );
  }
}
