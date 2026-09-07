import 'package:caride/core/auth/customer_auth_controller.dart';
import 'package:caride/features/profile/data/account_repository.dart';

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:navigation/navigation.dart';
import 'package:shared_widgets/shared_widgets.dart';

/// Redesigned Passenger Profile screen with Apple Liquid Glass listing segments.
class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final AccountRepository _accountRepository = AccountRepository();





  void _showLogoutBottomSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return BottomSheetShell(
          title: 'Sign Out',
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pagePadding),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: AppSpacing.md),
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.logout_rounded,
                    color: AppColors.error,
                    size: 28,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Are you sure you want to sign out?',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.titleMedium,
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  'You will need to sign in again to use your account.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodySmall,
                ),
                const SizedBox(height: AppSpacing.xl),
                Row(
                  children: [
                    Expanded(
                      child: SecondaryButton(
                        label: 'Cancel',
                        onPressed: () => Navigator.of(sheetContext).pop(),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: PrimaryButton(
                        label: 'Yes, Sign Out',
                        backgroundColor: AppColors.error,
                        onPressed: () async {
                          Navigator.of(sheetContext).pop();
                          await customerAuthController.signOut();
                          if (!context.mounted) return;
                          context.go(CustomerRoutePaths.welcome);
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildProfileHero({
    required BuildContext context,
    required String fullName,
    required String subtitle,
    required String photoUrl,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            AppColors.brandLight,
            AppColors.brand,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppRadius.xl),
        boxShadow: AppShadows.glowDark,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.22),
              shape: BoxShape.circle,
            ),
            child: CircleAvatar(
              radius: 36,
              backgroundColor: Colors.white,
              backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
              child: photoUrl.isEmpty
                  ? const Icon(
                      Icons.person_rounded,
                      size: 32,
                      color: AppColors.brand,
                    )
                  : null,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                Text(
                  fullName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.88),
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => context.push(CustomerRoutePaths.editProfile),
            icon: const Icon(Icons.edit_rounded, color: Colors.white),
            tooltip: 'Edit Profile',
          ),
        ],
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
      children: [
        Text(
          title,
          style: AppTextStyles.titleMedium,
        ),
      ],
    );
  }

  Widget _buildMenuSection({
    required BuildContext context,
    required List<Widget> children,
  }) {
    return GlassContainer(
      padding: EdgeInsets.zero,
      child: Column(children: children),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    Color? textColor,
    Color? iconColor,
    bool showChevron = true,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (iconColor ?? AppColors.brand).withValues(alpha: 0.10),
                  shape: BoxShape.circle,
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
              trailing ??
                  (showChevron
                      ? Icon(
                          Icons.chevron_right_rounded,
                          color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
                          size: 20,
                        )
                      : const SizedBox.shrink()),
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
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: GlassAppBar(
        automaticallyImplyLeading: false,
        title: 'Account',
      ),
      body: SafeArea(
        child: ResponsiveContainer(
          child: StreamBuilder<AccountProfile?>(
            stream: _accountRepository.watchProfile(),
            builder: (context, profileSnap) {
              if (!profileSnap.hasData) {
                return const Center(child: AppLoader());
              }
              final profile = profileSnap.data;
              final fullName = profile?.fullName ?? 'CaRide User';
              final photoUrl = profile?.photoUrl ?? '';
              final subtitle = profile?.phone.isNotEmpty == true
                  ? profile!.phone
                  : (profile?.email ?? 'CaRide Member');

              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.pagePadding,
                  vertical: AppSpacing.lg,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildProfileHero(
                      context: context,
                      fullName: fullName,
                      subtitle: subtitle,
                      photoUrl: photoUrl,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _buildSectionHeader(
                      context: context,
                      title: 'Finances & Activity',
                      subtitle: 'Your wallet, cards, and special promotions',
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _buildMenuSection(
                      context: context,
                      children: [
                        _buildMenuItem(
                          context,
                          icon: Icons.account_balance_wallet_outlined,
                          title: 'My CaRide Wallet',
                          onTap: () => context.push(CustomerRoutePaths.wallet),
                        ),
                        _buildMenuItem(
                          context,
                          icon: Icons.credit_card_outlined,
                          title: 'Payment Methods',
                          subtitle: 'Manage cards and active payment options',
                          onTap: () => context.push(CustomerRoutePaths.viewPaymentMethods),
                        ),
                        _buildMenuItem(
                          context,
                          icon: Icons.group_add_outlined,
                          title: 'Referral Program',
                          subtitle: 'Invite your friends and earn premium bonuses',
                          onTap: () => context.push(CustomerRoutePaths.referral),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _buildSectionHeader(
                      context: context,
                      title: 'Preferences & Settings',
                      subtitle: 'Personalize profile, security, and app looks',
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _buildMenuSection(
                      context: context,
                      children: [
                        _buildMenuItem(
                          context,
                          icon: Icons.location_on_outlined,
                          title: 'Saved Addresses',
                          subtitle: 'Manage your primary home, work, and saved places',
                          onTap: () => context.push(CustomerRoutePaths.savedAddresses),
                        ),
                        _buildMenuItem(
                          context,
                          icon: Icons.shield_outlined,
                          title: 'Account & Security',
                          subtitle: 'Set up login methods and password details',
                          onTap: () => context.push(CustomerRoutePaths.accountSecurity),
                        ),
                        _buildMenuItem(
                          context,
                          icon: Icons.visibility_outlined,
                          title: 'App Appearance',
                          subtitle: 'Toggle dark mode and viewing configurations',
                          onTap: () => context.push(CustomerRoutePaths.appAppearance),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _buildSectionHeader(
                      context: context,
                      title: 'Activity & Support',
                      subtitle: 'Check history, review data, and get support',
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _buildMenuSection(
                      context: context,
                      children: [
                        _buildMenuItem(
                          context,
                          icon: Icons.star_outline_rounded,
                          title: 'Rating & Reviews',
                          subtitle: 'View ratings and reviews from past rides',
                          onTap: () => context.push(CustomerRoutePaths.ratings),
                        ),
                        _buildMenuItem(
                          context,
                          icon: Icons.share_location_rounded,
                          title: 'Monitor Trip',
                          subtitle: 'Track your friend\'s active ride using a code',
                          onTap: () => context.push(CustomerRoutePaths.monitorTripEntry),
                        ),
                        _buildMenuItem(
                          context,
                          icon: Icons.insert_chart_outlined,
                          title: 'Data & Analytics',
                          subtitle: 'Manage storage and analytical summaries',
                          onTap: () => context.push(CustomerRoutePaths.dataAnalytics),
                        ),
                        _buildMenuItem(
                          context,
                          icon: Icons.description_outlined,
                          title: 'Help & Support',
                          subtitle: 'Browse articles or open a support ticket',
                          onTap: () => context.push(CustomerRoutePaths.helpSupport),
                        ),
                        _buildMenuItem(
                          context,
                          icon: Icons.gavel_outlined,
                          title: 'Legal',
                          subtitle: 'Terms of Use and Privacy Policy',
                          onTap: () => context.push(CustomerRoutePaths.legal),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _buildSectionHeader(
                      context: context,
                      title: 'Account Mode',
                      subtitle: 'Switch or expand your account modes',
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _buildMenuSection(
                      context: context,
                      children: [
                        if (customerAuthController.driverExists)
                          _buildMenuItem(
                            context,
                            icon: Icons.drive_eta_rounded,
                            title: 'Switch to Driver Mode',
                            subtitle: 'Access earnings, requests, and vehicle settings',
                            iconColor: AppColors.brand,
                            onTap: () async {
                              await customerAuthController.switchRole('driver');
                              if (!context.mounted) return;
                              context.go(DriverRoutePaths.home);
                            },
                          )
                        else
                          _buildMenuItem(
                            context,
                            icon: Icons.assignment_ind_outlined,
                            title: 'Become a Driver',
                            subtitle: 'Submit vehicle documents and start earning',
                            iconColor: AppColors.brand,
                            onTap: () {
                              context.push(CustomerRoutePaths.becomeDriver);
                            },
                          ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    _buildSectionHeader(
                      context: context,
                      title: 'Account Session',
                      subtitle: 'Log out securely from this device',
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    _buildMenuSection(
                      context: context,
                      children: [
                        _buildMenuItem(
                          context,
                          icon: Icons.logout_rounded,
                          title: 'Logout',
                          subtitle: 'Sign out of your CaRide account safely',
                          textColor: AppColors.error,
                          iconColor: AppColors.error,
                          showChevron: false,
                          onTap: () => _showLogoutBottomSheet(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xl),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
