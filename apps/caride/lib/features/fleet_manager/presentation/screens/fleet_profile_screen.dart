import 'package:caride/app/theme_mode_controller.dart';
import 'package:caride/core/auth/customer_auth_controller.dart';
import 'package:caride/features/fleet_manager/controllers/fleet_manager_controller.dart';
import 'package:caride/features/fleet_manager/presentation/widgets/fleet_bottom_nav.dart';
import 'package:design_system/design_system.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:navigation/navigation.dart';
import 'package:shared_models/shared_models.dart';

/// Minimalist Fleet Manager Profile Screen strictly styled after UI/Profile.png,
/// featuring flat surfaces, consistent palette, clean typography, bottom sheet appearance, and zero clutter.
class FleetProfileScreen extends StatefulWidget {
  const FleetProfileScreen({super.key});

  @override
  State<FleetProfileScreen> createState() => _FleetProfileScreenState();
}

class _FleetProfileScreenState extends State<FleetProfileScreen> {
  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    fleetManagerController.init(uid);
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



  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF111827);

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.darkBackground
          : const Color(0xFFFAFAFA),
      extendBody: true,
      bottomNavigationBar: FleetBottomNav(currentIndex: 4),
      body: SafeArea(
        child: ListenableBuilder(
          listenable: fleetManagerController,
          builder: (context, _) {
            final profile =
                fleetManagerController.currentProfile ??
                FleetProfile(
                  fleetId: '',
                  ownerUid: FirebaseAuth.instance.currentUser?.uid ?? '',
                  businessName: 'CaRide Fleet Partner',
                  phone: customerAuthController.currentProfile?.phone ?? '',
                  email: FirebaseAuth.instance.currentUser?.email ?? '',
                  businessType: 'individual',
                  fullName:
                      customerAuthController.currentProfile?.fullName ??
                      'Fleet Manager',
                  city: 'Abuja',
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                );

            final displayName = profile.fullName.isNotEmpty
                ? profile.fullName
                : (profile.businessName.isNotEmpty
                      ? profile.businessName
                      : 'Fleet Manager');
            final isVerified =
                profile.isVerified || profile.verificationStatus == 'approved';

            return SingleChildScrollView(
              padding: const EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: 50,
              ),
              child: Column(
                children: [
                  // ── Top Header Avatar & Name (Matching UI/Profile.png layout) ──
                  Center(
                    child: Column(
                      children: [
                        GestureDetector(
                          onTap: () =>
                              context.push(FleetRoutePaths.profileDetails),
                          child: Container(
                            width: 96,
                            height: 96,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isDark
                                  ? AppColors.darkSurface
                                  : const Color(0xFFF3F4F6),
                              border: Border.all(
                                color: isDark
                                    ? AppColors.glassBorderDark
                                    : const Color(0xFFE5E7EB),
                                width: 1.5,
                              ),
                            ),
                            child:
                                profile.profilePictureUrl != null &&
                                    profile.profilePictureUrl!.isNotEmpty
                                ? ClipOval(
                                    child: Image.network(
                                      profile.profilePictureUrl!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => Icon(
                                        Icons.person_rounded,
                                        size: 48,
                                        color: isDark
                                            ? Colors.white70
                                            : const Color(0xFF4B5563),
                                      ),
                                    ),
                                  )
                                : Icon(
                                    Icons.person_rounded,
                                    size: 48,
                                    color: isDark
                                        ? Colors.white70
                                        : const Color(0xFF4B5563),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          displayName,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: primaryTextColor,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ── CARD GROUP 1 (Main Profile & Operations) ──
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface : Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: isDark
                            ? AppColors.glassBorderDark
                            : const Color(0xFFE5E7EB),
                      ),
                    ),
                    child: Column(
                      children: [
                        _ProfileMenuItem(
                          title: 'Profile Details',
                          icon: Icons.person_outline_rounded,
                          isDark: isDark,
                          primaryTextColor: primaryTextColor,
                          onTap: () =>
                              context.push(FleetRoutePaths.profileDetails),
                        ),
                        _buildDivider(isDark),
                        _ProfileMenuItem(
                          title: 'Business Info',
                          icon: Icons.domain_outlined,
                          isDark: isDark,
                          primaryTextColor: primaryTextColor,
                          onTap: () =>
                              context.push(FleetRoutePaths.businessInfo),
                        ),
                        _buildDivider(isDark),
                        _ProfileMenuItem(
                          title: 'Verification',
                          icon: Icons.verified_user_outlined,
                          isDark: isDark,
                          primaryTextColor: primaryTextColor,
                          badge: isVerified ? 'Verified' : 'Pending',
                          badgeColor: isVerified
                              ? AppColors.brand
                              : const Color(0xFFF59E0B),
                          onTap: () =>
                              context.push(FleetRoutePaths.verification),
                        ),
                        _buildDivider(isDark),
                        _ProfileMenuItem(
                          title: 'Wallet',
                          icon: Icons.account_balance_wallet_outlined,
                          isDark: isDark,
                          primaryTextColor: primaryTextColor,
                          onTap: () => context.push(FleetRoutePaths.wallet),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── CARD GROUP 2 (Settings) ──
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface : Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: isDark
                            ? AppColors.glassBorderDark
                            : const Color(0xFFE5E7EB),
                      ),
                    ),
                    child: Column(
                      children: [
                        _ProfileMenuItem(
                          title: 'Settings',
                          icon: Icons.settings_outlined,
                          isDark: isDark,
                          primaryTextColor: primaryTextColor,
                          onTap: () => context.push(FleetRoutePaths.settings),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── CARD GROUP 3 (Support & Legal) ──
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface : Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: isDark
                            ? AppColors.glassBorderDark
                            : const Color(0xFFE5E7EB),
                      ),
                    ),
                    child: Column(
                      children: [
                        _ProfileMenuItem(
                          title: 'Support',
                          icon: Icons.headset_mic_outlined,
                          isDark: isDark,
                          primaryTextColor: primaryTextColor,
                          onTap: () => context.push(FleetRoutePaths.support),
                        ),
                        _buildDivider(isDark),
                        _ProfileMenuItem(
                          title: 'Help/FAQs',
                          icon: Icons.help_outline_rounded,
                          isDark: isDark,
                          primaryTextColor: primaryTextColor,
                          onTap: () => context.push(FleetRoutePaths.helpFaqs),
                        ),
                        _buildDivider(isDark),
                        _ProfileMenuItem(
                          title: 'Legal & Guidelines',
                          icon: Icons.description_outlined,
                          isDark: isDark,
                          primaryTextColor: primaryTextColor,
                          onTap: () => context.push(FleetRoutePaths.legal),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
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

class _ProfileMenuItem extends StatelessWidget {
  const _ProfileMenuItem({
    required this.title,
    required this.icon,
    required this.isDark,
    required this.primaryTextColor,
    required this.onTap,
    this.badge,
    this.badgeColor,
  });

  final String title;
  final IconData icon;
  final bool isDark;
  final Color primaryTextColor;
  final VoidCallback onTap;
  final String? badge;
  final Color? badgeColor;

  @override
  Widget build(BuildContext context) {
    final iconBgColor = isDark ? Colors.white10 : const Color(0xFFF3F4F6);
    final iconColor = isDark ? Colors.white70 : const Color(0xFF374151);

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
                color: iconBgColor,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 20),
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
