import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:navigation/navigation.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─── Data ────────────────────────────────────────────────────────────────────

class _RoleData {
  const _RoleData({
    required this.id,
    required this.label,
    required this.tagline,
    required this.perks,
    required this.heroAsset,
    required this.accentColor,
  });

  final String id;
  final String label;
  final String tagline;
  final List<String> perks;
  final String heroAsset;
  final Color accentColor;
}

const _roles = [
  _RoleData(
    id: 'customer',
    label: 'Ride as a Passenger',
    tagline: 'Go anywhere, anytime.',
    perks: ['Book instantly', 'Real-time tracking', 'Safe & comfortable'],
    heroAsset: 'lib/assets/passenger_hero.png',
    accentColor: Color(0xFF16A34A), // brand green
  ),
  _RoleData(
    id: 'driver',
    label: 'Drive & Earn',
    tagline: 'Your car. Your schedule. Your income.',
    perks: ['Flexible hours', 'Get Paid Anytime', 'Top driver rewards'],
    heroAsset: 'lib/assets/driver_hero_portrait.png',
    accentColor: Color(0xFF2563EB), // blue
  ),
  _RoleData(
    id: 'fleet',
    label: 'Fleet & Car Rentals',
    tagline: 'Manage vehicles, chauffeurs & rental orders.',
    perks: ['List rental cars', 'Assign chauffeurs', 'Direct settlements'],
    heroAsset: 'lib/assets/driver_hero.png',
    accentColor: Color(0xFF8B5CF6), // purple
  ),
];

