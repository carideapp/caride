import 'package:design_system/design_system.dart';
import 'package:caride/core/driver/auth/driver_auth_controller.dart';
import 'package:caride/core/driver/models/vehicle_info.dart';
import 'package:caride/core/driver/models/vehicle_review.dart';
import 'package:caride/core/driver/verification/driver_verification_config.dart';
import 'package:caride/features/driver/auth/data/driver_profile_repository.dart';
import 'package:caride/features/driver/profile/widgets/vehicle_info_requirement_dialog.dart';
import 'package:flutter/material.dart';
import 'package:navigation/navigation.dart';
import 'package:shared_widgets/shared_widgets.dart';

class DriverVehicleScreen extends StatefulWidget {
  const DriverVehicleScreen({super.key});

  @override
  State<DriverVehicleScreen> createState() => _DriverVehicleScreenState();
}

class _DriverVehicleScreenState extends State<DriverVehicleScreen> {
  final _profileRepo = DriverProfileRepository();
  VehicleInfo? _vehicle;
  VehicleReview? _vehicleReview;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadVehicle();
  }

  Future<void> _loadVehicle() async {
    final uid = driverAuthController.currentUid;
    if (uid == null) {
      setState(() => _loading = false);
      return;
    }
    final vehicle = await _profileRepo.getVehicleInfo(uid);
    final review = await _profileRepo.getVehicleReview(uid);
    if (mounted) {
      setState(() {
        _vehicle = vehicle;
        _vehicleReview = review;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final backgroundColor =
        isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final surfaceColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final borderColor =
        isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFE9EAF0);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        title: Text(
          'Vehicle',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ResponsiveContainer(
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.md,
                  ),
                  children: [
                    if (_vehicleReview != null) ...[
                      _VehicleReviewStatusCard(review: _vehicleReview!),
                      const SizedBox(height: AppSpacing.lg),
                    ],

                    // Vehicle Details Section Header
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Vehicle Details',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: isDark ? Colors.white : AppColors.slate900,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'General make, model, color and plate code',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: isDark ? Colors.grey[400] : const Color(0xFF6E7191),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),

                    // Vehicle details item card
                    Container(
                      decoration: BoxDecoration(
                        color: surfaceColor,
                        borderRadius: BorderRadius.circular(AppRadius.xl),
                        border: Border.all(color: borderColor),
                        boxShadow: isDark
                            ? null
                            : [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 16,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                      ),
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Row(
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: AppColors.primaryGreen.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(AppRadius.lg),
                            ),
                            child: const Icon(
                              Icons.directions_car_filled_rounded,
                              color: AppColors.primaryGreen,
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _vehicle != null
                                      ? _vehicle!.displayName
                                      : 'No vehicle added',
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 18,
                                    color: isDark ? Colors.white : AppColors.slate900,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _vehicle != null
                                      ? '${_vehicle!.color} • ${_vehicle!.plateNumber}'
                                      : 'Tap Edit to submit your vehicle details',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: isDark ? Colors.grey[400] : const Color(0xFF6E7191),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_vehicleReview?.isApproved != true) ...[
                            const SizedBox(width: AppSpacing.sm),
                            IconButton(
                              onPressed: () async {
                                await context.push(DriverRoutePaths.vehicleInfo);
                                _loadVehicle();
                              },
                              style: IconButton.styleFrom(
                                backgroundColor: AppColors.primaryGreen,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.all(AppSpacing.sm),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(AppRadius.md),
                                ),
                              ),
                              icon: const Icon(Icons.edit_rounded, size: 20),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    if (_vehicle != null) ...[
                      // Vehicle category Section Header
                      Padding(
                        padding: const EdgeInsets.only(left: 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Vehicle Category',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: isDark ? Colors.white : AppColors.slate900,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'The classification for matching matching services',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: isDark ? Colors.grey[400] : const Color(0xFF6E7191),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Container(
                        decoration: BoxDecoration(
                          color: surfaceColor,
                          borderRadius: BorderRadius.circular(AppRadius.xl),
                          border: Border.all(color: borderColor),
                          boxShadow: isDark
                              ? null
                              : [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.04),
                                    blurRadius: 16,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                        ),
                        padding: const EdgeInsets.all(AppSpacing.lg),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: AppColors.primaryGreen.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(AppRadius.md),
                              ),
                              child: const Icon(
                                Icons.category_rounded,
                                color: AppColors.primaryGreen,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.md),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    vehicleTypeLabel(_vehicle!.vehicleType),
                                    style: theme.textTheme.bodyLarge?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: isDark ? Colors.white : AppColors.slate900,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${seatCountForVehicleType(_vehicle!.vehicleType)} Passengers Max',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: isDark ? Colors.grey[400] : const Color(0xFF6E7191),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xl),
                    ],

                    // Vehicle Documents Section Header
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Vehicle Documents',
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: isDark ? Colors.white : AppColors.slate900,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Manage and upload regulatory verification papers',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: isDark ? Colors.grey[400] : const Color(0xFF6E7191),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Container(
                      decoration: BoxDecoration(
                        color: surfaceColor,
                        borderRadius: BorderRadius.circular(AppRadius.xl),
                        border: Border.all(color: borderColor),
                        boxShadow: isDark
                            ? null
                            : [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 16,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                      ),
                      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            if (_vehicle == null) {
                              showVehicleInfoRequiredDialog(context);
                              return;
                            }
                            context.push(DriverRoutePaths.profileDocuments);
                          },
                          borderRadius: BorderRadius.circular(AppRadius.xl),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.lg,
                              vertical: AppSpacing.md,
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryGreen.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(AppRadius.md),
                                  ),
                                  child: const Icon(
                                    Icons.folder_copy_outlined,
                                    color: AppColors.primaryGreen,
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.md),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Manage Documents',
                                        style: theme.textTheme.bodyLarge?.copyWith(
                                          fontWeight: FontWeight.w700,
                                          color: isDark ? Colors.white : AppColors.slate900,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Upload vehicle registration, insurance, etc.',
                                        style: theme.textTheme.bodySmall?.copyWith(
                                          color: isDark ? Colors.grey[400] : const Color(0xFF6E7191),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.chevron_right_rounded,
                                  color: Colors.grey[400],
                                  size: 24,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _VehicleReviewStatusCard extends StatelessWidget {
  const _VehicleReviewStatusCard({required this.review});

  final VehicleReview review;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final color = review.isRejected
        ? theme.colorScheme.error
        : review.isApproved
            ? AppColors.primaryGreen
            : theme.colorScheme.primary;
    final icon = review.isRejected
        ? Icons.error_outline_rounded
        : review.isApproved
            ? Icons.check_circle_outline_rounded
            : Icons.pending_outlined;
    final title = review.isRejected
        ? 'Vehicle update rejected'
        : review.isApproved
            ? 'Vehicle info approved'
            : 'Vehicle info pending review';
    final message = review.isRejected
        ? review.rejectionReason ?? 'Please update the highlighted details and submit again.'
        : review.isApproved
            ? 'Your latest vehicle details have been approved.'
            : 'Your latest vehicle details are waiting for admin approval.';

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: isDark ? Colors.grey[300] : const Color(0xFF4A4D70),
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
