import 'package:caride/core/auth/customer_auth_controller.dart';
import 'package:caride/core/driver/auth/driver_auth_controller.dart';
import 'package:caride/features/driver/auth/data/driver_profile_repository.dart';
import 'package:confetti/confetti.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:navigation/navigation.dart';
import 'package:shared_widgets/shared_widgets.dart';

/// "Become a Customer" benefits screen for drivers — mirrors the
/// BecomeDriverBenefitsScreen layout. Provisions a customer account
/// using the driver's existing profile data (email, fullName, phone).
class BecomeCustomerBenefitsScreen extends StatefulWidget {
  const BecomeCustomerBenefitsScreen({super.key});

  @override
  State<BecomeCustomerBenefitsScreen> createState() =>
      _BecomeCustomerBenefitsScreenState();
}

class _BecomeCustomerBenefitsScreenState
    extends State<BecomeCustomerBenefitsScreen> {
  bool _isRegistering = false;
  String? _errorMessage;
  final _profileRepo = DriverProfileRepository();

  Future<void> _registerAsCustomer() async {
    setState(() {
      _isRegistering = true;
      _errorMessage = null;
    });
    try {
      final uid = driverAuthController.currentUid;
      final email = driverAuthController.currentEmail ?? '';

      // Fetch driver profile to get fullName & phone
      String? fullName;
      String? phone;
      String? profilePhotoUrl;
      if (uid != null) {
        final profile = await _profileRepo.getDriverProfile(uid);
        fullName = profile?.fullName;
        phone = profile?.phone;
        profilePhotoUrl = profile?.profilePhotoUrl;
      }

      await driverAuthController.becomeCustomer(
        email: email,
        fullName: fullName,
        phone: phone,
        profilePhotoUrl: profilePhotoUrl,
      );

      if (!mounted) return;
      await _showSuccessDialog();
    } catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage =
          'Failed to create customer account. Please try again.');
    } finally {
      if (mounted) setState(() => _isRegistering = false);
    }
  }

  Future<void> _showSuccessDialog() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const _CustomerSuccessDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
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
                      SizedBox(
                        height: 300,
                        width: double.infinity,
                        child: Image.asset(
                          'lib/assets/passenger_hero.png',
                          fit: BoxFit.cover,
                        ),
                      ),
                      // Gradient scrim
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        height: 120,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                (isDark
                                        ? AppColors.darkBackground
                                        : AppColors.lightBackground)
                                    .withValues(alpha: 0.98),
                              ],
                            ),
                          ),
                        ),
                      ),
                      // Back button
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
                        Text(
                          'Ride with CaRide\nas a Passenger',
                          style: AppTextStyles.headlineLarge.copyWith(
                            fontWeight: FontWeight.w900,
                            height: 1.15,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          'Unlock the full CaRide experience. Book rides anytime, send packages, and enjoy premium passenger perks — all from the same account.',
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
                          icon: Icons.local_taxi_rounded,
                          title: 'Book rides instantly',
                          description:
                              'Request a ride in seconds. Choose from standard, comfort, or premium vehicle tiers based on your mood.',
                        ),
                        const _Divider(),
                        _BenefitRow(
                          icon: Icons.inventory_2_outlined,
                          title: 'Send parcels & packages',
                          description:
                              'Use CaRide courier to send items across the city with real-time tracking and delivery confirmation.',
                        ),
                        const _Divider(),
                        _BenefitRow(
                          icon: Icons.wallet_rounded,
                          title: 'In-app wallet & cashback',
                          description:
                              'Top up your wallet and earn cashback rewards on every ride. Refer friends for bonus credits.',
                        ),
                        const _Divider(),
                        _BenefitRow(
                          icon: Icons.people_outline_rounded,
                          title: 'Referral rewards',
                          description:
                              'Share your unique referral code and earn bonus ride credits every time a friend signs up and takes a ride.',
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
                final alreadyCustomer = customerAuthController.customerExists;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_errorMessage != null) ...[
                      InlineError(message: _errorMessage!),
                      const SizedBox(height: AppSpacing.sm),
                    ],
                    PrimaryButton(
                      label: alreadyCustomer
                          ? 'Switch to Passenger App'
                          : 'Register as a Passenger',
                      isLoading: _isRegistering,
                      onPressed: alreadyCustomer
                          ? () async {
                              await customerAuthController.switchRole('customer');
                              if (!context.mounted) return;
                              context.go(CustomerRoutePaths.home);
                            }
                          : _registerAsCustomer,
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
class _CustomerSuccessDialog extends StatefulWidget {
  const _CustomerSuccessDialog();

  @override
  State<_CustomerSuccessDialog> createState() => _CustomerSuccessDialogState();
}

class _CustomerSuccessDialogState extends State<_CustomerSuccessDialog> {
  late final ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 4));
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
                    Icons.directions_car_rounded,
                    size: 42,
                    color: AppColors.brand,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Title
                Text(
                  'Welcome as a\nPassenger! 🎉',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.headlineMedium.copyWith(
                    fontWeight: FontWeight.w900,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),

                // Description
                Text(
                  'Your passenger account has been created using your existing profile. You can now book rides and send packages!',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),

                // Switch to Customer button (primary)
                PrimaryButton(
                  label: 'Switch to Passenger',
                  onPressed: () {
                    Navigator.of(context).pop();
                    context.go(CustomerRoutePaths.home);
                  },
                ),
                const SizedBox(height: AppSpacing.sm),

                // Done button
                SecondaryButton(
                  label: 'Done',
                  onPressed: () {
                    Navigator.of(context).pop();
                    context.go(DriverRoutePaths.profile);
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

// ── Benefit row ──────────────────────────────────────────────────────────────
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
