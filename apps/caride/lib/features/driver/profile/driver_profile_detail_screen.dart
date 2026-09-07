import 'package:design_system/design_system.dart';
import 'package:caride/core/driver/auth/driver_auth_controller.dart';
import 'package:caride/core/driver/models/driver_profile.dart';
import 'package:caride/features/driver/auth/data/driver_profile_repository.dart';
import 'package:flutter/material.dart';
import 'package:navigation/navigation.dart';
import 'package:shared_widgets/shared_widgets.dart';

/// Redesigned Driver Profile Detail Screen with clean GlassAppBar, GlassSurface avatar container,
/// GlassContainer field groups, and updated typography tokens.
class DriverProfileDetailScreen extends StatelessWidget {
  const DriverProfileDetailScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = driverAuthController.currentUid;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (uid == null) {
      return Scaffold(
        backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
        body: const Center(child: AppLoader()),
      );
    }

    return StreamBuilder<DriverProfile?>(
      stream: DriverProfileRepository().streamDriverProfile(uid),
      builder: (context, snapshot) {
        final profile = snapshot.data;
        return _ProfileDetailContent(profile: profile);
      },
    );
  }
}

class _ProfileDetailContent extends StatelessWidget {
  const _ProfileDetailContent({this.profile});

  final DriverProfile? profile;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final photoUrl = profile?.profilePhotoUrl;
    final name = profile?.fullName ?? '';
    final email = profile?.email ?? driverAuthController.currentEmail ?? '';
    final phone = profile?.phone ?? '';

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: GlassAppBar(
        title: 'Profile Info',
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: ResponsiveContainer(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.pagePadding,
              vertical: AppSpacing.xl,
            ),
            child: Column(
              children: [
                Center(
                  child: Stack(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkSurfaceRaised : AppColors.lightSurfaceRaised,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.brand,
                            width: 3,
                          ),
                          boxShadow: isDark ? AppShadows.cardDark : AppShadows.cardLight,
                        ),
                        child: CircleAvatar(
                          radius: 56,
                          backgroundColor: Colors.white,
                          backgroundImage: (photoUrl != null && photoUrl.isNotEmpty)
                              ? NetworkImage(photoUrl)
                              : null,
                          child: (photoUrl == null || photoUrl.isEmpty)
                              ? Text(
                                  name.isNotEmpty ? name[0].toUpperCase() : 'D',
                                  style: AppTextStyles.headlineMedium.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.brand,
                                  ),
                                )
                              : null,
                        ),
                      ),
                      Positioned(
                        bottom: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () =>
                              context.push(DriverRoutePaths.profilePicture),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.brand,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isDark ? AppColors.darkSurfaceRaised : AppColors.lightSurfaceRaised,
                                width: 2.5,
                              ),
                              boxShadow: const [
                                BoxShadow(
                                  color: Color(0x3D000000),
                                  blurRadius: 8,
                                  offset: Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.camera_alt_rounded,
                              color: Colors.white,
                              size: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),

                GlassContainer(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                  child: Column(
                    children: [
                      _InfoRow(
                        icon: Icons.person_outline_rounded,
                        label: 'Full Name',
                        value: name.isNotEmpty ? name : '—',
                      ),
                      _InfoRow(
                        icon: Icons.email_outlined,
                        label: 'Email',
                        value: email.isNotEmpty ? email : '—',
                      ),
                      _InfoRow(
                        icon: Icons.phone_android_rounded,
                        label: 'Phone Number',
                        value: phone.isNotEmpty ? phone : '—',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),

                PrimaryButton(
                  label: 'Edit Profile',
                  onPressed: () =>
                      context.push(DriverRoutePaths.profileBasicInfo),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.brandGlass,
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(
              icon,
              color: AppColors.brand,
              size: 20,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: AppTextStyles.titleMedium.copyWith(
                    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
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
