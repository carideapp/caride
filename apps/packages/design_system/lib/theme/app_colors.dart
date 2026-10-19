import 'package:flutter/material.dart';

/// CaRide Liquid Glass design-token colour palette.
///
/// Dark mode is the *primary* experience; light mode is a polished secondary.
/// Glass-surface colours use alpha channels so they composite correctly
/// over `BackdropFilter` blurs.
abstract final class AppColors {
  // ── Brand ──────────────────────────────────────────────────────────────
  static const Color brand = Color(0xFF16A34A);
  static const Color primary = brand;
  static const Color brandLight = Color(0xFF22C55E);
  static const Color brandDark = Color(0xFF0B6B2E);
  static const Color brandSubtle = Color(0xFF052E16);

  // ── Brand glass tints (translucent for glass surfaces) ─────────────
  static const Color brandGlass = Color(0x2616A34A); // 15 %
  static const Color brandGlassLight = Color(0x1A22C55E); // 10 %
  static const Color brandGlassBorder = Color(0x3316A34A); // 20 %

  // ── Accent ─────────────────────────────────────────────────────────────
  static const Color accent = Color(0xFFFACC15);
  static const Color accentSubtle = Color(0x33FACC15); // 20 %
  static const Color onAccent = Color(0xFF0F172A);

  // ── Dark neutrals (primary experience) ─────────────────────────────────
  static const Color darkBackground = Color(0xFF0A0A0C);
  static const Color darkSurface = Color(0xFF111114);
  static const Color darkSurfaceRaised = Color(0xFF1A1A1F);
  static const Color darkSurfaceInset = Color(0xFF0E0E11);
  static const Color darkSurfaceVariant = Color(0xFF222228);
  static const Color darkOutline = Color(0xFF2E2E35);
  static const Color darkOutlineVariant = Color(0xFF3A3A42);
  static const Color darkShadow = Color(0xFF000000);
  static const Color darkHighlight = Color(0xFF38383F);

  // ── Light neutrals ─────────────────────────────────────────────────────
  static const Color lightBackground = Color(0xFFFFFFFF);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceRaised = Color(0xFFF9F9FB);
  static const Color lightSurfaceInset = Color(0xFFEFEFF1);
  static const Color lightSurfaceVariant = Color(0xFFE5E5EA);
  static const Color lightOutline = Color(0xFFD1D1D6);
  static const Color lightOutlineVariant = Color(0xFFC7C7CC);
  static const Color lightShadow = Color(0xFFB0B0B8);
  static const Color lightHighlight = Color(0xFFFFFFFF);

  // ── Glass surface colours (dark) ───────────────────────────────────────
  static const Color glassBackgroundDark = Color(0x1AFFFFFF); // 10 %
  static const Color glassBorderDark = Color(0x26FFFFFF); // 15 %
  static const Color glassHighlightDark = Color(0x0DFFFFFF); //  5 %
  static const Color glassOverlayDark = Color(0x80000000); // 50 %

  // ── Glass surface colours (light) ──────────────────────────────────────
  static const Color glassBackgroundLight = Color(0xB3FFFFFF); // 70 %
  static const Color glassBorderLight = Color(0x33000000); // 20 %
  static const Color glassHighlightLight = Color(0x1AFFFFFF); // 10 %
  static const Color glassOverlayLight = Color(0x4D000000); // 30 %

  // ── Text on dark ───────────────────────────────────────────────────────
  static const Color textPrimaryDark = Color(0xFFFFFFFF);
  static const Color textSecondaryDark = Color(0xFFF8FAFC);
  static const Color textTertiaryDark = Color(0xFFE2E8F0);
  static const Color textDisabledDark = Color(0xFF94A3B8);

  // ── Text on light ──────────────────────────────────────────────────────
  static const Color textPrimaryLight = Color(0xFF1C1C1E);
  static const Color textSecondaryLight = Color(0xFF636366);
  static const Color textTertiaryLight = Color(0xFFAEAEB2);
  static const Color textDisabledLight = Color(0xFFC7C7CC);

  // ── Semantic / status ──────────────────────────────────────────────────
  static const Color success = Color(0xFF34C759);
  static const Color successSubtle = Color(0x1A34C759);
  static const Color warning = Color(0xFFFF9F0A);
  static const Color warningSubtle = Color(0x1AFF9F0A);
  static const Color error = Color(0xFFFF3B30);
  static const Color errorSubtle = Color(0x1AFF3B30);
  static const Color info = Color(0xFF0A84FF);
  static const Color infoSubtle = Color(0x1A0A84FF);

  // ── Ride status ────────────────────────────────────────────────────────
  static const Color statusOnline = Color(0xFF30D158);
  static const Color statusOffline = Color(0xFF8E8E93);
  static const Color statusBusy = Color(0xFFFF9F0A);
  static const Color statusUrgent = Color(0xFFFF3B30);

  // ── Legacy aliases (keep old references compiling) ─────────────────────
  static const Color primaryGreen = brand;
  static const Color darkGreen = brandDark;
  static const Color accentYellow = accent;
  static const Color slate900 = textPrimaryLight;
  static const Color slate50 = lightBackground;
}
