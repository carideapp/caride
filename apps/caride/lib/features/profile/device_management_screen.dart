import 'dart:io';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:navigation/navigation.dart';
import 'package:shared_widgets/shared_widgets.dart';
import 'package:caride/core/auth/customer_auth_controller.dart';

/// Redesigned Customer Device Management Screen.
class DeviceManagementScreen extends StatefulWidget {
  const DeviceManagementScreen({super.key});

  @override
  State<DeviceManagementScreen> createState() => _DeviceManagementScreenState();
}

class _DeviceManagementScreenState extends State<DeviceManagementScreen> {
  bool _isLoggingOutAll = false;

  Future<void> _logoutAll() async {
    setState(() => _isLoggingOutAll = true);
    try {
      await customerAuthController.signOut();
      if (mounted) {
        context.go(CustomerRoutePaths.welcome);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to log out: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoggingOutAll = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final deviceOs = Platform.isAndroid ? 'Android Device' : 'iOS Device';

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: GlassAppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
        title: 'Device Management',
      ),
      body: SafeArea(
        child: ResponsiveContainer(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.pagePadding,
              vertical: AppSpacing.lg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader(
                  context: context,
                  title: 'Active Devices',
                  subtitle: 'Below is a list of devices that are currently logged into your account.',
                ),
                const SizedBox(height: AppSpacing.sm),
                GlassContainer(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.brandGlass,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.phone_android_rounded,
                          color: AppColors.brand,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              deviceOs,
                              style: AppTextStyles.bodyLarge.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 2),
                            const Text(
                              'Current Device • Active now',
                              style: TextStyle(
                                color: AppColors.brand,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                if (_isLoggingOutAll)
                  const Center(child: AppLoader())
                else
                  SizedBox(
                    width: double.infinity,
                    child: SecondaryButton(
                      label: 'Log Out of All Other Devices',
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            backgroundColor: Colors.transparent,
                            contentPadding: EdgeInsets.zero,
                            content: GlassSurface(
                              radius: AppRadius.lg,
                              padding: const EdgeInsets.all(AppSpacing.xl),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('Log Out?', style: AppTextStyles.titleLarge.copyWith(fontWeight: FontWeight.bold)),
                                  const SizedBox(height: AppSpacing.md),
                                  const Text(
                                    'Are you sure you want to log out of all other sessions? You will need to log back in on those devices.',
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: AppSpacing.xl),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: SecondaryButton(
                                          label: 'Cancel',
                                          onPressed: () => Navigator.pop(context),
                                        ),
                                      ),
                                      const SizedBox(width: AppSpacing.sm),
                                      Expanded(
                                        child: PrimaryButton(
                                          label: 'Log Out',
                                          backgroundColor: AppColors.error,
                                          onPressed: () {
                                            Navigator.pop(context);
                                            _logoutAll();
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader({
    required BuildContext context,
    required String title,
    required String subtitle,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTextStyles.titleMedium,
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: AppTextStyles.bodySmall.copyWith(
            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
          ),
        ),
      ],
    );
  }
}
