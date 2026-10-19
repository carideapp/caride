import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Accessibility contrast helpers for the Liquid Glass design system.
///
/// Use these to verify minimum contrast ratios when compositing
/// translucent glass surfaces over arbitrary backgrounds.
abstract final class AppContrast {
  /// WCAG AA minimum contrast ratio for normal text.
  static const double aa = 4.5;

  /// WCAG AA minimum contrast ratio for large text (≥18 pt or ≥14 pt bold).
  static const double aaLarge = 3.0;

  /// WCAG AAA minimum contrast ratio.
  static const double aaa = 7.0;

  /// Minimum touch-target size (logical pixels) per WCAG.
  static const double minTouchTarget = 48.0;

  /// Recommended touch-target size for comfortable tapping.
  static const double comfortableTouchTarget = 56.0;

  /// Returns `true` if [foreground] on [background] meets WCAG AA (4.5:1).
  static bool passesAa(Color foreground, Color background) {
    return _contrastRatio(foreground, background) >= aa;
  }

  /// Returns `true` if [foreground] on [background] meets WCAG AA for
  /// large text (3:1).
  static bool passesAaLarge(Color foreground, Color background) {
    return _contrastRatio(foreground, background) >= aaLarge;
  }

  /// Returns `true` if [foreground] on [background] meets WCAG AAA (7:1).
  static bool passesAaa(Color foreground, Color background) {
    return _contrastRatio(foreground, background) >= aaa;
  }

  /// Calculates the WCAG 2.1 contrast ratio between two colours.
  static double _contrastRatio(Color a, Color b) {
    final la = _relativeLuminance(a);
    final lb = _relativeLuminance(b);
    final lighter = math.max(la, lb);
    final darker = math.min(la, lb);
    return (lighter + 0.05) / (darker + 0.05);
  }

  static double _relativeLuminance(Color c) {
    double linearize(int channel) {
      final s = channel / 255.0;
      return s <= 0.03928 ? s / 12.92 : math.pow((s + 0.055) / 1.055, 2.4).toDouble();
    }

    return 0.2126 * linearize((c.r * 255.0).round().clamp(0, 255)) +
        0.7152 * linearize((c.g * 255.0).round().clamp(0, 255)) +
        0.0722 * linearize((c.b * 255.0).round().clamp(0, 255));
  }
}
