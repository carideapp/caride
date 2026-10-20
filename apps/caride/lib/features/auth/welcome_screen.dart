import 'dart:async';
import 'dart:ui';

import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:navigation/navigation.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─── Role Data Model ──────────────────────────────────────────────────────────

class _RoleData {
  const _RoleData({
    required this.id,
    required this.tabTitle,
    required this.label,
    required this.tagline,
    required this.heroAsset,
    required this.accentColor,
    required this.loginLabel,
    required this.signupLabel,
  });

  final String id;
  final String tabTitle;
  final String label;
  final String tagline;
  final String heroAsset;
  final Color accentColor;
  final String loginLabel;
  final String signupLabel;
}

const _roles = [
  _RoleData(
    id: 'customer',
    tabTitle: 'Passenger',
    label: 'Ride as a Passenger',
    tagline: 'Go anywhere, anytime.',
    heroAsset: 'lib/assets/passenger_hero.png',
    accentColor: AppColors.brand,
    loginLabel: 'Log In as Passenger',
    signupLabel: 'Sign Up as Passenger',
  ),
  _RoleData(
    id: 'driver',
    tabTitle: 'Driver',
    label: 'Drive & Earn',
    tagline: 'Your car. Your schedule. Your income.',
    heroAsset: 'lib/assets/driver_hero_portrait.png',
    accentColor: AppColors.brand,
    loginLabel: 'Log In as Driver',
    signupLabel: 'Sign Up as Driver',
  ),
  _RoleData(
    id: 'fleet',
    tabTitle: 'Fleet Manager',
    label: 'Fleet & Car Rentals',
    tagline: 'Manage vehicles, chauffeurs & rental orders.',
    heroAsset: 'lib/assets/driver_hero.png',
    accentColor: AppColors.brand,
    loginLabel: 'Log In as Fleet Manager',
    signupLabel: 'Sign Up as Fleet Manager',
  ),
];

// ─── Screen ──────────────────────────────────────────────────────────────────

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  late final PageController _pageController;
  late final AnimationController _entryController;

  int _selectedRoleIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _selectedRoleIndex);
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _entryController.dispose();
    super.dispose();
  }

  void _onRoleTabSelected(int index) {
    if (index == _selectedRoleIndex) return;
    setState(() => _selectedRoleIndex = index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOutCubic,
    );
  }

  void _handleAuthAction(String roleId, bool isLogin) {
    unawaited(() async {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('selected_role', roleId);
      } catch (e) {
        debugPrint('Failed to persist selected_role: $e');
      }
    }());

    final path = roleId == 'driver'
        ? (isLogin ? DriverRoutePaths.login : DriverRoutePaths.signup)
        : roleId == 'fleet'
            ? (isLogin ? FleetRoutePaths.login : FleetRoutePaths.signup)
            : (isLogin ? CustomerRoutePaths.login : CustomerRoutePaths.signup);

    try {
      context.push(path);
    } catch (e, stack) {
      debugPrint('Navigation push failed ($e), falling back to go: $stack');
      if (mounted) {
        context.go(path);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentRole = _roles[_selectedRoleIndex];

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Full-screen hero PageView ──────────────────────────────────
          PageView.builder(
            controller: _pageController,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _roles.length,
            itemBuilder: (context, index) {
              return _HeroPage(
                role: _roles[index],
              );
            },
          ),

          // ── Top logo bar ──────────────────────────────────────────────
          SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: FadeTransition(
                opacity: CurvedAnimation(
                  parent: _entryController,
                  curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  child: Row(
                    children: [
                      Image.asset(
                        'lib/assets/CaRide_logo.png',
                        height: 32,
                        color: Colors.white,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Bottom frosted panel with fixed tabs ───────────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _BottomPanel(
              role: currentRole,
              selectedIndex: _selectedRoleIndex,
              entryAnimation: _entryController,
              onTabSelected: _onRoleTabSelected,
              onLoginPressed: () =>
                  _handleAuthAction(currentRole.id, true),
              onSignupPressed: () =>
                  _handleAuthAction(currentRole.id, false),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Hero Page ────────────────────────────────────────────────────────────────

class _HeroPage extends StatelessWidget {
  const _HeroPage({required this.role});

  final _RoleData role;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          role.heroAsset,
          fit: BoxFit.cover,
          alignment: Alignment.center,
          width: double.infinity,
          height: double.infinity,
        ),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: const [0.0, 0.35, 0.65, 1.0],
              colors: [
                Colors.transparent,
                Colors.transparent,
                Colors.black.withValues(alpha: 0.55),
                Colors.black.withValues(alpha: 0.97),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Bottom Frosted Panel with Fixed Segmented Role Tabs ──────────────────────

class _BottomPanel extends StatelessWidget {
  const _BottomPanel({
    required this.role,
    required this.selectedIndex,
    required this.entryAnimation,
    required this.onTabSelected,
    required this.onLoginPressed,
    required this.onSignupPressed,
  });

  final _RoleData role;
  final int selectedIndex;
  final Animation<double> entryAnimation;
  final ValueChanged<int> onTabSelected;
  final VoidCallback onLoginPressed;
  final VoidCallback onSignupPressed;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return AnimatedBuilder(
      animation: entryAnimation,
      builder: (context, child) {
        final entrySlide = Tween<Offset>(
          begin: const Offset(0, 0.2),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: entryAnimation,
          curve: const Interval(0.2, 1.0, curve: Curves.easeOutCubic),
        )).value;

        return FractionalTranslation(
          translation: entrySlide,
          child: Opacity(
            opacity: CurvedAnimation(
              parent: entryAnimation,
              curve: const Interval(0.2, 0.85, curve: Curves.easeOut),
            ).value,
            child: child,
          ),
        );
      },
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.55),
              border: Border(
                top: BorderSide(
                  color: Colors.white.withValues(alpha: 0.12),
                  width: 0.5,
                ),
              ),
            ),
            padding: EdgeInsets.fromLTRB(20, 24, 20, bottomInset + 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Fixed Segmented Role Tabs ──────────────────────────
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                  ),
                  child: Row(
                    children: List.generate(_roles.length, (index) {
                      final isSelected = index == selectedIndex;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => onTabSelected(index),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeInOut,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.brand
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(24),
                            ),
                            child: Text(
                              _roles[index].tabTitle,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: isSelected
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: isSelected
                                    ? Colors.white
                                    : Colors.white.withValues(alpha: 0.70),
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ),

                const SizedBox(height: 20),

                // ── Role Title ─────────────────────────────────────────
                Text(
                  role.label,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),

                const SizedBox(height: 4),

                // ── Tagline ────────────────────────────────────────────
                Text(
                  role.tagline,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    color: Colors.white.withValues(alpha: 0.65),
                    letterSpacing: 0.1,
                  ),
                ),

                const SizedBox(height: 24),

                // ── Dedicated Auth Pill Buttons (Login & Signup) ──────
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brand,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                    onPressed: onLoginPressed,
                    child: Text(
                      role.loginLabel,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.35),
                        width: 1.5,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                    onPressed: onSignupPressed,
                    child: Text(
                      role.signupLabel,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // ── Terms ──────────────────────────────────────────────
                Center(
                  child: Text(
                    'By continuing you agree to CaRide\'s Terms & Privacy Policy.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10.5,
                      color: Colors.white.withValues(alpha: 0.35),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
