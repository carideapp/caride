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

/// Minimalist Customer Account & Security Screen styled after the CaRide Profile design standards.
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

      // 1. Delete customer Firestore subcollections & doc
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

      // 3. Sign out
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
          _showRecentLoginRequiredSheet();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete account: ${e.message}'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: AppColors.error,
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
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isDeleting = false);
      }
    }
  }

  void _showRecentLoginRequiredSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 48,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD1D5DB),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.lock_reset_rounded,
                  color: Color(0xFFD97706),
                  size: 28,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Recent Login Required',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'For security reasons, you must log out and sign back in before permanently deleting your account.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? AppColors.textSecondaryDark : const Color(0xFF6B7280),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                  ),
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await customerAuthController.signOut();
                    if (mounted) {
                      context.go(CustomerRoutePaths.welcome);
                    }
                  },
                  child: const Text('Log Out Now', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: TextButton(
                  style: TextButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.textSecondaryDark : const Color(0xFF4B5563),
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

  void _showDeleteConfirmation() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 48,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD1D5DB),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.delete_forever_rounded,
                  color: AppColors.error,
                  size: 28,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Delete Account?',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'This action is permanent and cannot be undone. All your data, wallet balance, and ride history will be permanently erased.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? AppColors.textSecondaryDark : const Color(0xFF6B7280),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _showDoubleConfirmation();
                  },
                  child: const Text('Yes, Proceed to Delete', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: TextButton(
                  style: TextButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.textSecondaryDark : const Color(0xFF4B5563),
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

  void _showDoubleConfirmation() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 48,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD1D5DB),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: AppColors.error,
                  size: 28,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Final Confirmation',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Are you absolutely sure? Click "Delete My Account Permanently" to erase your account forever.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? AppColors.textSecondaryDark : const Color(0xFF6B7280),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _deleteAccount();
                  },
                  child: const Text('Delete My Account Permanently', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: TextButton(
                  style: TextButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                  ),
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(
                    'Keep My Account',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.textSecondaryDark : const Color(0xFF4B5563),
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF111827);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFFAFAFA),
      body: SafeArea(
        child: _isDeleting
            ? const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AppLoader(),
                    SizedBox(height: 16),
                    Text('Deleting account, please wait...'),
                  ],
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 14,
                  bottom: 50,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top App Bar with Circular Back Button
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => context.pop(),
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.darkSurface : Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB),
                              ),
                            ),
                            child: Icon(
                              Icons.arrow_back_ios_new_rounded,
                              size: 18,
                              color: primaryTextColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Text(
                          'Account & Security',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: primaryTextColor,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // ── CARD GROUP 1 (Ride Safety & Contacts) ──
                    Container(
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurface : Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB),
                        ),
                      ),
                      child: Column(
                        children: [
                          _SecurityMenuItem(
                            title: 'Pickup Code Verification',
                            icon: Icons.shield_rounded,
                            isDark: isDark,
                            primaryTextColor: primaryTextColor,
                            onTap: () => showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (_) => DraggableScrollableSheet(
                                expand: false,
                                initialChildSize: 0.50,
                                minChildSize: 0.50,
                                maxChildSize: 0.55,
                                builder: (_, ctrl) => Container(
                                  decoration: BoxDecoration(
                                    color: isDark ? AppColors.darkSurface : Colors.white,
                                    borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                                  ),
                                  child: SingleChildScrollView(
                                    controller: ctrl,
                                    child: const PickupCodeSettingsSheet(),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          _buildDivider(isDark),
                          _SecurityMenuItem(
                            title: 'Trusted Contacts',
                            icon: Icons.people_rounded,
                            isDark: isDark,
                            primaryTextColor: primaryTextColor,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const TrustedContactsScreen(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // ── CARD GROUP 2 (Credentials & Sessions) ──
                    Container(
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurface : Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB),
                        ),
                      ),
                      child: Column(
                        children: [
                          _SecurityMenuItem(
                            title: 'Device Management',
                            icon: Icons.devices_rounded,
                            isDark: isDark,
                            primaryTextColor: primaryTextColor,
                            onTap: () => context.push(CustomerRoutePaths.deviceManagement),
                          ),
                          _buildDivider(isDark),
                          _SecurityMenuItem(
                            title: 'Security PIN',
                            icon: Icons.lock_outline_rounded,
                            isDark: isDark,
                            primaryTextColor: primaryTextColor,
                            badge: _hasPinSet == null
                                ? 'Loading'
                                : (_hasPinSet! ? 'Active' : 'Not Set'),
                            badgeColor: _hasPinSet == true ? AppColors.brand : const Color(0xFFF59E0B),
                            onTap: () async {
                              await context.push(CustomerRoutePaths.securityPin);
                              _checkPinSet();
                            },
                          ),
                          _buildDivider(isDark),
                          _SecurityMenuItem(
                            title: 'Delete Account',
                            icon: Icons.delete_forever_rounded,
                            isDark: isDark,
                            primaryTextColor: AppColors.error,
                            iconColor: AppColors.error,
                            iconBgColor: AppColors.error.withValues(alpha: 0.1),
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
    );
  }

  Widget _buildDivider(bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 68, right: 18),
      child: Divider(
        height: 1,
        color: isDark ? Colors.white10 : const Color(0xFFF3F4F6),
      ),
    );
  }
}

class _SecurityMenuItem extends StatelessWidget {
  const _SecurityMenuItem({
    required this.title,
    required this.icon,
    required this.isDark,
    required this.primaryTextColor,
    required this.onTap,
    this.iconColor,
    this.iconBgColor,
    this.badge,
    this.badgeColor,
    this.showChevron = true,
  });

  final String title;
  final IconData icon;
  final bool isDark;
  final Color primaryTextColor;
  final VoidCallback onTap;
  final Color? iconColor;
  final Color? iconBgColor;
  final String? badge;
  final Color? badgeColor;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final effectiveIconBg = iconBgColor ?? (isDark ? Colors.white10 : const Color(0xFFF3F4F6));
    final effectiveIconColor = iconColor ?? (isDark ? Colors.white70 : const Color(0xFF374151));

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: effectiveIconBg,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: effectiveIconColor, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: primaryTextColor,
                  letterSpacing: -0.2,
                ),
              ),
            ),
            if (badge != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: (badgeColor ?? AppColors.brand).withValues(
                    alpha: 0.12,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  badge!,
                  style: TextStyle(
                    color: badgeColor ?? AppColors.brand,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 6),
            ],
            if (showChevron)
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF9CA3AF),
                size: 22,
              ),
          ],
        ),
      ),
    );
  }
}
