import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rfbrowser/ui/theme/design_tokens.dart';

void main() {
  group('DesignColors', () {
    test('E0-AC1: defines all required color categories', () {
      expect(DesignColors.brandPrimary, isA<Color>());
      expect(DesignColors.brandSecondary, isA<Color>());
      expect(DesignColors.semanticSuccess, isA<Color>());
      expect(DesignColors.semanticError, isA<Color>());
      expect(DesignColors.semanticWarning, isA<Color>());
      expect(DesignColors.semanticInfo, isA<Color>());

      expect(DesignColors.sceneCaptureBg, isA<Color>());
      expect(DesignColors.sceneThinkBg, isA<Color>());
      expect(DesignColors.sceneConnectBg, isA<Color>());

      expect(DesignColors.textPrimary, isA<Color>());
      expect(DesignColors.textSecondary, isA<Color>());
      expect(DesignColors.textMuted, isA<Color>());
      expect(DesignColors.textInverse, isA<Color>());
    });

    test('E0-AC2: brand colors match design spec', () {
      expect(DesignColors.brandPrimary, const Color(0xFF6366F1));
      expect(DesignColors.brandPrimaryLight, const Color(0xFF818CF8));
      expect(DesignColors.brandPrimaryDark, const Color(0xFF4F46E5));
      expect(DesignColors.brandSecondary, const Color(0xFF10B981));
      expect(DesignColors.brandSecondaryLight, const Color(0xFF34D399));
    });

    test('E0-AC2b: semantic colors match design spec', () {
      expect(DesignColors.semanticSuccess, const Color(0xFF10B981));
      expect(DesignColors.semanticWarning, const Color(0xFFF59E0B));
      expect(DesignColors.semanticError, const Color(0xFFEF4444));
      expect(DesignColors.semanticInfo, const Color(0xFF3B82F6));
    });
  });

  group('DesignSpacing', () {
    test('E0-AC1b: spacing tokens are defined as const doubles', () {
      expect(DesignSpacing.xs, 4.0);
      expect(DesignSpacing.sm, 8.0);
      expect(DesignSpacing.md, 12.0);
      expect(DesignSpacing.lg, 16.0);
      expect(DesignSpacing.xl, 24.0);
      expect(DesignSpacing.xxl, 32.0);
    });
  });

  group('DesignRadius', () {
    test('E0-AC1c: radius tokens are defined as const doubles', () {
      expect(DesignRadius.sm, 6.0);
      expect(DesignRadius.md, 8.0);
      expect(DesignRadius.lg, 12.0);
      expect(DesignRadius.xl, 16.0);
      expect(DesignRadius.full, 999.0);
    });
  });

  group('DesignTypography', () {
    test('E0-AC1d: typography tokens are defined', () {
      expect(DesignTypography.displaySize, 28.0);
      expect(DesignTypography.headingSize, 20.0);
      expect(DesignTypography.bodySize, 14.0);
      expect(DesignTypography.codeSize, 13.0);
      expect(DesignTypography.bodyLineHeight, 1.6);
    });
  });

  group('DesignDuration', () {
    test('E0-AC1e: animation duration tokens are defined', () {
      expect(DesignDuration.sceneTransition, const Duration(milliseconds: 300));
      expect(DesignDuration.panelSlide, const Duration(milliseconds: 200));
      expect(DesignDuration.aiFloatExpand, const Duration(milliseconds: 250));
      expect(DesignDuration.clipSuccess, const Duration(milliseconds: 200));
      expect(DesignDuration.toastShow, const Duration(milliseconds: 300));
      expect(DesignDuration.toastHide, const Duration(milliseconds: 200));
    });
  });

  group('DesignShadow', () {
    test('shadow tokens are defined as non-empty strings', () {
      expect(DesignShadow.float, isNotEmpty);
      expect(DesignShadow.dialog, isNotEmpty);
      expect(DesignShadow.card, isNotEmpty);
    });
  });
}
