import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Premium layered shadows for the Liquid Glass design system.
///
/// Each shadow set is a `List<BoxShadow>` so it can be used in
/// `BoxDecoration.boxShadow` directly.
abstract final class AppShadows {
  // ── Dark mode shadows ──────────────────────────────────────────────────

  /// Subtle shadow for cards resting on the dark surface.
  static const List<BoxShadow> cardDark = [
    BoxShadow(
      color: Color(0x40000000),
      blurRadius: 12,
      offset: Offset(0, 4),
      spreadRadius: -2,
    ),
    BoxShadow(
      color: Color(0x1A000000),
      blurRadius: 4,
      offset: Offset(0, 1),
    ),
  ];

  /// Raised shadow for floating elements (FABs, nav bar).
  static const List<BoxShadow> raisedDark = [
    BoxShadow(
      color: Color(0x66000000),
      blurRadius: 24,
      offset: Offset(0, 8),
      spreadRadius: -4,
    ),
    BoxShadow(
      color: Color(0x26000000),
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
  ];

  /// Modal / bottom-sheet shadow.
  static const List<BoxShadow> modalDark = [
    BoxShadow(
      color: Color(0x80000000),
      blurRadius: 40,
      offset: Offset(0, 16),
      spreadRadius: -8,
    ),
  ];

  /// Brand-coloured glow for primary actions.
  static List<BoxShadow> glowDark = [
    BoxShadow(
      color: AppColors.brand.withValues(alpha: 0.35),
      blurRadius: 20,
      offset: const Offset(0, 4),
      spreadRadius: -4,
    ),
    BoxShadow(
      color: AppColors.brand.withValues(alpha: 0.15),
      blurRadius: 40,
      offset: const Offset(0, 8),
      spreadRadius: -8,
    ),
  ];

  // ── Light mode shadows ─────────────────────────────────────────────────

  static const List<BoxShadow> cardLight = [
    BoxShadow(
      color: Color(0x14000000),
      blurRadius: 12,
      offset: Offset(0, 4),
      spreadRadius: -2,
    ),
    BoxShadow(
      color: Color(0x0A000000),
      blurRadius: 4,
      offset: Offset(0, 1),
    ),
  ];

  static const List<BoxShadow> raisedLight = [
    BoxShadow(
      color: Color(0x1F000000),
      blurRadius: 24,
      offset: Offset(0, 8),
      spreadRadius: -4,
    ),
    BoxShadow(
      color: Color(0x0D000000),
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
  ];

  static const List<BoxShadow> modalLight = [
    BoxShadow(
      color: Color(0x29000000),
      blurRadius: 40,
      offset: Offset(0, 16),
      spreadRadius: -8,
    ),
  ];

  static List<BoxShadow> glowLight = [
    BoxShadow(
      color: AppColors.brand.withValues(alpha: 0.25),
      blurRadius: 16,
      offset: const Offset(0, 4),
      spreadRadius: -4,
    ),
  ];

  // ── Inner shadows (for inset glass surfaces) ───────────────────────────

  /// Subtle inner glow on glass surfaces (painted via CustomPainter).
  static const List<BoxShadow> innerGlowDark = [
    BoxShadow(
      color: Color(0x0DFFFFFF),
      blurRadius: 1,
      spreadRadius: 0,
    ),
  ];

  static const List<BoxShadow> innerGlowLight = [
    BoxShadow(
      color: Color(0x1AFFFFFF),
      blurRadius: 1,
      spreadRadius: 0,
    ),
  ];

  // ── Legacy Compatibility ───────────────────────────────────────────────

  /// Legacy button shadow helper fallback.
  static List<BoxShadow> buttonRaised(ThemeData theme) {
    return theme.brightness == Brightness.dark ? raisedDark : raisedLight;
  }
}
