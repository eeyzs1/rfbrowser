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

  static const double displaySize = 28.0;
  static const double headingSize = 20.0;
  static const double bodySize = 14.0;
  static const double codeSize = 13.0;
  static const double bodyLineHeight = 1.6;
}

class DesignDuration {
  DesignDuration._();

  static const Duration sceneTransition = Duration(milliseconds: 300);
  static const Duration panelSlide = Duration(milliseconds: 200);
  static const Duration aiFloatExpand = Duration(milliseconds: 250);
  static const Duration clipSuccess = Duration(milliseconds: 200);
  static const Duration toastShow = Duration(milliseconds: 300);
  static const Duration toastHide = Duration(milliseconds: 200);
}

class DesignShadow {
  DesignShadow._();

  static const String float = '0 8px 32px rgba(0,0,0,0.3)';
  static const String dialog = '0 16px 48px rgba(0,0,0,0.4)';
  static const String card = '0 2px 8px rgba(0,0,0,0.15)';
}
