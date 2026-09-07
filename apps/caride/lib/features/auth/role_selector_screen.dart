import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:navigation/navigation.dart';
import 'package:caride/core/auth/customer_auth_controller.dart';
import 'package:caride/features/fleet_manager/controllers/fleet_manager_controller.dart';
import 'package:caride/features/fleet_manager/auth/controllers/fleet_auth_controller.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Redesigned Role Selector Screen supporting Customer, Driver, and Fleet Partner modes.
class RoleSelectorScreen extends StatelessWidget {
  const RoleSelectorScreen({super.key});

  void _selectRole(BuildContext context, String role) async {
    debugPrint('[RoleSelector] _selectRole called with role: $role');
    final currentUser = FirebaseAuth.instance.currentUser;
    debugPrint(
      '[RoleSelector] Current User UID: ${currentUser?.uid}, Email: ${currentUser?.email}',
    );

    if (role == 'fleet') {
      final uid = currentUser?.uid;
      fleetManagerController.init(uid);
      // Preload user data into fleetAuthController for smooth onboarding
      fleetAuthController.preloadFromUser(
        email: currentUser?.email,
        fullName: customerAuthController.currentProfile?.fullName,
        phone: customerAuthController.currentProfile?.phone,
      );
    }

    try {
      debugPrint('[RoleSelector] Switching active role in database to: $role...');
      await customerAuthController.switchRole(role);
      debugPrint('[RoleSelector] Database role switch completed successfully.');
    } catch (e) {
      debugPrint('[RoleSelector] Error switching role: $e');
    }

    if (!context.mounted) {
      debugPrint('[RoleSelector] Context is no longer mounted, aborting navigation.');
      return;
    }

    if (role == 'customer') {
      debugPrint('[RoleSelector] Navigating to Customer Home: ${CustomerRoutePaths.home}');
      context.go(CustomerRoutePaths.home);
    } else if (role == 'driver') {
      debugPrint('[RoleSelector] Navigating to Driver Home: ${DriverRoutePaths.home}');
      context.go(DriverRoutePaths.home);
    } else if (role == 'fleet') {
      final hasFleet = customerAuthController.fleetExists ||
          fleetManagerController.hasFleetProfile ||
          fleetAuthController.currentProfile != null;
      if (hasFleet) {
        debugPrint('[RoleSelector] Navigating to Fleet Dashboard: ${FleetRoutePaths.dashboard}');
        context.go(FleetRoutePaths.dashboard);
      } else {
        debugPrint('[RoleSelector] Navigating to Fleet Signup: ${FleetRoutePaths.signup}');
        context.go(FleetRoutePaths.signup);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.pagePadding,
              vertical: AppSpacing.lg,
            ),
            child: ListenableBuilder(
              listenable: customerAuthController,
              builder: (context, _) {
                final currentActiveRole = customerAuthController.activeRole;
                final customerExists = customerAuthController.customerExists;
                final driverExists = customerAuthController.driverExists;
                final fleetExists = customerAuthController.fleetExists;

                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Image.asset(
                        'lib/assets/CaRide_logo.png',
                        height: 56,
                        color: isDark ? Colors.white : null,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Text(
                      "Select Account Mode",
                      textAlign: TextAlign.center,
                      style: AppTextStyles.headlineLarge.copyWith(
                        fontWeight: FontWeight.w900,
                        fontSize: 26,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      "Switch between your customer, driver, or fleet manager workspace anytime.",
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: isDark
                            ? AppColors.textSecondaryDark
                            : AppColors.textSecondaryLight,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    // ── Customer Mode Card ──
                    _RoleOptionCard(
                      title: "Customer Mode",
                      subtitle:
                          "Book rides, send delivery items & browse car rentals",
                      icon: Icons.directions_car_rounded,
                      accentColor: const Color(0xFF16A34A),
                      isActive: currentActiveRole == 'customer',
                      badgeLabel: customerExists ? null : 'GET STARTED',
                      onTap: () => _selectRole(context, 'customer'),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // ── Driver Mode Card ──
                    _RoleOptionCard(
                      title: "Driver Mode",
                      subtitle:
                          "Accept ride offers, navigate trips & track daily earnings",
                      icon: Icons.drive_eta_rounded,
                      accentColor: const Color(0xFF2563EB),
                      isActive: currentActiveRole == 'driver',
                      badgeLabel: driverExists ? null : 'BECOME DRIVER',
                      onTap: () => _selectRole(context, 'driver'),
                    ),
                    const SizedBox(height: AppSpacing.md),

                    // ── Fleet Partner Mode Card ──
                    _RoleOptionCard(
                      title: "Fleet Partner Mode",
                      subtitle:
                          "List rental vehicles, dispatch chauffeurs & manage bookings",
                      icon: Icons.business_center_rounded,
                      accentColor: const Color(0xFF8B5CF6),
                      isActive: currentActiveRole == 'fleet',
                      badgeLabel: fleetExists ? 'ACTIVE FLEET' : 'BECOME FLEET PARTNER',
                      onTap: () => _selectRole(context, 'fleet'),
                    ),
                    const SizedBox(height: AppSpacing.xl),

                    // ── Sign Out CTA ──
                    TextButton.icon(
                      icon: const Icon(
                        Icons.logout_rounded,
                        color: AppColors.error,
                        size: 20,
                      ),
                      label: Text(
                        "Sign Out of CaRide",
                        style: AppTextStyles.titleSmall.copyWith(
                          color: AppColors.error,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      onPressed: () async {
                        await customerAuthController.signOut();
                        if (context.mounted) {
                          context.go(CustomerRoutePaths.welcome);
                        }
                      },
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _RoleOptionCard extends StatefulWidget {
  const _RoleOptionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
    required this.onTap,
    this.isActive = false,
    this.badgeLabel,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;
  final VoidCallback onTap;
  final bool isActive;
  final String? badgeLabel;

  @override
  State<_RoleOptionCard> createState() => _RoleOptionCardState();
}

class _RoleOptionCardState extends State<_RoleOptionCard> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _isPressed ? 0.98 : 1.0,
        duration: AppDurations.fast,
        curve: AppCurves.spring,
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            border: Border.all(
              color: widget.isActive
                  ? widget.accentColor
                  : (isDark
                      ? AppColors.glassBorderDark
                      : AppColors.glassBorderLight),
              width: widget.isActive ? 2 : 1,
            ),
            boxShadow: [
              if (widget.isActive)
                BoxShadow(
                  color: widget.accentColor.withValues(alpha: 0.2),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                )
              else
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
            ],
          ),
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: widget.accentColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  widget.icon,
                  color: widget.accentColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            widget.title,
                            style: AppTextStyles.titleMedium.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (widget.badgeLabel != null) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: widget.accentColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              widget.badgeLabel!,
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: widget.accentColor,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      widget.subtitle,
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
              if (widget.isActive)
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: widget.accentColor,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                )
              else
                Icon(
                  Icons.chevron_right_rounded,
                  color: isDark
                      ? AppColors.textTertiaryDark
                      : AppColors.textTertiaryLight,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
