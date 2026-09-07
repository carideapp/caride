import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:navigation/navigation.dart';
import 'package:shared_widgets/shared_widgets.dart';

class DriverRegisterSuccessScreen extends StatelessWidget {
  const DriverRegisterSuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: GlassAppBar(
        title: 'Registration Successful',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.go(CustomerRoutePaths.welcome),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.pagePadding,
            vertical: AppSpacing.xl,
          ),
          child: GlassSurface(
            radius: AppRadius.xxl,
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(AppSpacing.xl),
                    decoration: BoxDecoration(
                      color: AppColors.brandGlass,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.brandGlassBorder),
                    ),
                    child: const Icon(
                      Icons.check_circle_rounded,
                      size: 80,
                      color: AppColors.brand,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  'Success!',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.headlineLarge.copyWith(
                    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Your account has been successfully created. You can now sign in to your driver dashboard.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl * 1.5),

                PrimaryButton(
                  label: 'Proceed to Login',
                  onPressed: () => context.go(DriverRoutePaths.login),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
