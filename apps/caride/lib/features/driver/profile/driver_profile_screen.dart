import 'package:caride/app/theme_mode_controller.dart';
import 'package:caride/core/driver/auth/driver_auth_controller.dart';
import 'package:caride/core/driver/models/driver_profile.dart';
import 'package:caride/core/driver/models/vehicle_info.dart';
import 'package:caride/features/driver/auth/data/driver_profile_repository.dart';
import 'package:caride/features/driver/profile/widgets/vehicle_info_requirement_dialog.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:navigation/navigation.dart';

/// Redesigned Driver Account Screen matching the modern emerald hero card
/// and grouped section layout from the design specifications.
class DriverProfileScreen extends StatefulWidget {
  const DriverProfileScreen({super.key});

  @override
  State<DriverProfileScreen> createState() => _DriverProfileScreenState();
}

class _DriverProfileScreenState extends State<DriverProfileScreen> {
  final _profileRepo = DriverProfileRepository();

  void _showLogoutBottomSheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
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
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : const Color(0xFFE5E7EB),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.logout_rounded,
                  color: AppColors.error,
                  size: 28,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Sign Out',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Are you sure you want to sign out? You will need to sign in again to use your driver account.',
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
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.error,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(26)),
                  ),
                  onPressed: () async {
                    Navigator.of(sheetContext).pop();
                    await driverAuthController.signOut();
                    if (!context.mounted) return;
                    context.go(DriverRoutePaths.login);
                  },
                  child: const Text('Yes, Sign Out',
                      style:
                          TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: TextButton(
                  style: TextButton.styleFrom(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(26)),
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

  void _showAppearanceBottomSheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) {
        ThemeMode tempMode = customerThemeMode.value;

        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 24,
                  right: 24,
                  top: 16,
                  bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
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
                    Text(
                      'App Appearance',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Choose how CaRide looks on your device',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : const Color(0xFF6B7280),
                      ),
                    ),
                    const SizedBox(height: 24),
                    _buildThemeOption(
                      title: 'System Default',
                      icon: Icons.brightness_auto_rounded,
                      mode: ThemeMode.system,
                      selectedMode: tempMode,
                      isDark: isDark,
                      onTap: () {
                        setSheetState(() => tempMode = ThemeMode.system);
                        customerThemeMode.setTheme(ThemeMode.system);
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildThemeOption(
                      title: 'Light Mode',
                      icon: Icons.light_mode_rounded,
                      mode: ThemeMode.light,
                      selectedMode: tempMode,
                      isDark: isDark,
                      onTap: () {
                        setSheetState(() => tempMode = ThemeMode.light);
                        customerThemeMode.setTheme(ThemeMode.light);
                      },
                    ),
                    const SizedBox(height: 12),
                    _buildThemeOption(
                      title: 'Dark Mode',
                      icon: Icons.dark_mode_rounded,
                      mode: ThemeMode.dark,
                      selectedMode: tempMode,
                      isDark: isDark,
                      onTap: () {
                        setSheetState(() => tempMode = ThemeMode.dark);
                        customerThemeMode.setTheme(ThemeMode.dark);
                      },
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.brand,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(26)),
                        ),
                        onPressed: () => Navigator.of(sheetContext).pop(),
                        child: const Text('Done',
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildThemeOption({
    required String title,
    required IconData icon,
    required ThemeMode mode,
    required ThemeMode selectedMode,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    final isSelected = mode == selectedMode;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.brand.withValues(alpha: 0.1)
              : (isDark
                  ? Colors.white.withValues(alpha: 0.04)
                  : const Color(0xFFF9FAFB)),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppColors.brand
                : (isDark
                    ? AppColors.glassBorderDark
                    : const Color(0xFFE5E7EB)),
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.brand
                    : (isDark ? Colors.white10 : const Color(0xFFF3F4F6)),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: isSelected
                    ? Colors.white
                    : (isDark ? Colors.white70 : const Color(0xFF374151)),
                size: 18,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  color: isDark ? Colors.white : const Color(0xFF111827),
                ),
              ),
            ),
            Icon(
              isSelected
                  ? Icons.radio_button_checked_rounded
                  : Icons.radio_button_off_rounded,
              color: isSelected
                  ? AppColors.brand
                  : (isDark ? Colors.white30 : const Color(0xFF9CA3AF)),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF111827);
    final uid = driverAuthController.currentUid;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : const Color(0xFFF9FAFB),
      body: SafeArea(
        child: uid != null
            ? StreamBuilder<DriverProfile?>(
                stream: _profileRepo.streamDriverProfile(uid),
                builder: (context, snapshot) => _buildScrollBody(
                  context,
                  uid: uid,
                  profile: snapshot.data,
                  isDark: isDark,
                  primaryTextColor: primaryTextColor,
                ),
              )
            : _buildScrollBody(
                context,
                uid: null,
                profile: null,
                isDark: isDark,
                primaryTextColor: primaryTextColor,
              ),
      ),
    );
  }

  Widget _buildScrollBody(
    BuildContext context, {
    required String? uid,
    required DriverProfile? profile,
    required bool isDark,
    required Color primaryTextColor,
  }) {
    final name = profile?.fullName.trim().isNotEmpty == true
        ? profile!.fullName.trim()
        : 'Driver';
    final phone = profile?.phone.isNotEmpty == true
        ? profile!.phone
        : (profile?.email.isNotEmpty == true
            ? profile!.email
            : (driverAuthController.currentEmail ?? ''));
    final photoUrl = profile?.profilePhotoUrl ?? '';
    final cardBg = isDark ? AppColors.darkSurface : Colors.white;
    final borderColor =
        isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB);

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
                                  errorBuilder: (_, __, ___) => const Icon(
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
                              name.toUpperCase(),
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
                              phone.isNotEmpty ? phone : 'CaRide Driver',
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
                            context.push(DriverRoutePaths.profileDetail),
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
                        onTap: () => context.push(DriverRoutePaths.wallet),
                      ),
                      _buildDivider(isDark),
                      _ProfileMenuItem(
                        title: 'Bank Account Details',
                        icon: Icons.credit_card_outlined,
                        isDark: isDark,
                        primaryTextColor: primaryTextColor,
                        onTap: () =>
                            context.push(DriverRoutePaths.walletBankAccount),
                      ),
                      _buildDivider(isDark),
                      _ProfileMenuItem(
                        title: 'Referral Program',
                        icon: Icons.person_add_alt_1_outlined,
                        isDark: isDark,
                        primaryTextColor: primaryTextColor,
                        onTap: () => context.push(DriverRoutePaths.referral),
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
                        title: 'Vehicle Information',
                        icon: Icons.directions_car_outlined,
                        isDark: isDark,
                        primaryTextColor: primaryTextColor,
                        onTap: () =>
                            context.push(DriverRoutePaths.profileVehicle),
                      ),
                      _buildDivider(isDark),
                      if (uid != null)
                        StreamBuilder<VehicleInfo?>(
                          stream: _profileRepo.streamVehicleInfo(uid),
                          builder: (context, vehicleSnapshot) {
                            final vehicle = vehicleSnapshot.data;
                            return _ProfileMenuItem(
                              title: 'Documents',
                              icon: Icons.folder_copy_outlined,
                              isDark: isDark,
                              primaryTextColor: primaryTextColor,
                              onTap: () {
                                if (vehicle == null) {
                                  showVehicleInfoRequiredDialog(context);
                                  return;
                                }
                                context.push(DriverRoutePaths.profileDocuments);
                              },
                            );
                          },
                        )
                      else
                        _ProfileMenuItem(
                          title: 'Documents',
                          icon: Icons.folder_copy_outlined,
                          isDark: isDark,
                          primaryTextColor: primaryTextColor,
                          onTap: () => showVehicleInfoRequiredDialog(context),
                        ),
                      _buildDivider(isDark),
                      _ProfileMenuItem(
                        title: 'Account & Security',
                        icon: Icons.shield_outlined,
                        isDark: isDark,
                        primaryTextColor: primaryTextColor,
                        onTap: () =>
                            context.push(DriverRoutePaths.accountSecurity),
                      ),
                      _buildDivider(isDark),
                      _ProfileMenuItem(
                        title: 'App Appearance',
                        icon: Icons.visibility_outlined,
                        isDark: isDark,
                        primaryTextColor: primaryTextColor,
                        onTap: () => _showAppearanceBottomSheet(context),
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
                            context.push(DriverRoutePaths.profileRatings),
                      ),
                      _buildDivider(isDark),
                      _ProfileMenuItem(
                        title: 'Assigned Rentals',
                        icon: Icons.car_rental_rounded,
                        isDark: isDark,
                        primaryTextColor: primaryTextColor,
                        onTap: () =>
                            context.push(DriverRoutePaths.rentalBookings),
                      ),
                      _buildDivider(isDark),
                      _ProfileMenuItem(
                        title: 'Driver Tiers',
                        icon: Icons.workspace_premium_outlined,
                        isDark: isDark,
                        primaryTextColor: primaryTextColor,
                        badge: (profile?.tier ?? 'bronze').toUpperCase(),
                        badgeColor: AppColors.brand,
                        onTap: () =>
                            context.push(DriverRoutePaths.profileTiers),
                      ),
                      if (profile?.linkedFleetIds.isNotEmpty == true) ...[
                        _buildDivider(isDark),
                        _ProfileMenuItem(
                          title: 'My Fleet Managers',
                          icon: Icons.business_rounded,
                          isDark: isDark,
                          primaryTextColor: primaryTextColor,
                          badge: '${profile!.linkedFleetIds.length}',
                          badgeColor: AppColors.brand,
                          onTap: () =>
                              context.push(DriverRoutePaths.linkedFleets),
                        ),
                      ],
                      _buildDivider(isDark),
                      _ProfileMenuItem(
                        title: 'Help & FAQs',
                        icon: Icons.help_outline_rounded,
                        isDark: isDark,
                        primaryTextColor: primaryTextColor,
                        onTap: () => context.push(DriverRoutePaths.helpFaq),
                      ),
                      _buildDivider(isDark),
                      _ProfileMenuItem(
                        title: 'Privacy Policy & Legal',
                        icon: Icons.privacy_tip_outlined,
                        isDark: isDark,
                        primaryTextColor: primaryTextColor,
                        onTap: () =>
                            context.push(DriverRoutePaths.privacyPolicy),
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
                      _ProfileMenuItem(
                        title: 'Switch to Passenger Mode',
                        icon: Icons.directions_walk_rounded,
                        isDark: isDark,
                        primaryTextColor: primaryTextColor,
                        onTap: () =>
                            context.push(DriverRoutePaths.becomeCustomer),
                      ),
                      _buildDivider(isDark),
                      _ProfileMenuItem(
                        title: 'Sign Out',
                        icon: Icons.logout_rounded,
                        isDark: isDark,
                        primaryTextColor: AppColors.error,
                        iconColor: AppColors.error,
                        iconBgColor: AppColors.error.withValues(alpha: 0.1),
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
    this.badge,
    this.badgeColor,
    this.iconColor,
    this.iconBgColor,
    this.showChevron = true,
  });

  final String title;
  final IconData icon;
  final bool isDark;
  final Color primaryTextColor;
  final VoidCallback onTap;
  final String? badge;
  final Color? badgeColor;
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
            if (badge != null) ...[
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (badgeColor ?? AppColors.brand).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  badge!,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: badgeColor ?? AppColors.brand,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],
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
