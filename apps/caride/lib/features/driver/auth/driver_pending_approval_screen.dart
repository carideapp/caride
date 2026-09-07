import 'package:design_system/design_system.dart';
import 'package:caride/core/driver/auth/driver_auth_controller.dart';
import 'package:caride/core/driver/models/driver_profile.dart';
import 'package:caride/features/driver/auth/data/driver_profile_repository.dart';
import 'package:flutter/material.dart';
import 'package:navigation/navigation.dart';
import 'package:shared_widgets/shared_widgets.dart';

class DriverPendingApprovalScreen extends StatefulWidget {
  const DriverPendingApprovalScreen({super.key});

  @override
  State<DriverPendingApprovalScreen> createState() =>
      _DriverPendingApprovalScreenState();
}

class _DriverPendingApprovalScreenState
    extends State<DriverPendingApprovalScreen> {
  final _repo = DriverProfileRepository();

  @override
  Widget build(BuildContext context) {
    final uid = driverAuthController.currentUid;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (uid == null) {
      return const Scaffold(body: Center(child: AppLoader()));
    }

    return StreamBuilder<DriverProfile?>(
      stream: _repo.streamDriverProfile(uid),
      builder: (context, snapshot) {
        final profile = snapshot.data;

        if (profile != null && profile.isApproved) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) context.go(DriverRoutePaths.home);
          });
        }

        final isRejected = profile?.isRejected ?? false;
        final isDraft = profile?.isDraft ?? false;
        final rejectionReason = profile?.rejectionReason;

        return Scaffold(
          backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
          appBar: GlassAppBar(
            title: 'Verification Status',
            showBorder: true,
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
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildStatusIcon(isRejected: isRejected, isDraft: isDraft),
                    const SizedBox(height: AppSpacing.xl),
                    Text(
                      isDraft
                          ? 'Complete Your Verification'
                          : isRejected
                              ? 'Application Not Approved'
                              : 'Application Under Review',
                      style: AppTextStyles.headlineMedium.copyWith(
                        color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                        fontWeight: FontWeight.w800,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      isDraft
                          ? 'Add your vehicle information and upload required documents before admin review can begin.'
                          : isRejected
                              ? 'Your application was not approved. Please review the feedback below and re-submit your documents.'
                              : 'We are reviewing your documents and application. This typically takes 1–2 business days. We will notify you by email.',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                      ),
                      textAlign: TextAlign.center,
                    ),

                    if (isRejected && rejectionReason != null) ...[
                      const SizedBox(height: AppSpacing.xl),
                      _RejectionReasonCard(reason: rejectionReason),
                    ],

                    const SizedBox(height: AppSpacing.xl * 1.5),

                    if (isDraft)
                      PrimaryButton(
                        label: 'Continue Verification',
                        onPressed: () => context.go(DriverRoutePaths.profileVehicle),
                      )
                    else if (isRejected)
                      PrimaryButton(
                        label: 'Re-upload Documents',
                        onPressed: () => context.go(DriverRoutePaths.profileDocuments),
                      )
                    else
                      _ReviewingStatusCard(),

                    const SizedBox(height: AppSpacing.md),
                    SecondaryButton(
                      label: 'Sign Out',
                      onPressed: () async {
                        await driverAuthController.signOut();
                        if (context.mounted) {
                          context.go(DriverRoutePaths.login);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusIcon({required bool isRejected, required bool isDraft}) {
    final baseColor = isRejected ? AppColors.error : AppColors.brand;
    final bg = isRejected ? AppColors.errorSubtle : AppColors.brandGlass;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: bg,
        shape: BoxShape.circle,
        border: Border.all(
          color: isRejected
              ? AppColors.error.withValues(alpha: 0.2)
              : AppColors.brandGlassBorder,
        ),
      ),
      child: Icon(
        isDraft
            ? Icons.assignment_outlined
            : isRejected
                ? Icons.cancel_outlined
                : Icons.hourglass_top_rounded,
        size: 72,
        color: baseColor,
      ),
    );
  }
}

class _RejectionReasonCard extends StatelessWidget {
  const _RejectionReasonCard({required this.reason});

  final String reason;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.errorSubtle,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: AppColors.error.withValues(alpha: 0.2),
          width: AppGlass.borderThin,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.info_outline, color: AppColors.error, size: 18),
              const SizedBox(width: AppSpacing.xs),
              Text(
                'Reason for Rejection',
                style: AppTextStyles.titleSmall.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.error,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            reason,
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.error),
          ),
        ],
      ),
    );
  }
}

class _ReviewingStatusCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GlassContainer(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          const SizedBox(
            width: 24,
            height: 24,
            child: AppLoader(size: 20),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Review in progress',
                  style: AppTextStyles.titleSmall.copyWith(
                    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                  ),
                ),
                Text(
                  'We will redirect you automatically when approved.',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
