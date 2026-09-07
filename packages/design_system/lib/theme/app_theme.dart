import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';
import 'app_elevations.dart';
import 'app_radius.dart';
import 'app_spacing.dart';

/// Central theme factory: Liquid Glass light and dark.
///
/// Dark mode is the **primary** experience.
abstract final class AppTheme {
  // ═══════════════════════════════════════════════════════════════════════
  //  LIGHT
  // ═══════════════════════════════════════════════════════════════════════
  static ThemeData light() {
    final colorScheme = ColorScheme.light(
      primary: AppColors.brand,
      onPrimary: Colors.white,
      primaryContainer: AppColors.brandLight,
      onPrimaryContainer: AppColors.brandDark,
      secondary: AppColors.accent,
      onSecondary: AppColors.onAccent,
      surface: AppColors.lightSurface,
      onSurface: AppColors.textPrimaryLight,
      surfaceContainerHighest: AppColors.lightSurfaceVariant,
      outline: AppColors.lightOutline,
      outlineVariant: AppColors.lightOutlineVariant,
      error: AppColors.error,
      onError: Colors.white,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.lightBackground,
      splashFactory: InkSparkle.splashFactory,
    );

    return base.copyWith(
      textTheme: AppTypography.textThemeLight(base.textTheme),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textPrimaryLight,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
        titleTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: AppFontSizes.headlineSmall,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimaryLight,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: AppElevations.none,
        color: AppColors.lightSurface.withValues(alpha: 0.85),
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          side: BorderSide(
            color: AppColors.glassBorderLight,
            width: 0.5,
          ),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.lightSurfaceInset,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(
            color: AppColors.lightOutline.withValues(alpha: 0.4),
            width: 0.5,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.brand, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.error, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
        hintStyle: GoogleFonts.plusJakartaSans(
          fontSize: AppFontSizes.bodyMedium,
          color: AppColors.textTertiaryLight,
        ),
        labelStyle: GoogleFonts.plusJakartaSans(
          fontSize: AppFontSizes.bodyMedium,
          color: AppColors.textSecondaryLight,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: AppColors.brand,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.lightSurfaceVariant,
          disabledForegroundColor: AppColors.textDisabledLight,
          minimumSize: const Size(double.infinity, 52),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xxl,
            vertical: AppSpacing.md,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: AppFontSizes.titleMedium,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimaryLight,
          backgroundColor: Colors.transparent,
          side: BorderSide(color: AppColors.lightOutline, width: 1),
          minimumSize: const Size(double.infinity, 52),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xxl,
            vertical: AppSpacing.md,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.brand,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.transparent,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        height: AppSpacing.navBarHeight,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        indicatorColor: Colors.transparent,
        iconTheme: WidgetStateProperty.resolveWith<IconThemeData>((states) {
          final isSelected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 24,
            color: isSelected
                ? AppColors.brand
                : AppColors.textTertiaryLight,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>((states) {
          final isSelected = states.contains(WidgetState.selected);
          return GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected
                ? AppColors.brand
                : AppColors.textTertiaryLight,
          );
        }),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.brand,
        foregroundColor: Colors.white,
        elevation: AppElevations.raised,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.lightOutline,
        thickness: 0.5,
        space: 0.5,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: AppColors.lightSurface,
        surfaceTintColor: Colors.transparent,
        modalBarrierColor: AppColors.glassOverlayLight,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.xxl),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.textPrimaryLight,
        contentTextStyle: GoogleFonts.plusJakartaSans(color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.lightSurfaceInset,
        selectedColor: AppColors.brandGlass,
        labelStyle: GoogleFonts.plusJakartaSans(fontSize: AppFontSizes.bodySmall),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        side: BorderSide.none,
      ),
      shadowColor: Colors.transparent,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════
  //  DARK (primary experience)
  // ═══════════════════════════════════════════════════════════════════════
  static ThemeData dark() {
    final colorScheme = ColorScheme.dark(
      primary: AppColors.brand,
      onPrimary: Colors.white,
      primaryContainer: AppColors.brandDark,
      onPrimaryContainer: AppColors.brandLight,
      secondary: AppColors.accent,
      onSecondary: AppColors.onAccent,
      surface: AppColors.darkSurface,
      onSurface: AppColors.textPrimaryDark,
      surfaceContainerHighest: AppColors.darkSurfaceVariant,
      outline: AppColors.darkOutline,
      outlineVariant: AppColors.darkOutlineVariant,
      error: AppColors.error,
      onError: Colors.white,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.darkBackground,
      splashFactory: InkSparkle.splashFactory,
    );

    return base.copyWith(
      textTheme: AppTypography.textThemeDark(base.textTheme),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor: Colors.transparent,
        foregroundColor: AppColors.textPrimaryDark,
        surfaceTintColor: Colors.transparent,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarIconBrightness: Brightness.light,
        ),
        titleTextStyle: GoogleFonts.plusJakartaSans(
          fontSize: AppFontSizes.headlineSmall,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimaryDark,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: AppElevations.none,
        color: AppColors.glassBackgroundDark,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          side: BorderSide(
            color: AppColors.glassBorderDark,
            width: 0.5,
          ),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.darkSurfaceInset,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide(
            color: AppColors.darkOutline.withValues(alpha: 0.5),
            width: 0.5,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.brand, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.error, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
        hintStyle: GoogleFonts.plusJakartaSans(
          fontSize: AppFontSizes.bodyMedium,
          color: AppColors.textTertiaryDark,
        ),
        labelStyle: GoogleFonts.plusJakartaSans(
          fontSize: AppFontSizes.bodyMedium,
          color: AppColors.textSecondaryDark,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: AppColors.brand,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.darkSurfaceVariant,
          disabledForegroundColor: AppColors.textDisabledDark,
          minimumSize: const Size(double.infinity, 52),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xxl,
            vertical: AppSpacing.md,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          textStyle: GoogleFonts.plusJakartaSans(
            fontSize: AppFontSizes.titleMedium,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimaryDark,
          backgroundColor: Colors.transparent,
          side: BorderSide(color: AppColors.darkOutline, width: 1),
          minimumSize: const Size(double.infinity, 52),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xxl,
            vertical: AppSpacing.md,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.brandLight,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.transparent,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        height: AppSpacing.navBarHeight,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        indicatorColor: Colors.transparent,
        iconTheme: WidgetStateProperty.resolveWith<IconThemeData>((states) {
          final isSelected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 24,
            color: isSelected
                ? AppColors.brand
                : AppColors.textTertiaryDark,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>((states) {
          final isSelected = states.contains(WidgetState.selected);
          return GoogleFonts.plusJakartaSans(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected
                ? AppColors.brand
                : AppColors.textTertiaryDark,
          );
        }),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: AppColors.brand,
        foregroundColor: Colors.white,
        elevation: AppElevations.raised,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.darkOutline,
        thickness: 0.5,
        space: 0.5,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: AppColors.darkSurfaceRaised,
        surfaceTintColor: Colors.transparent,
        modalBarrierColor: AppColors.glassOverlayDark,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.xxl),
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.darkSurfaceVariant,
        contentTextStyle: GoogleFonts.plusJakartaSans(color: Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.darkSurfaceVariant,
        selectedColor: AppColors.brandGlass,
        labelStyle: GoogleFonts.plusJakartaSans(
          fontSize: AppFontSizes.bodySmall,
          color: AppColors.textPrimaryDark,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.pill),
        ),
        side: BorderSide(color: AppColors.glassBorderDark, width: 0.5),
      ),
      shadowColor: Colors.transparent,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  TYPOGRAPHY
// ═══════════════════════════════════════════════════════════════════════════

class AppFontSizes {
  static const double displayLarge = 34;
  static const double displayMedium = 28;
  static const double displaySmall = 24;
  static const double headlineLarge = 22;
  static const double headlineMedium = 20;
  static const double headlineSmall = 17;
  static const double titleLarge = 17;
  static const double titleMedium = 15;
  static const double titleSmall = 13;
  static const double bodyLarge = 17;
  static const double bodyMedium = 15;
  static const double bodySmall = 13;
  static const double caption = 11;
  static const double overline = 10;

  /// Large monospaced number display (earnings, stats).
  static const double statLarge = 40;
  static const double statMedium = 28;
}

class AppTypography {
  static double scale = 1.0;

  static double font(double size) => size * scale;

  static TextTheme textThemeLight(TextTheme base) {
    return TextTheme(
      displayLarge: AppTextStyles.displayLarge.copyWith(color: AppColors.textPrimaryLight),
      displayMedium: AppTextStyles.displayMedium.copyWith(color: AppColors.textPrimaryLight),
      displaySmall: AppTextStyles.displaySmall.copyWith(color: AppColors.textPrimaryLight),
      headlineLarge: AppTextStyles.headlineLarge.copyWith(color: AppColors.textPrimaryLight),
      headlineMedium: AppTextStyles.headlineMedium.copyWith(color: AppColors.textPrimaryLight),
      headlineSmall: AppTextStyles.headlineSmall.copyWith(color: AppColors.textPrimaryLight),
      titleLarge: AppTextStyles.titleLarge.copyWith(color: AppColors.textPrimaryLight),
      titleMedium: AppTextStyles.titleMedium.copyWith(color: AppColors.textPrimaryLight),
      titleSmall: AppTextStyles.titleSmall.copyWith(color: AppColors.textPrimaryLight),
      bodyLarge: AppTextStyles.bodyLarge.copyWith(color: AppColors.textPrimaryLight),
      bodyMedium: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondaryLight),
      bodySmall: AppTextStyles.bodySmall.copyWith(color: AppColors.textTertiaryLight),
      labelLarge: AppTextStyles.labelLarge.copyWith(color: AppColors.textPrimaryLight),
      labelMedium: AppTextStyles.labelMedium.copyWith(color: AppColors.textSecondaryLight),
      labelSmall: AppTextStyles.labelSmall.copyWith(color: AppColors.textTertiaryLight),
    );
  }

  static TextTheme textThemeDark(TextTheme base) {
    return TextTheme(
      displayLarge: AppTextStyles.displayLarge.copyWith(color: AppColors.textPrimaryDark),
      displayMedium: AppTextStyles.displayMedium.copyWith(color: AppColors.textPrimaryDark),
      displaySmall: AppTextStyles.displaySmall.copyWith(color: AppColors.textPrimaryDark),
      headlineLarge: AppTextStyles.headlineLarge.copyWith(color: AppColors.textPrimaryDark),
      headlineMedium: AppTextStyles.headlineMedium.copyWith(color: AppColors.textPrimaryDark),
      headlineSmall: AppTextStyles.headlineSmall.copyWith(color: AppColors.textPrimaryDark),
      titleLarge: AppTextStyles.titleLarge.copyWith(color: AppColors.textPrimaryDark),
      titleMedium: AppTextStyles.titleMedium.copyWith(color: AppColors.textPrimaryDark),
      titleSmall: AppTextStyles.titleSmall.copyWith(color: AppColors.textPrimaryDark),
      bodyLarge: AppTextStyles.bodyLarge.copyWith(color: AppColors.textPrimaryDark),
      bodyMedium: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimaryDark),
      bodySmall: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondaryDark),
      labelLarge: AppTextStyles.labelLarge.copyWith(color: AppColors.textPrimaryDark),
      labelMedium: AppTextStyles.labelMedium.copyWith(color: AppColors.textPrimaryDark),
      labelSmall: AppTextStyles.labelSmall.copyWith(color: AppColors.textSecondaryDark),
    );
  }
}

/// Individual text styles — use via [AppTypography] text themes or directly.
class AppTextStyles {
  static TextStyle get displayLarge => GoogleFonts.plusJakartaSans(
        fontWeight: FontWeight.w700,
        fontSize: AppTypography.font(AppFontSizes.displayLarge),
        height: 1.18,
        letterSpacing: -0.8,
      );

  static TextStyle get displayMedium => GoogleFonts.plusJakartaSans(
        fontWeight: FontWeight.w700,
        fontSize: AppTypography.font(AppFontSizes.displayMedium),
        height: 1.2,
        letterSpacing: -0.5,
      );

  static TextStyle get displaySmall => GoogleFonts.plusJakartaSans(
        fontWeight: FontWeight.w700,
        fontSize: AppTypography.font(AppFontSizes.displaySmall),
        height: 1.22,
        letterSpacing: -0.4,
      );

  static TextStyle get headlineLarge => GoogleFonts.plusJakartaSans(
        fontWeight: FontWeight.w700,
        fontSize: AppTypography.font(AppFontSizes.headlineLarge),
        height: 1.25,
        letterSpacing: -0.3,
      );

  static TextStyle get headlineMedium => GoogleFonts.plusJakartaSans(
        fontWeight: FontWeight.w600,
        fontSize: AppTypography.font(AppFontSizes.headlineMedium),
        height: 1.25,
        letterSpacing: -0.2,
      );

  static TextStyle get headlineSmall => GoogleFonts.plusJakartaSans(
        fontWeight: FontWeight.w600,
        fontSize: AppTypography.font(AppFontSizes.headlineSmall),
        height: 1.3,
      );

  static TextStyle get titleLarge => GoogleFonts.plusJakartaSans(
        fontWeight: FontWeight.w600,
        fontSize: AppTypography.font(AppFontSizes.titleLarge),
        height: 1.3,
      );

  static TextStyle get titleMedium => GoogleFonts.plusJakartaSans(
        fontWeight: FontWeight.w600,
        fontSize: AppTypography.font(AppFontSizes.titleMedium),
        height: 1.35,
      );

  static TextStyle get titleSmall => GoogleFonts.plusJakartaSans(
        fontWeight: FontWeight.w600,
        fontSize: AppTypography.font(AppFontSizes.titleSmall),
        height: 1.35,
        letterSpacing: 0.1,
      );

  static TextStyle get bodyLarge => GoogleFonts.plusJakartaSans(
        fontWeight: FontWeight.w400,
        fontSize: AppTypography.font(AppFontSizes.bodyLarge),
        height: 1.47,
      );

  static TextStyle get bodyMedium => GoogleFonts.plusJakartaSans(
        fontWeight: FontWeight.w400,
        fontSize: AppTypography.font(AppFontSizes.bodyMedium),
        height: 1.45,
      );

  static TextStyle get bodySmall => GoogleFonts.plusJakartaSans(
        fontWeight: FontWeight.w400,
        fontSize: AppTypography.font(AppFontSizes.bodySmall),
        height: 1.4,
      );

  static TextStyle get labelLarge => GoogleFonts.plusJakartaSans(
        fontWeight: FontWeight.w600,
        fontSize: AppTypography.font(AppFontSizes.titleMedium),
        height: 1.35,
        letterSpacing: 0.2,
      );

  static TextStyle get labelMedium => GoogleFonts.plusJakartaSans(
        fontWeight: FontWeight.w500,
        fontSize: AppTypography.font(AppFontSizes.titleSmall),
        height: 1.3,
        letterSpacing: 0.3,
      );

  static TextStyle get labelSmall => GoogleFonts.plusJakartaSans(
        fontWeight: FontWeight.w500,
        fontSize: AppTypography.font(AppFontSizes.caption),
        height: 1.3,
        letterSpacing: 0.4,
      );

  static TextStyle get caption => GoogleFonts.plusJakartaSans(
        fontWeight: FontWeight.w400,
        fontSize: AppTypography.font(AppFontSizes.caption),
        height: 1.4,
      );

  /// Large monospaced number for stats / earnings.
  static TextStyle get statLarge => GoogleFonts.plusJakartaSans(
        fontWeight: FontWeight.w700,
        fontSize: AppTypography.font(AppFontSizes.statLarge),
        height: 1.1,
        letterSpacing: -1.5,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  static TextStyle get statMedium => GoogleFonts.plusJakartaSans(
        fontWeight: FontWeight.w700,
        fontSize: AppTypography.font(AppFontSizes.statMedium),
        height: 1.15,
        letterSpacing: -1.0,
        fontFeatures: const [FontFeature.tabularFigures()],
      );
}
