import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:navigation/navigation.dart';

/// Redesigned Fleet Manager Signup Success Screen matching the design system.
class FleetManagerSignupSuccessScreen extends StatelessWidget {
  const FleetManagerSignupSuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : Colors.black;
    final subtitleTextColor = isDark ? AppColors.textSecondaryDark : const Color(0xFF6B7280);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),

              // Scalloped Rosette Success Emblem in AppColors.brand
              Center(
                child: Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: AppColors.brand,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.brand.withValues(alpha: 0.3),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 50,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // Title
              Text(
                'Application Submitted!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: primaryTextColor,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 12),

              // Subtitle
              Text(
                'Your Fleet Manager registration has been submitted and is currently under review by our operations team.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: subtitleTextColor,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 28),

              // Notice Card (20px rounded corners, subtle tint)
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.brand.withValues(alpha: 0.08)
                      : const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.brand.withValues(alpha: 0.25),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.brand.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.schedule_rounded,
                        color: AppColors.brand,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Text(
                        'Verification typically takes 24–48 hours. We will notify you via email once approved.',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.white : const Color(0xFF1F2937),
                          fontWeight: FontWeight.w500,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Primary Action Button (Green Pill)
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brand,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  onPressed: () {
                    context.go(FleetRoutePaths.dashboard);
                  },
                  child: const Text(
                    'Go to Fleet Dashboard',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Secondary Action Button (Outlined Pill)
              SizedBox(
                width: double.infinity,
                height: 56,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
                    side: BorderSide(
                      color: isDark ? AppColors.glassBorderDark : const Color(0xFFD1D5DB),
                      width: 1.2,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  onPressed: () {
                    context.go(FleetRoutePaths.dashboard);
                  },
                  child: Text(
                    'Explore Fleet Portal',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: primaryTextColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}