// ─── Screen ──────────────────────────────────────────────────────────────────

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  late final AnimationController _entryController;
  late final AnimationController _panelController;

  int _currentPage = 0;

  @override
  void initState() {
    super.initState();

    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();

    _panelController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    )..forward();

    _pageController.addListener(() {
      final page = _pageController.page?.round() ?? 0;
      if (page != _currentPage) {
        setState(() => _currentPage = page);
        _panelController
          ..reset()
          ..forward();
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _entryController.dispose();
    _panelController.dispose();
    super.dispose();
  }

  Future<void> _selectRole(String role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_role', role);
    if (!mounted) return;
    if (role == 'driver') {
      context.push(DriverRoutePaths.login);
    } else if (role == 'fleet') {
      context.push(FleetRoutePaths.login);
    } else {
      context.push(CustomerRoutePaths.login);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Full-screen hero PageView ──────────────────────────────────
          PageView.builder(
            controller: _pageController,
            itemCount: _roles.length,
            itemBuilder: (context, index) {
              return _HeroPage(
                role: _roles[index],
                entryAnimation: _entryController,
              );
            },
          ),

          // ── Top logo bar ──────────────────────────────────────────────
          SafeArea(
            child: FadeTransition(
              opacity: CurvedAnimation(
                parent: _entryController,
                curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Image.asset(
                      'lib/assets/CaRide_logo.png',
                      height: 32,
                      color: Colors.white,
                    ),
                    _PageDots(
                      count: _roles.length,
                      current: _currentPage,
                      activeColor: _roles[_currentPage].accentColor,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── Bottom frosted panel ───────────────────────────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _BottomPanel(
              role: _roles[_currentPage],
              panelAnimation: _panelController,
              entryAnimation: _entryController,
              onContinue: () => _selectRole(_roles[_currentPage].id),
              onSwitchRole: () {
                final next = (_currentPage + 1) % _roles.length;
                _pageController.animateToPage(
                  next,
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeInOut,
                );
              },
              otherRoleLabel: _roles[(_currentPage + 1) % _roles.length].label,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Hero Page ────────────────────────────────────────────────────────────────

class _HeroPage extends StatelessWidget {
  const _HeroPage({
    required this.role,
    required this.entryAnimation,
  });

  final _RoleData role;
  final Animation<double> entryAnimation;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Hero image — bleeds full screen
        Image.asset(
          role.heroAsset,
          fit: BoxFit.cover,
          alignment: Alignment.center,
          width: double.infinity,
          height: double.infinity,
        ),

        // Dark scrim that grows from bottom so text stays readable
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

// ─── Bottom frosted panel ─────────────────────────────────────────────────────

class _BottomPanel extends StatelessWidget {
  const _BottomPanel({
    required this.role,
    required this.panelAnimation,
    required this.entryAnimation,
    required this.onContinue,
    required this.onSwitchRole,
    required this.otherRoleLabel,
  });

  final _RoleData role;
  final Animation<double> panelAnimation;
  final Animation<double> entryAnimation;
  final VoidCallback onContinue;
  final VoidCallback onSwitchRole;
  final String otherRoleLabel;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).padding.bottom;

    return AnimatedBuilder(
      animation: entryAnimation,
      builder: (context, child) {
        final entrySlide = Tween<Offset>(
          begin: const Offset(0, 0.25),
          end: Offset.zero,
        )
            .animate(CurvedAnimation(
              parent: entryAnimation,
              curve: const Interval(0.3, 1.0, curve: Curves.easeOutCubic),
            ))
            .value;

        return FractionalTranslation(
          translation: entrySlide,
          child: Opacity(
            opacity: CurvedAnimation(
              parent: entryAnimation,
              curve: const Interval(0.3, 0.85, curve: Curves.easeOut),
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
              color: Colors.black.withValues(alpha: 0.45),
              border: Border(
                top: BorderSide(
                  color: Colors.white.withValues(alpha: 0.08),
                  width: 0.5,
                ),
              ),
            ),
            padding: EdgeInsets.fromLTRB(28, 28, 28, bottomInset + 24),
            child: AnimatedBuilder(
              animation: panelAnimation,
              builder: (context, _) {
                final t = CurvedAnimation(
                  parent: panelAnimation,
                  curve: Curves.easeOutCubic,
                ).value;

                return Opacity(
                  opacity: t,
                  child: Transform.translate(
                    offset: Offset(0, 16 * (1 - t)),
                    child: _PanelContent(
                      role: role,
                      onContinue: onContinue,
                      onSwitchRole: onSwitchRole,
                      otherRoleLabel: otherRoleLabel,
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _PanelContent extends StatelessWidget {
  const _PanelContent({
    required this.role,
    required this.onContinue,
    required this.onSwitchRole,
    required this.otherRoleLabel,
  });

  final _RoleData role;
  final VoidCallback onContinue;
  final VoidCallback onSwitchRole;
  final String otherRoleLabel;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Role label with accent dot
        Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: role.accentColor,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              role.label,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),

        const SizedBox(height: 6),

        // Tagline
        Text(
          role.tagline,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: Colors.white.withValues(alpha: 0.6),
            letterSpacing: 0.1,
          ),
        ),

        const SizedBox(height: 20),

        // Perks chips
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: role.perks
              .map(
                (p) => _PerkChip(label: p, accentColor: role.accentColor),
              )
              .toList(),
        ),

        const SizedBox(height: 28),

        // Primary CTA
        SizedBox(
          width: double.infinity,
          height: 52,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            decoration: BoxDecoration(
              color: role.accentColor,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: onContinue,
                child: Center(
                  child: Text(
                    'Continue as ${role.id == 'customer' ? 'Passenger' : (role.id == 'driver' ? 'Driver' : 'Fleet Partner')}  →',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),

        const SizedBox(height: 14),

        // Switch role ghost button
        SizedBox(
          width: double.infinity,
          height: 44,
          child: TextButton(
            onPressed: onSwitchRole,
            style: TextButton.styleFrom(
              foregroundColor: Colors.white.withValues(alpha: 0.55),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: Colors.white.withValues(alpha: 0.15),
                ),
              ),
            ),
            child: Text(
              'Switch to: $otherRoleLabel →',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.1,
              ),
            ),
          ),
        ),

        const SizedBox(height: 14),

        // Terms
        Center(
          child: Text(
            'By continuing you agree to CaRide\'s Terms & Privacy Policy.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10.5,
              color: Colors.white.withValues(alpha: 0.3),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Perk chip ────────────────────────────────────────────────────────────────

class _PerkChip extends StatelessWidget {
  const _PerkChip({required this.label, required this.accentColor});

  final String label;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.35),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_rounded, size: 13, color: accentColor),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Page indicator dots ──────────────────────────────────────────────────────

class _PageDots extends StatelessWidget {
  const _PageDots({
    required this.count,
    required this.current,
    required this.activeColor,
  });

  final int count;
  final int current;
  final Color activeColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(count, (i) {
        final isActive = i == current;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: isActive ? 22 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: isActive
                ? activeColor
                : Colors.white.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }
}
