import 'package:flutter/material.dart';

extension ColorLuminance on Color {
  double get luminance => r * 0.299 + g * 0.587 + b * 0.114;

  bool get isDark => luminance < 0.5;

  Color get contrastText =>
      luminance > 0.5 ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);
}
