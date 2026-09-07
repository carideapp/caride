import 'dart:ui';

import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_radius.dart';

/// Glass surface constants and builders for the Liquid Glass design system.
///
/// Provides blur sigma values, tint opacities, and helper methods
/// to construct consistent glass decorations across the app.
abstract final class AppGlass {
  // ── Blur sigma values ──────────────────────────────────────────────────
  static const double blurLight = 8.0;
  static const double blurMedium = 16.0;
  static const double blurHeavy = 24.0;
  static const double blurUltra = 40.0;

  // ── Tint opacities ────────────────────────────────────────────────────
  static const double tintOpacityDark = 0.12;
  static const double tintOpacityLight = 0.72;
  static const double borderOpacityDark = 0.15;
  static const double borderOpacityLight = 0.12;

  // ── Border widths ─────────────────────────────────────────────────────
  static const double borderThin = 0.5;
  static const double borderNormal = 1.0;
  static const double borderThick = 1.5;

  /// Creates a glass-style [BoxDecoration] that should be paired with a
  /// [BackdropFilter] for the blur effect.
  ///
  /// ```dart
  /// ClipRRect(
  ///   borderRadius: BorderRadius.circular(AppRadius.lg),
  ///   child: BackdropFilter(
  ///     filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
  ///     child: Container(
  ///       decoration: AppGlass.decoration(isDark: true),
  ///       child: content,
  ///     ),
  ///   ),
  /// );
  /// ```
  static BoxDecoration decoration({
    required bool isDark,
    double radius = AppRadius.lg,
    double blurSigma = blurMedium,
    Color? tintOverride,
    double borderWidth = borderThin,
  }) {
    final bg = tintOverride ??
        (isDark ? AppColors.glassBackgroundDark : AppColors.glassBackgroundLight);
    final border =
        isDark ? AppColors.glassBorderDark : AppColors.glassBorderLight;

    return BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: border, width: borderWidth),
    );
  }

  /// An [ImageFilter] for the standard glass blur.
  static ImageFilter blur([double sigma = blurMedium]) =>
      ImageFilter.blur(sigmaX: sigma, sigmaY: sigma);

  /// A navigation-bar / sticky-header glass decoration.
  static BoxDecoration navBarDecoration({required bool isDark}) {
    return BoxDecoration(
      color: isDark
          ? AppColors.darkBackground.withValues(alpha: 0.8)
          : AppColors.lightBackground.withValues(alpha: 0.85),
      border: Border(
        top: BorderSide(
          color: isDark ? AppColors.glassBorderDark : AppColors.glassBorderLight,
          width: borderThin,
        ),
      ),
    );
  }

  /// Bottom-sheet glass decoration with rounded top corners.
  static BoxDecoration sheetDecoration({required bool isDark}) {
    return BoxDecoration(
      color: isDark
          ? AppColors.darkSurfaceRaised.withValues(alpha: 0.92)
          : AppColors.lightSurface.withValues(alpha: 0.95),
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(AppRadius.xxl),
      ),
      border: Border(
        top: BorderSide(
          color: isDark ? AppColors.glassBorderDark : AppColors.glassBorderLight,
          width: borderThin,
        ),
      ),
    );
  }
}
