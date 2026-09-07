import 'package:design_system/design_system.dart';
import 'package:caride/app/theme_mode_controller.dart';
import 'package:caride/core/driver/auth/driver_auth_controller.dart';
import 'package:caride/core/auth/customer_auth_controller.dart';
import 'package:caride/core/driver/models/driver_document.dart';
import 'package:caride/core/driver/models/driver_profile.dart';
import 'package:caride/core/driver/models/vehicle_info.dart';
import 'package:caride/core/driver/verification/driver_verification_config.dart';
import 'package:caride/features/driver/auth/data/driver_profile_repository.dart';
import 'package:caride/features/driver/profile/data/driver_document_repository.dart';
import 'package:caride/features/driver/profile/widgets/vehicle_info_requirement_dialog.dart';
import 'package:caride/features/driver/wallet/data/driver_wallet_repository.dart';
import 'package:flutter/material.dart';
import 'package:navigation/navigation.dart';
import 'package:shared_widgets/shared_widgets.dart';

/// Redesigned Driver Profile screen featuring high-fidelity Liquid Glass cards,
/// grouped sections, status headers, and an iOS-style bottom sheet logout dialog.
class DriverProfileScreen extends StatefulWidget {
  const DriverProfileScreen({super.key});

  @override
  State<DriverProfileScreen> createState() => _DriverProfileScreenState();
}

class _DriverProfileScreenState extends State<DriverProfileScreen> {
  final _profileRepo = DriverProfileRepository();
  final _documentRepo = DriverDocumentRepository();
  final _walletRepo = DriverWalletRepository();

