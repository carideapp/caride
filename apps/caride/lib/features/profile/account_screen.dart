import 'package:caride/app/theme_mode_controller.dart';
import 'package:caride/core/auth/customer_auth_controller.dart';
import 'package:design_system/design_system.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:navigation/navigation.dart';

/// Redesigned Customer Account Screen matching the modern emerald hero card
/// and grouped section layout from the design specifications.
class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  @override
  void initState() {
    super.initState();
    customerThemeMode.addListener(_handleThemeChanged);
  }

  @override
  void dispose() {
    customerThemeMode.removeListener(_handleThemeChanged);
    super.dispose();
  }

  void _handleThemeChanged() {
    if (mounted) setState(() {});
  }

  void _showLogoutBottomSheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 12,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 28,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Drag Handle
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.logout_rounded,
                  color: AppColors.error,
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Sign Out',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : const Color(0xFF111827),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Are you sure you want to sign out of your account?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark
                      ? AppColors.textSecondaryDark
                      : const Color(0xFF6B7280),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  onPressed: () async {
                    Navigator.of(sheetContext).pop();
                    await customerAuthController.signOut();
                    if (!context.mounted) return;
                    context.go(CustomerRoutePaths.welcome);
                  },
                  child: const Text(
                    'Yes, Sign Out',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: TextButton(
                  style: TextButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  onPressed: () => Navigator.of(sheetContext).pop(),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : const Color(0xFF4B5563),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF111827);
    final borderColor =
        isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB);
    final cardBg = isDark ? AppColors.darkSurface : Colors.white;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : const Color(0xFFF9FAFB),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: customerAuthController,
          builder: (context, _) {
            final profile = customerAuthController.currentProfile;
            final fullName = (profile?.fullName.trim().isNotEmpty ?? false)
                ? profile!.fullName.trim()
                : (FirebaseAuth.instance.currentUser?.displayName?.isNotEmpty ?? false
                    ? FirebaseAuth.instance.currentUser!.displayName!
                    : 'CaRide User');
            final phone = (profile?.phone.trim().isNotEmpty ?? false)
                ? profile!.phone.trim()
                : (FirebaseAuth.instance.currentUser?.phoneNumber ??
                    FirebaseAuth.instance.currentUser?.email ??
                    '');
            final photoUrl = profile?.photoUrl ??
                FirebaseAuth.instance.currentUser?.photoURL ??
                '';

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Header UI: Clean Bold Account Title ──
                Padding(
                  padding:
                      const EdgeInsets.only(left: 20, right: 20, top: 16, bottom: 8),
                  child: Text(
                    'Account',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: primaryTextColor,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),

                // ── Scrollable Body ──
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(
                      left: 16,
                      right: 16,
                      top: 6,
                      bottom: 40,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── Emerald Hero Card (Avatar, Name, Phone & Edit Pencil) ──
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 16),
                          decoration: BoxDecoration(
                            color: AppColors.brand,
                            borderRadius: BorderRadius.circular(22),
                          ),
                          child: Row(
                            children: [
                              // Circular White Avatar with Emerald Icon or Photo
                              Container(
                                width: 58,
                                height: 58,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white,
                                ),
                                child: ClipOval(
                                  child: photoUrl.isNotEmpty
                                      ? Image.network(
                                          photoUrl,
                                          fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) =>
                                              const Icon(
                                            Icons.person_rounded,
                                            color: AppColors.brand,
                                            size: 34,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.person_rounded,
                                          color: AppColors.brand,
                                          size: 34,
                                        ),
                                ),
                              ),
                              const SizedBox(width: 14),

                              // Name & Phone
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      fullName.toUpperCase(),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.3,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      phone.isNotEmpty ? phone : 'Add Phone Number',
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.90),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),

                              // Edit Pencil Action
                              IconButton(
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                icon: const Icon(
                                  Icons.edit_rounded,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                onPressed: () =>
                                    context.push(CustomerRoutePaths.editProfile),
                              ),
                            ],
                          ),
                        ),

                        // ── SECTION 1: Finances & Activity ──
                        _buildSectionHeader('Finances & Activity', isDark),
                        Container(
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: borderColor),
                          ),
                          child: Column(
                            children: [
                              _ProfileMenuItem(
                                title: 'My CaRide Wallet',
                                icon: Icons.account_balance_wallet_outlined,
                                isDark: isDark,
                                primaryTextColor: primaryTextColor,
                                onTap: () =>
                                    context.push(CustomerRoutePaths.wallet),
                              ),
                              _buildDivider(isDark),
                              _ProfileMenuItem(
                                title: 'Payment Methods',
                                icon: Icons.credit_card_outlined,
                                isDark: isDark,
                                primaryTextColor: primaryTextColor,
                                onTap: () => context
                                    .push(CustomerRoutePaths.viewPaymentMethods),
                              ),
                              _buildDivider(isDark),
                              _ProfileMenuItem(
                                title: 'Referral Program',
                                icon: Icons.person_add_alt_1_outlined,
                                isDark: isDark,
                                primaryTextColor: primaryTextColor,
                                onTap: () =>
                                    context.push(CustomerRoutePaths.referral),
                              ),
                            ],
                          ),
                        ),

                        // ── SECTION 2: Preferences & Settings ──
                        _buildSectionHeader('Preferences & Settings', isDark),
                        Container(
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: borderColor),
                          ),
                          child: Column(
                            children: [
                              _ProfileMenuItem(
                                title: 'Saved Addresses',
                                icon: Icons.location_on_outlined,
                                isDark: isDark,
                                primaryTextColor: primaryTextColor,
                                onTap: () => context
                                    .push(CustomerRoutePaths.savedAddresses),
                              ),
                              _buildDivider(isDark),
                              _ProfileMenuItem(
                                title: 'Account & Security',
                                icon: Icons.shield_outlined,
                                isDark: isDark,
                                primaryTextColor: primaryTextColor,
                                onTap: () => context
                                    .push(CustomerRoutePaths.accountSecurity),
                              ),
                              _buildDivider(isDark),
                              _ProfileMenuItem(
                                title: 'App Appearance',
                                icon: Icons.visibility_outlined,
                                isDark: isDark,
                                primaryTextColor: primaryTextColor,
                                onTap: () => context
                                    .push(CustomerRoutePaths.appAppearance),
                              ),
                            ],
                          ),
                        ),

                        // ── SECTION 3: Activity & Support ──
                        _buildSectionHeader('Activity & Support', isDark),
                        Container(
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: borderColor),
                          ),
                          child: Column(
                            children: [
                              _ProfileMenuItem(
                                title: 'Rating & Reviews',
                                icon: Icons.star_outline_rounded,
                                isDark: isDark,
                                primaryTextColor: primaryTextColor,
                                onTap: () =>
                                    context.push(CustomerRoutePaths.ratings),
                              ),
                              _buildDivider(isDark),
                              _ProfileMenuItem(
                                title: 'Monitor Trip',
                                icon: Icons.location_searching_rounded,
                                isDark: isDark,
                                primaryTextColor: primaryTextColor,
                                onTap: () => context
                                    .push(CustomerRoutePaths.monitorTripEntry),
                              ),
                              _buildDivider(isDark),
                              _ProfileMenuItem(
                                title: 'Data & Analytics',
                                icon: Icons.bar_chart_rounded,
                                isDark: isDark,
                                primaryTextColor: primaryTextColor,
                                onTap: () => context
                                    .push(CustomerRoutePaths.dataAnalytics),
                              ),
                              _buildDivider(isDark),
                              _ProfileMenuItem(
                                title: 'Help & Support',
                                icon: Icons.help_outline_rounded,
                                isDark: isDark,
                                primaryTextColor: primaryTextColor,
                                onTap: () =>
                                    context.push(CustomerRoutePaths.helpSupport),
                              ),
                              _buildDivider(isDark),
                              _ProfileMenuItem(
                                title: 'Legal & Privacy Policy',
                                icon: Icons.privacy_tip_outlined,
                                isDark: isDark,
                                primaryTextColor: primaryTextColor,
                                onTap: () =>
                                    context.push(CustomerRoutePaths.legal),
                              ),
                            ],
                          ),
                        ),

                        // ── SECTION 4: Account Actions ──
                        _buildSectionHeader('Account Actions', isDark),
                        Container(
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: borderColor),
                          ),
                          child: Column(
                            children: [
                              if (customerAuthController.driverExists)
                                _ProfileMenuItem(
                                  title: 'Switch to Driver Mode',
                                  icon: Icons.directions_car_rounded,
                                  isDark: isDark,
                                  primaryTextColor: primaryTextColor,
                                  onTap: () async {
                                    await customerAuthController
                                        .switchRole('driver');
                                    if (!context.mounted) return;
                                    context.go(DriverRoutePaths.home);
                                  },
                                )
                              else
                                _ProfileMenuItem(
                                  title: 'Become a Driver',
                                  icon: Icons.assignment_ind_outlined,
                                  isDark: isDark,
                                  primaryTextColor: primaryTextColor,
                                  onTap: () => context
                                      .push(CustomerRoutePaths.becomeDriver),
                                ),
                              _buildDivider(isDark),
                              _ProfileMenuItem(
                                title: 'Sign Out',
                                icon: Icons.logout_rounded,
                                isDark: isDark,
                                primaryTextColor: AppColors.error,
                                iconColor: AppColors.error,
                                iconBgColor:
                                    AppColors.error.withValues(alpha: 0.1),
                                showChevron: false,
                                onTap: () => _showLogoutBottomSheet(context),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),
                        Center(
                          child: Text(
                            'Version 1.0.4 (Build 45)',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? AppColors.textTertiaryDark
                                  : AppColors.textTertiaryLight,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8, top: 22),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: isDark ? AppColors.textSecondaryDark : const Color(0xFF4B5563),
          letterSpacing: -0.1,
        ),
      ),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 68, right: 16),
      child: Divider(
        height: 1,
        thickness: 1,
        color: isDark ? Colors.white10 : const Color(0xFFF3F4F6),
      ),
    );
  }
}

class _ProfileMenuItem extends StatelessWidget {
  const _ProfileMenuItem({
    required this.title,
    required this.icon,
    required this.isDark,
    required this.primaryTextColor,
    required this.onTap,
    this.iconColor,
    this.iconBgColor,
    this.showChevron = true,
  });

  final String title;
  final IconData icon;
  final bool isDark;
  final Color primaryTextColor;
  final VoidCallback onTap;
  final Color? iconColor;
  final Color? iconBgColor;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final effectiveIconBg = iconBgColor ??
        (isDark
            ? AppColors.brand.withValues(alpha: 0.18)
            : const Color(0xFFE8F5E9));
    final effectiveIconColor = iconColor ?? AppColors.brand;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: effectiveIconBg,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: effectiveIconColor, size: 20),
            ),
            const SizedBox(width: 14),
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
            if (showChevron)
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF9CA3AF),
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}
