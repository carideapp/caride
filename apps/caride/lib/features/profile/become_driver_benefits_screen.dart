import 'package:caride/core/auth/customer_auth_controller.dart';
import 'package:confetti/confetti.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:navigation/navigation.dart';
import 'package:shared_widgets/shared_widgets.dart';

/// Redesigned "Become a Driver" benefits screen matching the Uber-style
/// layout: full-bleed hero image → scrollable content → sticky CTA.
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
      // Show the success dialog with confetti
      await _showSuccessDialog();
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Failed to create driver account. Please try again.');
    } finally {
      if (mounted) setState(() => _isRegistering = false);
    }
  }

  Future<void> _showSuccessDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const _DriverSuccessDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      // No app bar — we overlay the back button on the image
      body: Column(
        children: [
          // ── Scrollable body ───────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── Hero image (full-bleed) ──────────────────────────
                  Stack(
                    children: [
                      // Hero photo
                      SizedBox(
                        height: 300,
                        width: double.infinity,
                        child: Image.asset(
                          'lib/assets/driver_hero.png',
                          fit: BoxFit.cover,
                        ),
                      ),
                      // Gradient scrim at bottom of image for readability
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        height: 80,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                (isDark ? AppColors.darkBackground : AppColors.lightBackground)
                                    .withValues(alpha: 0.95),
                              ],
                            ),
                          ),
                        ),
                      ),
                      // Close / back button
                      Positioned(
                        top: MediaQuery.of(context).padding.top + 12,
                        left: 16,
                        child: GestureDetector(
                          onTap: () => Navigator.of(context).pop(),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.90),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.15),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.close_rounded,
                              size: 20,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  // ── Content section ──────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.pagePadding,
                      AppSpacing.md,
                      AppSpacing.pagePadding,
                      AppSpacing.pagePadding,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title
                        Text(
                          'Drive & Earn on\nYour Schedule',
                          style: AppTextStyles.headlineLarge.copyWith(
                            fontWeight: FontWeight.w900,
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        // Subtitle
                        Text(
                          'Join the CaRide driver community and unlock premium benefits, flexible hours, and consistent payouts.',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xl),

                        // ── Benefit rows ─────────────────────────────
                        _BenefitRow(
                          icon: Icons.monetization_on_outlined,
                          title: 'High earnings & low service fees',
                          description:
                              'Keep more of what you earn with our transparent payment model — get paid anytime directly to your wallet.',
                        ),
                        const _Divider(),
                        _BenefitRow(
                          icon: Icons.alarm_on_outlined,
                          title: 'Flexible hours',
                          description:
                              'Be your own boss. Work whenever it fits your lifestyle — full-time or just a few hours a week.',
                        ),
                        const _Divider(),
                        _BenefitRow(
                          icon: Icons.security_outlined,
                          title: 'Real-time safety & support',
                          description:
                              'Drive confidently with 24/7 in-app emergency buttons and driver-focused premium support.',
                        ),
                        const _Divider(),
                        _BenefitRow(
                          icon: Icons.trending_up_rounded,
                          title: 'Driver rewards program',
                          description:
                              'Unlock special fuel discounts, vehicle maintenance bonuses, and higher rating tier perks.',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Sticky CTA footer ─────────────────────────────────────────
          Container(
            color: isDark ? AppColors.darkBackground : AppColors.lightBackground,
            padding: EdgeInsets.fromLTRB(
              AppSpacing.pagePadding,
              AppSpacing.md,
              AppSpacing.pagePadding,
              MediaQuery.of(context).padding.bottom + AppSpacing.md,
            ),
            child: ListenableBuilder(
              listenable: customerAuthController,
              builder: (context, _) {
                final alreadyDriver = customerAuthController.driverExists;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_errorMessage != null) ...[
                      InlineError(message: _errorMessage!),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                    PrimaryButton(
                      label: alreadyDriver ? 'Switch to Driver App' : 'Register as a Driver',
                      isLoading: _isRegistering,
                      onPressed: alreadyDriver
                          ? () async {
                              await customerAuthController.switchRole('driver');
                              if (!context.mounted) return;
                              context.go(DriverRoutePaths.home);
                            }
                          : _registerAsDriver,
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Success Dialog with Confetti ─────────────────────────────────────────────
class _DriverSuccessDialog extends StatefulWidget {
  const _DriverSuccessDialog();

  @override
  State<_DriverSuccessDialog> createState() => _DriverSuccessDialogState();
}

class _DriverSuccessDialogState extends State<_DriverSuccessDialog> {
  late final ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 4));
    // Fire confetti shortly after dialog opens
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

    return Stack(
      alignment: Alignment.topCenter,
      children: [
        // ── Confetti emitter ──────────────────────────────────────────
        ConfettiWidget(
          confettiController: _confettiController,
          blastDirectionality: BlastDirectionality.explosive,
          particleDrag: 0.05,
          emissionFrequency: 0.08,
          numberOfParticles: 25,
          gravity: 0.2,
          shouldLoop: false,
          colors: const [
            Color(0xFF6C63FF),
            Color(0xFF00C896),
            Color(0xFFFFB800),
            Color(0xFFFF4F4F),
            Color(0xFF00BFFF),
            Color(0xFFFF69B4),
          ],
        ),

        // ── Dialog content ────────────────────────────────────────────
        Dialog(
          backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.xl),
          ),
          insetPadding: const EdgeInsets.symmetric(horizontal: 28),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Celebration icon
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.brandGlass,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.celebration_rounded,
                    size: 42,
                    color: AppColors.brand,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Title
                Text(
                  'Welcome to the\nDriver Team! 🎉',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.headlineMedium.copyWith(
                    fontWeight: FontWeight.w900,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),

                // Description
                Text(
                  'Your driver account has been created successfully using your existing profile. Complete onboarding to start earning!',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),

                // Switch to Driver button (primary)
                PrimaryButton(
                  label: 'Switch to Driver',
                  onPressed: () {
                    Navigator.of(context).pop();
                    context.go(DriverRoutePaths.home);
                  },
                ),
                const SizedBox(height: AppSpacing.sm),

                // Done button (secondary / text)
                SecondaryButton(
                  label: 'Done',
                  onPressed: () {
                    Navigator.of(context).pop();
                    // Navigate back to the account screen
                    context.go(CustomerRoutePaths.profile);
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ── Benefit row ─────────────────────────────────────────────────────────────
class _BenefitRow extends StatelessWidget {
  const _BenefitRow({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Branded icon chip
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.brandGlass,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.brand, size: 22),
          ),
          const SizedBox(width: AppSpacing.md),
          // Text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.bodyLarge.copyWith(
                    fontWeight: FontWeight.w800,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                    height: 1.5,
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

// ── Hairline divider ─────────────────────────────────────────────────────────
class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Divider(
      height: 1,
      thickness: 0.8,
      color: isDark
          ? Colors.white.withValues(alpha: 0.08)
          : Colors.black.withValues(alpha: 0.08),
    );
  }
}
