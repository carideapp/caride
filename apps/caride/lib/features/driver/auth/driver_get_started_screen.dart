import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:navigation/navigation.dart';
import 'package:shared_widgets/shared_widgets.dart';

import 'package:flutter/services.dart';

/// Redesigned Get Started Screen with Apple Liquid Glass overlay and premium aesthetics.
class DriverGetStartedScreen extends StatelessWidget {
  const DriverGetStartedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark
          ? SystemUiOverlayStyle.light.copyWith(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: Brightness.light,
              statusBarBrightness: Brightness.dark,
            )
          : SystemUiOverlayStyle.dark.copyWith(
              statusBarColor: Colors.transparent,
              statusBarIconBrightness: Brightness.dark,
              statusBarBrightness: Brightness.light,
            ),
      child: Scaffold(
        backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
        body: Stack(
          children: [
            // ── Background Image ──
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: MediaQuery.of(context).size.height * 0.58,
              child: Image.asset(
                'lib/assets/driver_img.png',
                fit: BoxFit.cover,
              ),
            ),
            // Gradient Overlay on Image for better contrast
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: MediaQuery.of(context).size.height * 0.58,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.black.withValues(alpha: 0.4),
                      Colors.transparent,
                      isDark ? AppColors.darkBackground : AppColors.lightBackground,
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),

            // ── Content Container with Glass Bottom Overlay ──
            Align(
              alignment: Alignment.bottomCenter,
              child: GlassSurface(
                radius: AppRadius.xxxl,
                blurSigma: AppGlass.blurHeavy,
                margin: const EdgeInsets.all(AppSpacing.md),
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.xl,
                  AppSpacing.xl,
                  AppSpacing.xl,
                  AppSpacing.xl,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── Header Text ──
                    Text(
                      'Drive & Earn with CaRide',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.headlineLarge.copyWith(
                        color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      'Join our community of professional drivers and take control of your earnings.',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxl),

                    // ── Action Buttons ──
                    PrimaryButton(
                      label: 'Register as a Driver',
                      onPressed: () => context.push(DriverRoutePaths.signup),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    SecondaryButton(
                      label: 'Sign In',
                      onPressed: () => context.push(DriverRoutePaths.login),
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    // ── Footer ──
                    Text(
                      'By continuing, you agree to our Terms of Service and Privacy Policy.',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.caption.copyWith(
                        fontSize: 10,
                        color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
