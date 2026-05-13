import 'package:flutter/material.dart';

class DesignColors {
  DesignColors._();

  static const Color brandPrimary = Color(0xFF6366F1);
  static const Color brandPrimaryLight = Color(0xFF818CF8);
  static const Color brandPrimaryDark = Color(0xFF4F46E5);
  static const Color brandSecondary = Color(0xFF10B981);
  static const Color brandSecondaryLight = Color(0xFF34D399);

  static const Color sceneCaptureBg = Color(0xFF0F172A);
  static const Color sceneThinkBg = Color(0xFF1A1A2E);
  static const Color sceneConnectBg = Color(0xFF0D1117);

  static const Color semanticSuccess = Color(0xFF10B981);
  static const Color semanticWarning = Color(0xFFF59E0B);
  static const Color semanticError = Color(0xFFEF4444);
  static const Color semanticInfo = Color(0xFF3B82F6);

  static const Color textPrimary = Color(0xFFE2E8F0);
  static const Color textSecondary = Color(0xFFCBD5E1);
  static const Color textMuted = Color(0xFF64748B);
  static const Color textInverse = Color(0xFF0F172A);

  static const Color primarySubtle = Color(0x146366F1);
  static const Color primaryMuted = Color(0x266366F1);
  static const Color primaryHover = Color(0x0D6366F1);

  static const Color darkSurfaceText = Color(0xFFF1F5F9);
  static const Color darkSurfaceTextSecondary = Color(0xFF94A3B8);
  static const Color lightSurfaceText = Color(0xFF1E293B);
  static const Color lightSurfaceTextSecondary = Color(0xFF475569);
}

class DesignSpacing {
  DesignSpacing._();

  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 24.0;
  static const double xxl = 32.0;
}

class DesignRadius {
  DesignRadius._();

  static const double sm = 6.0;
  static const double md = 8.0;
  static const double lg = 12.0;
  static const double xl = 16.0;
  static const double full = 999.0;
}

class DesignTypography {
  DesignTypography._();

  static const double displaySize = 36.0;
  static const double headlineSize = 30.0;
  static const double titleSize = 24.0;
  static const double subtitleSize = 20.0;
  static const double bodySize = 16.0;
  static const double labelSize = 14.0;
  static const double captionSize = 12.0;
  static const double codeSize = 13.0;
  static const double bodyLineHeight = 1.6;
  static const double maxContentWidth = 720.0;
}

class DesignDuration {
  DesignDuration._();

  static const Duration sceneTransition = Duration(milliseconds: 300);
  static const Duration panelSlide = Duration(milliseconds: 200);
  static const Duration aiFloatExpand = Duration(milliseconds: 250);
  static const Duration aiFloatCollapse = Duration(milliseconds: 150);
  static const Duration clipSuccess = Duration(milliseconds: 200);
  static const Duration toastShow = Duration(milliseconds: 300);
  static const Duration toastHide = Duration(milliseconds: 200);
  static const Duration saveIndicator = Duration(milliseconds: 1500);
  static const Duration staggerItem = Duration(milliseconds: 40);
}

class DesignShadow {
  DesignShadow._();

  static const BoxShadow sm = BoxShadow(
    color: Color(0x1A000000),
    offset: Offset(0, 1),
    blurRadius: 4,
  );
  static const BoxShadow md = BoxShadow(
    color: Color(0x26000000),
    offset: Offset(0, 4),
    blurRadius: 12,
  );
  static const BoxShadow lg = BoxShadow(
    color: Color(0x33000000),
    offset: Offset(0, 8),
    blurRadius: 24,
  );
  static const BoxShadow dialog = BoxShadow(
    color: Color(0x40000000),
    offset: Offset(0, 16),
    blurRadius: 48,
  );
}

class DesignZIndex {
  DesignZIndex._();

  static const int base = 0;
  static const int panel = 10;
  static const int overlay = 20;
  static const int commandBar = 40;
  static const int dialog = 100;
  static const int toast = 1000;
}

class DesignTouchTarget {
  DesignTouchTarget._();

  static const double minSize = 44.0;
  static const double iconButtonSize = 44.0;
  static const double panelCollapseWidth = 32.0;
}