  void _showLogoutBottomSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return BottomSheetShell(
          title: 'Sign Out',
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
                'You will need to sign in again to use your driver account.',
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
                        await driverAuthController.signOut();
                        if (!context.mounted) return;
                        context.go(DriverRoutePaths.login);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProfileHero(
    BuildContext context, {
    required String name,
    required String subtitle,
    required String? photoUrl,
    required String? uid,
    required DriverProfile? profile,
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
          Stack(
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
                  backgroundImage: (photoUrl != null && photoUrl.isNotEmpty)
                      ? NetworkImage(photoUrl)
                      : null,
                  child: (photoUrl == null || photoUrl.isEmpty)
                      ? Text(
                          name.isNotEmpty ? name[0].toUpperCase() : 'D',
                          style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: AppColors.brand,
                          ),
                        )
                      : null,
                ),
              ),
              Positioned(
                bottom: 2,
                right: 2,
                child: _buildVerificationBadge(context, uid, profile),
              ),
            ],
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Text(
                    'Driver Profile',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  name,
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
          GestureDetector(
            onTap: () => context.push(DriverRoutePaths.profileDetail),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.edit_outlined,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationBadge(
      BuildContext context, String? uid, DriverProfile? profile) {
    if (uid == null || profile == null) return const SizedBox.shrink();

    return StreamBuilder<VehicleInfo?>(
      stream: _profileRepo.streamVehicleInfo(uid),
      builder: (context, vehicleSnapshot) {
        final vehicleInfo = vehicleSnapshot.data;
        if (vehicleInfo == null) return const SizedBox.shrink();

        return StreamBuilder<List<DriverDocument>>(
          stream: _documentRepo.streamDocuments(uid),
          builder: (context, docsSnapshot) {
            final documents = docsSnapshot.data ?? [];
            final requiredDocs =
                requiredDocumentsForVehicleType(vehicleInfo.vehicleType);
            final allApproved = requiredDocs.every((docDef) {
              final document = documents.firstWhere(
                (d) => d.documentType == docDef.type,
                orElse: () => DriverDocument(
                  documentType: '',
                  fileUrl: '',
                  status: 'pending',
                ),
              );
              return document.isApproved;
            });

            if (!allApproved) return const SizedBox.shrink();

            return Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.verified_rounded,
                color: AppColors.brand,
                size: 14,
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildWalletCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return StreamBuilder<double>(
      stream: _walletRepo.streamWalletBalance(),
      builder: (context, snapshot) {
        final balance = snapshot.data ?? 0.0;
        final formattedBalance =
            '₦${balance.toStringAsFixed(2).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';

        return GlassContainer(
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
                  Icons.account_balance_wallet_outlined,
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
                      formattedBalance,
                      style: AppTextStyles.titleLarge,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Available balance',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 80,
                height: 36,
                child: PrimaryButton(
                  label: 'View',
                  onPressed: () => context.push(DriverRoutePaths.wallet),
                  height: 36,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(
    BuildContext context, {
    required String title,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTextStyles.titleMedium.copyWith(
            color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _buildMenuSection(
    BuildContext context, {
    required List<Widget> children,
  }) {
    return GlassContainer(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Column(children: children),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
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
                  color: (iconColor ?? AppColors.brand)
                      .withValues(alpha: 0.10),
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
                child: Text(
                  title,
                  style: AppTextStyles.titleMedium.copyWith(
                    color: textColor ??
                        (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight),
                  ),
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

  Widget _buildVehicleMenuItem(BuildContext context, {String? uid}) {
    return _buildMenuItem(
      context,
      icon: Icons.drive_eta_rounded,
      title: 'Vehicle Information',
      onTap: () => context.push(DriverRoutePaths.profileVehicle),
    );
  }

  Widget _buildDocumentsMenuItem(BuildContext context, {String? uid}) {
    if (uid == null) {
      return _buildMenuItem(
        context,
        icon: Icons.folder_copy_outlined,
        title: 'Documents',
        onTap: () => showVehicleInfoRequiredDialog(context),
      );
    }
    return StreamBuilder<VehicleInfo?>(
      stream: _profileRepo.streamVehicleInfo(uid),
      builder: (context, vehicleSnapshot) {
        final vehicle = vehicleSnapshot.data;
        return _buildMenuItem(
          context,
          icon: Icons.folder_copy_outlined,
          title: 'Documents',
          onTap: () {
            if (vehicle == null) {
              showVehicleInfoRequiredDialog(context);
              return;
            }
            context.push(DriverRoutePaths.profileDocuments);
          },
        );
      },
    );
  }

  Widget _buildRatingsMenuItem(BuildContext context, {String? uid}) {
    return _buildMenuItem(
      context,
      icon: Icons.star_outline_rounded,
      title: 'Ratings & Reviews',
      onTap: () => context.push(DriverRoutePaths.profileRatings),
    );
  }

  Widget _buildTierMenuItem(BuildContext context, {String? uid}) {
    if (uid == null) {
      return _buildMenuItem(
        context,
        icon: Icons.workspace_premium_outlined,
        title: 'Driver Tiers',
        onTap: () => context.push(DriverRoutePaths.profileTiers),
      );
    }
    return StreamBuilder<DriverProfile?>(
      stream: _profileRepo.streamDriverProfile(uid),
      builder: (context, snapshot) {
        final profile = snapshot.data;
        final tier = (profile?.tier ?? 'bronze').toUpperCase();
        return _buildMenuItem(
          context,
          icon: Icons.workspace_premium_outlined,
          title: 'Driver Tiers',
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.brandGlass,
              borderRadius: BorderRadius.circular(AppRadius.sm),
              border: Border.all(color: AppColors.brandGlassBorder),
            ),
            child: Text(
              tier,
              style: const TextStyle(
                color: AppColors.brand,
                fontWeight: FontWeight.bold,
                fontSize: 10,
              ),
            ),
          ),
          onTap: () => context.push(DriverRoutePaths.profileTiers),
        );
      },
    );
  }

  void _showAppearanceBottomSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        ThemeMode tempMode = customerThemeMode.value;

        return StatefulBuilder(
          builder: (context, setSheetState) {
            return BottomSheetShell(
              title: 'App Appearance',
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pagePadding),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: AppSpacing.sm),
                    _buildThemeOptionTile(
                      context,
                      title: 'Light Mode',
                      subtitle: 'Bright and clean white appearance',
                      icon: Icons.light_mode_rounded,
                      mode: ThemeMode.light,
                      selectedMode: tempMode,
                      onTap: () => setSheetState(() => tempMode = ThemeMode.light),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    _buildThemeOptionTile(
                      context,
                      title: 'Dark Mode',
                      subtitle: 'Sleek dark interface easy on the eyes',
                      icon: Icons.dark_mode_rounded,
                      mode: ThemeMode.dark,
                      selectedMode: tempMode,
                      onTap: () => setSheetState(() => tempMode = ThemeMode.dark),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    _buildThemeOptionTile(
                      context,
                      title: 'System Default Mode',
                      subtitle: 'Matches your device display settings',
                      icon: Icons.brightness_auto_rounded,
                      mode: ThemeMode.system,
                      selectedMode: tempMode,
                      onTap: () => setSheetState(() => tempMode = ThemeMode.system),
                    ),
                    const SizedBox(height: AppSpacing.lg),
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
                            label: 'Apply',
                            onPressed: () {
                              customerThemeMode.setTheme(tempMode);
                              Navigator.of(sheetContext).pop();
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
      },
    );
  }

  Widget _buildThemeOptionTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required ThemeMode mode,
    required ThemeMode selectedMode,
    required VoidCallback onTap,
  }) {
    final isSelected = mode == selectedMode;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const activeColor = AppColors.brand;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: isSelected
                ? activeColor.withValues(alpha: 0.12)
                : (isDark ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFF8F9FC)),
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: isSelected
                  ? activeColor.withValues(alpha: 0.5)
                  : (isDark ? Colors.white10 : const Color(0xFFE9EAF0)),
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? activeColor.withValues(alpha: 0.2)
                      : (isDark ? Colors.white10 : Colors.grey[200]),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: isSelected ? activeColor : (isDark ? Colors.grey[400] : Colors.grey[700]),
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
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                        color: isDark ? Colors.white : AppColors.slate900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: isDark ? Colors.grey[400] : const Color(0xFF6E7191),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                color: isSelected ? activeColor : (isDark ? Colors.grey[600] : Colors.grey[400]),
                size: 22,
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
    final uid = driverAuthController.currentUid;

    return AppScaffold(
      extendBody: true,
      title: 'Profile',
      body: SafeArea(
        child: ResponsiveContainer(
          child: uid != null
              ? StreamBuilder<DriverProfile?>(
                  stream: _profileRepo.streamDriverProfile(uid),
                  builder: (context, snapshot) => _buildScrollBody(
                    context,
                    uid: uid,
                    profile: snapshot.data,
                    isDark: isDark,
                  ),
                )
              : _buildScrollBody(
                  context,
                  uid: null,
                  profile: null,
                  isDark: isDark,
                ),
        ),
      ),
    );
  }

  Widget _buildScrollBody(
    BuildContext context, {
    required String? uid,
    required DriverProfile? profile,
    required bool isDark,
  }) {
    final name = profile?.fullName.isNotEmpty == true
        ? profile!.fullName
        : 'Driver';
    final subtitle = profile?.email ??
        driverAuthController.currentEmail ??
        'CaRide Driver';
    final photoUrl = profile?.profilePhotoUrl;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.pagePadding,
        vertical: AppSpacing.md,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildProfileHero(
            context,
            name: name,
            subtitle: subtitle,
            photoUrl: photoUrl,
            uid: uid,
            profile: profile,
          ),
          const SizedBox(height: AppSpacing.lg),
          _buildSectionHeader(
            context,
            title: 'Earnings & Account',
          ),
          const SizedBox(height: AppSpacing.sm),
          _buildWalletCard(context),
          const SizedBox(height: AppSpacing.sm),
          _buildMenuSection(
            context,
            children: [
              _buildVehicleMenuItem(context, uid: uid),
              _buildDocumentsMenuItem(context, uid: uid),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          _buildSectionHeader(
            context,
            title: 'Programs',
          ),
          const SizedBox(height: AppSpacing.sm),
          _buildMenuSection(
            context,
            children: [
              _buildMenuItem(
                context,
                icon: Icons.people_outline_rounded,
                title: 'Refer & Earn',
                onTap: () => context.push(DriverRoutePaths.referral),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          _buildSectionHeader(
            context,
            title: 'Performance',
          ),
          const SizedBox(height: AppSpacing.sm),
          _buildMenuSection(
            context,
            children: [
              _buildRatingsMenuItem(context, uid: uid),
              _buildTierMenuItem(context, uid: uid),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          _buildSectionHeader(
            context,
            title: 'Preferences & Support',
          ),
          const SizedBox(height: AppSpacing.sm),
          _buildMenuSection(
            context,
            children: [
              _buildMenuItem(
                context,
                icon: Icons.shield_outlined,
                title: 'Account & Security',
                onTap: () => context.push(DriverRoutePaths.accountSecurity),
              ),
              _buildMenuItem(
                context,
                icon: Icons.brightness_6_outlined,
                title: 'App Appearance',
                onTap: () => _showAppearanceBottomSheet(context),
              ),
              _buildMenuItem(
                context,
                icon: Icons.help_outline_rounded,
                title: 'Help & FAQs',
                onTap: () => context.push(DriverRoutePaths.helpFaq),
              ),
              _buildMenuItem(
                context,
                icon: Icons.privacy_tip_outlined,
                title: 'Privacy Policy',
                onTap: () => context.push(DriverRoutePaths.privacyPolicy),
              ),
              _buildMenuItem(
                context,
                icon: Icons.info_outline_rounded,
                title: 'About CaRide',
                onTap: () => context.push(DriverRoutePaths.aboutApp),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          _buildSectionHeader(
            context,
            title: 'Account Mode',
          ),
          const SizedBox(height: AppSpacing.sm),
          ListenableBuilder(
            listenable: customerAuthController,
            builder: (context, _) {
              return _buildMenuSection(
                context,
                children: [
                  _buildMenuItem(
                    context,
                    icon: customerAuthController.customerExists
                        ? Icons.directions_car_rounded
                        : Icons.assignment_ind_outlined,
                    title: customerAuthController.customerExists
                        ? 'Switch to Passenger Mode'
                        : 'Become a Passenger',
                    onTap: () => context.push(DriverRoutePaths.becomeCustomer),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: AppSpacing.lg),

          _buildSectionHeader(
            context,
            title: 'Account Session',
          ),
          const SizedBox(height: AppSpacing.sm),
          _buildMenuSection(
            context,
            children: [
              _buildMenuItem(
                context,
                icon: Icons.logout_rounded,
                title: 'Sign Out',
                textColor: AppColors.error,
                iconColor: AppColors.error,
                showChevron: false,
                onTap: () => _showLogoutBottomSheet(context),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          Center(
            child: Text(
              'Version 1.0.4 (Build 45)',
              style: AppTextStyles.bodySmall.copyWith(
                color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
        ],
      ),
    );
  }
}
