import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:design_system/design_system.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:navigation/navigation.dart';
import 'package:shared_widgets/shared_widgets.dart';
import 'package:caride/core/auth/customer_auth_controller.dart';
import 'package:caride/features/profile/data/security_pin_repository.dart';
import 'package:caride/features/profile/pickup_code_settings_sheet.dart';
import 'package:caride/features/profile/trusted_contacts_screen.dart';

/// Redesigned Customer Account & Security Screen.
class AccountSecurityScreen extends StatefulWidget {
  const AccountSecurityScreen({super.key});

  @override
  State<AccountSecurityScreen> createState() => _AccountSecurityScreenState();
}

class _AccountSecurityScreenState extends State<AccountSecurityScreen> {
  bool _isDeleting = false;
  bool? _hasPinSet;

  @override
  void initState() {
    super.initState();
    _checkPinSet();
  }

  Future<void> _checkPinSet() async {
    try {
      final set = await SecurityPinRepository().hasPinSet();
      if (mounted) {
        setState(() => _hasPinSet = set);
      }
    } catch (_) {}
  }

  Future<void> _deleteAccount() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isDeleting = true);
    try {
      final uid = user.uid;

      // 1. Delete customer Firestore data and subcollections
      final txDocs = await FirebaseFirestore.instance
          .collection('customers')
          .doc(uid)
          .collection('transactions')
          .get();
      for (var doc in txDocs.docs) {
        await doc.reference.delete();
      }
      final addrDocs = await FirebaseFirestore.instance
          .collection('customers')
          .doc(uid)
          .collection('addresses')
          .get();
      for (var doc in addrDocs.docs) {
        await doc.reference.delete();
      }
      final cartDocs = await FirebaseFirestore.instance
          .collection('customers')
          .doc(uid)
          .collection('cart')
          .get();
      for (var doc in cartDocs.docs) {
        await doc.reference.delete();
      }
      await FirebaseFirestore.instance
          .collection('customers')
          .doc(uid)
          .delete();

      // 2. Delete Firebase Auth user
      await user.delete();

      // 3. Sign out of local controller
      await customerAuthController.signOut();

      if (mounted) {
        context.go(CustomerRoutePaths.welcome);
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
                              await customerAuthController.signOut();
                              if (context.mounted) {
                                context.go(CustomerRoutePaths.welcome);
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
                'This action is permanent and cannot be undone. All your data, wallet balance, and ride history will be lost forever.',
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
                      Text('Deleting account, please wait...'),
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
                      // ─── Safety Section ───────────────────────────────
                      const SizedBox(height: AppSpacing.xl),
                      _buildSectionHeader(
                        context: context,
                        title: 'Safety',
                        subtitle: 'Ride verification and emergency contacts',
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      GlassContainer(
                        padding: EdgeInsets.zero,
                        child: Column(
                          children: [
                            _buildMenuItem(
                              context,
                              icon: Icons.shield_rounded,
                              title: 'Pickup Code',
                              subtitle:
                                  'Verify your driver before starting your trip',
                              onTap: () => showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: Colors.transparent,
                                builder: (_) => DraggableScrollableSheet(
                                  expand: false,
                                  initialChildSize: 0.50,
                                  minChildSize: 0.50,
                                  maxChildSize: 0.52,
                                  builder: (_, ctrl) => GlassSurface(
                                    radius: AppRadius.xl,
                                    child: SingleChildScrollView(
                                      controller: ctrl,
                                      child: const PickupCodeSettingsSheet(),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Divider(
                              height: 1,
                              color: isDark
                                  ? AppColors.glassBorderDark
                                  : AppColors.glassBorderLight,
                            ),
                            _buildMenuItem(
                              context,
                              icon: Icons.people_rounded,
                              title: 'Trusted Contacts',
                              subtitle:
                                  'Manage contacts for emergency alerts and trip sharing',
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const TrustedContactsScreen(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // ─── Privacy & Sessions ────────────────────────────
                      const SizedBox(height: AppSpacing.xl),
                      _buildSectionHeader(
                        context: context,
                        title: 'Privacy & Sessions',
                        subtitle:
                            'Control logins, connected devices, and account status',
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      GlassContainer(
                        padding: EdgeInsets.zero,
                        child: Column(
                          children: [
                            _buildMenuItem(
                              context,
                              icon: Icons.devices_rounded,
                              title: 'Device Management',
                              subtitle:
                                  'Review and manage your active login sessions',
                              onTap: () => context.push(
                                CustomerRoutePaths.deviceManagement,
                              ),
                            ),
                            Divider(
                              height: 1,
                              color: isDark
                                  ? AppColors.glassBorderDark
                                  : AppColors.glassBorderLight,
                            ),
                            _buildMenuItem(
                              context,
                              icon: Icons.lock_outline_rounded,
                              title: 'Security PIN',
                              subtitle: _hasPinSet == null
                                  ? 'Loading...'
                                  : (_hasPinSet!
                                        ? 'Change or reset your transaction PIN'
                                        : 'Set a transaction PIN to secure withdrawals'),
                              onTap: () async {
                                await context.push(
                                  CustomerRoutePaths.securityPin,
                                );
                                _checkPinSet();
                              },
                            ),
                            Divider(
                              height: 1,
                              color: isDark
                                  ? AppColors.glassBorderDark
                                  : AppColors.glassBorderLight,
                            ),
                            _buildMenuItem(
                              context,
                              icon: Icons.delete_forever_rounded,
                              title: 'Delete Account',
                              subtitle:
                                  'Permanently erase your credentials and records',
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

  Widget _buildSectionHeader({
    required BuildContext context,
    required String title,
    required String subtitle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [Text(title, style: AppTextStyles.titleMedium)],
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
