import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:design_system/design_system.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:navigation/navigation.dart';
import 'package:shared_widgets/shared_widgets.dart';
import 'package:caride/core/driver/auth/driver_auth_controller.dart';

/// Driver Account & Security Screen featuring deletion confirmation flow.
class DriverAccountSecurityScreen extends StatefulWidget {
  const DriverAccountSecurityScreen({super.key});

  @override
  State<DriverAccountSecurityScreen> createState() =>
      _DriverAccountSecurityScreenState();
}

class _DriverAccountSecurityScreenState
    extends State<DriverAccountSecurityScreen> {
  bool _isDeleting = false;

  Future<void> _deleteAccount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isDeleting = true);
    try {
      final uid = user.uid;

      // 1. Delete driver subcollections & documents from Firestore
      final docs = await FirebaseFirestore.instance
          .collection('drivers')
          .doc(uid)
          .collection('documents')
          .get();
      for (var doc in docs.docs) {
        await doc.reference.delete();
      }

      final vehicle = await FirebaseFirestore.instance
          .collection('drivers')
          .doc(uid)
          .collection('vehicle')
          .get();
      for (var doc in vehicle.docs) {
        await doc.reference.delete();
      }

      final bankAccounts = await FirebaseFirestore.instance
          .collection('drivers')
          .doc(uid)
          .collection('bankAccounts')
          .get();
      for (var doc in bankAccounts.docs) {
        await doc.reference.delete();
      }

      final verificationHistory = await FirebaseFirestore.instance
          .collection('drivers')
          .doc(uid)
          .collection('verificationHistory')
          .get();
      for (var doc in verificationHistory.docs) {
        await doc.reference.delete();
      }

      // Delete presence doc if exists
      await FirebaseFirestore.instance
          .collection('driverPresence')
          .doc(uid)
          .delete()
          .catchError((_) {});

      // Delete driver profile doc
      await FirebaseFirestore.instance
          .collection('drivers')
          .doc(uid)
          .delete();

      // 2. Delete Firebase Auth user
      await user.delete();

      // 3. Sign out driver controller
      await driverAuthController.signOut();

      if (mounted) {
        context.go(DriverRoutePaths.login);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account deleted successfully.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        if (e.code == 'requires-recent-login') {
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
                    Text(
                      'Recent Login Required',
                      style: AppTextStyles.titleLarge.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    const Text(
                      'For security reasons, you must log out and log back in before deleting your account.',
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
                            onPressed: () async {
                              Navigator.pop(context);
                              await driverAuthController.signOut();
                              if (context.mounted) {
                                context.go(DriverRoutePaths.login);
                              }
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
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete account: ${e.message}'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isDeleting = false);
      }
    }
  }

  void _showDeleteConfirmation() {
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
              Text(
                'Delete Account?',
                style: AppTextStyles.titleLarge.copyWith(
                  color: AppColors.error,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              const Text(
                'This action is permanent and cannot be undone. All your driver data, verification documents, earnings history, and profile details will be lost forever.',
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
                      label: 'Proceed',
                      backgroundColor: AppColors.error,
                      onPressed: () {
                        Navigator.pop(context);
                        _showDoubleConfirmation();
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
  }

  void _showDoubleConfirmation() {
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
              Text(
                'Confirm Deletion',
                style: AppTextStyles.titleLarge.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              const Text(
                'Are you absolutely sure? Click confirm to proceed with final account deletion.',
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
                      label: 'DELETE',
                      backgroundColor: AppColors.error,
                      onPressed: () {
                        Navigator.pop(context);
                        _deleteAccount();
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
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.darkBackground
          : AppColors.lightBackground,
      appBar: GlassAppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
        title: 'Account & Security',
      ),
      body: SafeArea(
        child: ResponsiveContainer(
          child: _isDeleting
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AppLoader(),
                      SizedBox(height: AppSpacing.md),
                      Text('Deleting driver account, please wait...'),
                    ],
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.pagePadding,
                    vertical: AppSpacing.lg,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Account Management',
                        style: AppTextStyles.titleMedium,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      GlassContainer(
                        padding: EdgeInsets.zero,
                        child: Column(
                          children: [
                            _buildMenuItem(
                              context,
                              icon: Icons.delete_forever_rounded,
                              title: 'Delete Account',
                              subtitle:
                                  'Permanently erase your driver account and records',
                              textColor: AppColors.error,
                              iconColor: AppColors.error,
                              showChevron: false,
                              onTap: _showDeleteConfirmation,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    Color? textColor,
    Color? iconColor,
    bool showChevron = true,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Padding(
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
                  color: (iconColor ?? AppColors.brand).withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(
                  icon,
                  color: iconColor ?? AppColors.brand,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.bodyLarge.copyWith(
                        fontWeight: FontWeight.w700,
                        color: textColor,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              if (showChevron)
                Icon(
                  Icons.chevron_right_rounded,
                  color: isDark
                      ? AppColors.textTertiaryDark
                      : AppColors.textTertiaryLight,
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
