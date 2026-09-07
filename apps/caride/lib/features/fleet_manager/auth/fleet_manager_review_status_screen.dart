import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:navigation/navigation.dart';

import 'controllers/fleet_auth_controller.dart';

/// Redesigned Fleet Manager Review Status Screen matching the design system.
class FleetManagerReviewStatusScreen extends StatelessWidget {
  const FleetManagerReviewStatusScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar with Circular Back Button & Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface : Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB),
                      ),
                    ),
                    child: IconButton(
                      icon: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 18,
                        color: primaryTextColor,
                      ),
                      onPressed: () {
                        if (Navigator.of(context).canPop()) {
                          context.pop();
                        } else {
                          context.go(CustomerRoutePaths.roleSelector);
                        }
                      },
                    ),
                  ),
                  Expanded(
                    child: Text(
                      'Application Status',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: primaryTextColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 44),
                ],
              ),
            ),

            // Content
            Expanded(
              child: ListenableBuilder(
                listenable: fleetAuthController,
                builder: (context, _) {
                  final profile = fleetAuthController.currentProfile;
                  final status = profile?.verificationStatus.toLowerCase() ?? 'pending';

                  if (status == 'approved' || profile?.isVerified == true) {
                    return _buildApprovedState(context, isDark, primaryTextColor, profile);
                  } else if (status == 'rejected') {
                    return _buildRejectedState(context, isDark, primaryTextColor, profile);
                  } else if (status == 'suspended') {
                    return _buildSuspendedState(context, isDark, primaryTextColor, profile);
                  }
                  return _buildPendingState(context, isDark, primaryTextColor, profile);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 1. Pending Review State ───────────────────────────────────────────

  Widget _buildPendingState(
      BuildContext context, bool isDark, Color primaryTextColor, dynamic profile) {
    final subtitleTextColor = isDark ? AppColors.textSecondaryDark : const Color(0xFF6B7280);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(),

          // Pending Icon in Soft Amber Container
          Center(
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Center(
                child: Icon(
                  Icons.hourglass_top_rounded,
                  color: Color(0xFFF59E0B),
                  size: 44,
                ),
              ),
            ),
          ),
          const SizedBox(height: 28),

          Text(
            'Under Review',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: primaryTextColor,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your Fleet Manager account is currently being reviewed by the CaRide operations team.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: subtitleTextColor,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 28),

          // Status Checklist Card (20px rounded)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB),
              ),
            ),
            child: Column(
              children: [
                _buildStatusItem(
                  icon: Icons.mark_email_read_rounded,
                  title: 'Email & Credentials',
                  subtitle: 'Verified',
                  isSuccess: true,
                  isDark: isDark,
                ),
                Divider(
                  height: 24,
                  color: isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB),
                ),
                _buildStatusItem(
                  icon: Icons.domain_verification_rounded,
                  title: 'Identity & CAC Documents',
                  subtitle: 'Pending Admin Verification',
                  isSuccess: false,
                  isWarning: true,
                  isDark: isDark,
                ),
                Divider(
                  height: 24,
                  color: isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB),
                ),
                _buildStatusItem(
                  icon: Icons.shield_outlined,
                  title: 'Fleet Operations Access',
                  subtitle: 'Unlocked upon verification',
                  isSuccess: false,
                  isDark: isDark,
                ),
              ],
            ),
          ),

          const Spacer(),

          // Primary Pill Button: Switch Account Mode
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
              onPressed: () => context.go(CustomerRoutePaths.roleSelector),
              child: const Text(
                'Switch Account Mode',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Outlined Pill Button: Sign Out
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
              onPressed: () async {
                await fleetAuthController.signOut();
                if (context.mounted) {
                  context.go(CustomerRoutePaths.welcome);
                }
              },
              child: const Text(
                'Sign Out',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.error,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ── 2. Approved State ─────────────────────────────────────────────────

  Widget _buildApprovedState(
      BuildContext context, bool isDark, Color primaryTextColor, dynamic profile) {
    final subtitleTextColor = isDark ? AppColors.textSecondaryDark : const Color(0xFF6B7280);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(),

          // Rosette Success Emblem in AppColors.brand
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
          const SizedBox(height: 28),

          Text(
            'Account Approved!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: primaryTextColor,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Your Fleet Manager account is fully verified. You can now list rental vehicles, assign chauffeurs, and track operations.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: subtitleTextColor,
              height: 1.4,
            ),
          ),
          const Spacer(),

          // Primary Pill Button: Open Fleet Dashboard
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
              onPressed: () => context.go(FleetRoutePaths.dashboard),
              child: const Text(
                'Open Fleet Dashboard',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ── 3. Rejected State ─────────────────────────────────────────────────

  Widget _buildRejectedState(
      BuildContext context, bool isDark, Color primaryTextColor, dynamic profile) {
    final rejectionReason =
        profile?.rejectionReason ?? 'Document unreadable or invalid credentials.';
    final subtitleTextColor = isDark ? AppColors.textSecondaryDark : const Color(0xFF6B7280);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(),

          Center(
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.error.withValues(alpha: 0.2),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Center(
                child: Icon(
                  Icons.cancel_rounded,
                  color: AppColors.error,
                  size: 48,
                ),
              ),
            ),
          ),
          const SizedBox(height: 28),

          Text(
            'Action Required',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: primaryTextColor,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Our review team requested updates for your application:',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: subtitleTextColor,
            ),
          ),
          const SizedBox(height: 20),

          // Rejection Reason Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurface : const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline_rounded, color: AppColors.error, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    rejectionReason,
                    style: const TextStyle(
                      color: AppColors.error,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const Spacer(),

          // Update Documents Pill Button
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
              onPressed: () => context.go(FleetRoutePaths.signup),
              child: const Text(
                'Update Application & Resubmit',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  // ── 4. Suspended State ────────────────────────────────────────────────

  Widget _buildSuspendedState(
      BuildContext context, bool isDark, Color primaryTextColor, dynamic profile) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(),

          Center(
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Icon(
                  Icons.block_rounded,
                  color: AppColors.error,
                  size: 48,
                ),
              ),
            ),
          ),
          const SizedBox(height: 28),

          Text(
            'Account Suspended',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: primaryTextColor,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Your Fleet Manager account has been suspended. Please contact CaRide support for assistance.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              color: isDark ? AppColors.textSecondaryDark : const Color(0xFF6B7280),
              height: 1.4,
            ),
          ),
          const Spacer(),

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
              onPressed: () => context.go(CustomerRoutePaths.roleSelector),
              child: const Text(
                'Return to Role Selection',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildStatusItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isSuccess,
    bool isWarning = false,
    required bool isDark,
  }) {
    Color iconColor;
    Color iconBg;
    if (isSuccess) {
      iconColor = AppColors.brand;
      iconBg = AppColors.brand.withValues(alpha: 0.12);
    } else if (isWarning) {
      iconColor = const Color(0xFFF59E0B);
      iconBg = const Color(0xFFFEF3C7);
    } else {
      iconColor = const Color(0xFF9CA3AF);
      iconBg = const Color(0xFFF3F4F6);
    }

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: iconBg,
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: isDark ? Colors.white : const Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  color: isSuccess
                      ? AppColors.brand
                      : (isWarning
                          ? const Color(0xFFD97706)
                          : (isDark ? AppColors.textSecondaryDark : const Color(0xFF6B7280))),
                  fontSize: 12,
                  fontWeight: isSuccess || isWarning ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
        if (isSuccess)
          const Icon(Icons.check_circle_rounded, color: AppColors.brand, size: 20)
        else if (isWarning)
          const Icon(Icons.access_time_filled_rounded, color: Color(0xFFF59E0B), size: 20),
      ],
    );
  }
}
