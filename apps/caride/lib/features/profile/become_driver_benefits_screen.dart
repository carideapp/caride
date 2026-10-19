import 'package:caride/core/auth/customer_auth_controller.dart';
import 'package:confetti/confetti.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:navigation/navigation.dart';

/// Redesigned "Become a Driver" benefits screen matching the CaRide design standard:
/// full-bleed hero image → clean benefit cards → 56px pill sticky CTA.
class BecomeDriverBenefitsScreen extends StatefulWidget {
  const BecomeDriverBenefitsScreen({super.key});

  @override
  State<BecomeDriverBenefitsScreen> createState() => _BecomeDriverBenefitsScreenState();
}

class _BecomeDriverBenefitsScreenState extends State<BecomeDriverBenefitsScreen> {
  bool _isRegistering = false;
  String? _errorMessage;

  Future<void> _registerAsDriver() async {
    setState(() {
      _isRegistering = true;
      _errorMessage = null;
    });
    try {
      await customerAuthController.becomeDriver();
      if (!mounted) return;
      await _showSuccessBottomSheet();
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Failed to create driver account. Please try again.');
    } finally {
      if (mounted) setState(() => _isRegistering = false);
    }
  }

  Future<void> _showSuccessBottomSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _DriverSuccessBottomSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF111827);
    final secondaryTextColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
    final cardBg = isDark ? AppColors.darkSurface : Colors.white;
    final borderColor = isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFFAFAFA),
      body: Column(
        children: [
          // Scrollable content
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Hero photo with overlay
                  Stack(
                    children: [
                      SizedBox(
                        height: 280,
                        width: double.infinity,
                        child: Image.asset(
                          'lib/assets/driver_hero.png',
                          fit: BoxFit.cover,
                        ),
                      ),
                      // Gradient overlay
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        height: 90,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                (isDark ? AppColors.darkBackground : const Color(0xFFFAFAFA)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      // 44x44 Circular Back Button
                      Positioned(
                        top: MediaQuery.of(context).padding.top + 12,
                        left: 20,
                        child: GestureDetector(
                          onTap: () => Navigator.of(context).pop(),
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.darkSurface : Colors.white,
                              shape: BoxShape.circle,
                              border: Border.all(color: borderColor),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.arrow_back_ios_new_rounded,
                              size: 18,
                              color: primaryTextColor,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Content Section
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Drive & Earn on\nYour Schedule',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: primaryTextColor,
                            letterSpacing: -0.5,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Join the CaRide driver network and unlock premium earnings, flexible hours, and direct daily payouts.',
                          style: TextStyle(
                            fontSize: 14,
                            color: secondaryTextColor,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // In-View Error Banner
                        if (_errorMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: AppColors.error.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: const TextStyle(
                                      color: AppColors.error,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],

                        // Benefits Grouped Card
                        Container(
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: borderColor),
                          ),
                          child: Column(
                            children: [
                              _buildBenefitTile(
                                icon: Icons.monetization_on_outlined,
                                title: 'High earnings & transparent fees',
                                description:
                                    'Keep the majority of every fare with our fair pricing model and withdraw earnings to your wallet anytime.',
                                primaryTextColor: primaryTextColor,
                                secondaryTextColor: secondaryTextColor,
                              ),
                              Divider(height: 1, indent: 68, endIndent: 16, color: borderColor),
                              _buildBenefitTile(
                                icon: Icons.schedule_rounded,
                                title: 'Flexible working hours',
                                description:
                                    'Be your own boss. Log in and accept trips whenever it fits your lifestyle.',
                                primaryTextColor: primaryTextColor,
                                secondaryTextColor: secondaryTextColor,
                              ),
                              Divider(height: 1, indent: 68, endIndent: 16, color: borderColor),
                              _buildBenefitTile(
                                icon: Icons.shield_outlined,
                                title: 'Real-time safety & assistance',
                                description:
                                    'Drive with confidence using in-app SOS safety sharing and 24/7 dedicated support.',
                                primaryTextColor: primaryTextColor,
                                secondaryTextColor: secondaryTextColor,
                              ),
                              Divider(height: 1, indent: 68, endIndent: 16, color: borderColor),
                              _buildBenefitTile(
                                icon: Icons.military_tech_outlined,
                                title: 'Driver rewards program',
                                description:
                                    'Unlock special fuel discounts, vehicle maintenance bonuses, and higher rating tier incentives.',
                                primaryTextColor: primaryTextColor,
                                secondaryTextColor: secondaryTextColor,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Sticky CTA footer
          Container(
            padding: EdgeInsets.fromLTRB(
              20,
              12,
              20,
              MediaQuery.of(context).padding.bottom + 16,
            ),
            decoration: BoxDecoration(
              color: cardBg,
              border: Border(top: BorderSide(color: borderColor)),
            ),
            child: ListenableBuilder(
              listenable: customerAuthController,
              builder: (context, _) {
                final alreadyDriver = customerAuthController.driverExists;
                return SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isRegistering
                        ? null
                        : alreadyDriver
                            ? () async {
                                await customerAuthController.switchRole('driver');
                                if (!context.mounted) return;
                                context.go(DriverRoutePaths.home);
                              }
                            : _registerAsDriver,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brand,
                      elevation: 0,
                      disabledBackgroundColor: AppColors.brand.withValues(alpha: 0.4),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(28),
                      ),
                    ),
                    child: _isRegistering
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                          )
                        : Text(
                            alreadyDriver ? 'Switch to Driver App' : 'Register as a Driver',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBenefitTile({
    required IconData icon,
    required String title,
    required String description,
    required Color primaryTextColor,
    required Color secondaryTextColor,
  }) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.brand.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.brand, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: primaryTextColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13,
                    color: secondaryTextColor,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Success BottomSheet with Confetti ─────────────────────────────────────────────
class _DriverSuccessBottomSheet extends StatefulWidget {
  const _DriverSuccessBottomSheet();

  @override
  State<_DriverSuccessBottomSheet> createState() => _DriverSuccessBottomSheetState();
}

class _DriverSuccessBottomSheetState extends State<_DriverSuccessBottomSheet> {
  late final ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _confettiController.play();
    });
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF111827);
    final secondaryTextColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
    final cardBg = isDark ? AppColors.darkSurface : Colors.white;
    final borderColor = isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB);

    return Stack(
      alignment: Alignment.topCenter,
      children: [
        // Confetti emitter
        ConfettiWidget(
          confettiController: _confettiController,
          blastDirectionality: BlastDirectionality.explosive,
          particleDrag: 0.05,
          emissionFrequency: 0.08,
          numberOfParticles: 25,
          gravity: 0.2,
          shouldLoop: false,
          colors: const [
            Color(0xFF16A34A),
            Color(0xFF22C55E),
            Color(0xFFFFB800),
            Color(0xFF3B82F6),
          ],
        ),

        Container(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(top: BorderSide(color: borderColor)),
          ),
          padding: EdgeInsets.fromLTRB(
            24,
            14,
            24,
            MediaQuery.of(context).padding.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : const Color(0xFFD1D5DB),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Celebration icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.brand.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.celebration_rounded,
                  size: 42,
                  color: AppColors.brand,
                ),
              ),
              const SizedBox(height: 18),

              // Title
              Text(
                'Welcome to the Driver Team! 🎉',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: primaryTextColor,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 10),

              // Description
              Text(
                'Your driver account has been created successfully. Complete onboarding to start earning with CaRide!',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: secondaryTextColor,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 28),

              // Switch to Driver button (primary)
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    context.go(DriverRoutePaths.home);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.brand,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  child: const Text(
                    'Switch to Driver App',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Done button
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  context.go(CustomerRoutePaths.profile);
                },
                child: Text(
                  'Done',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: secondaryTextColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
