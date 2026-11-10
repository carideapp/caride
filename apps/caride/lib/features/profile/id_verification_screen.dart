import 'package:caride/core/auth/customer_auth_controller.dart';
import 'package:caride/features/profile/data/account_repository.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:navigation/navigation.dart';

/// Customer ID Verification (NIN KYC) Screen.
///
/// Displays the 2D car interior illustration with a verified checkmark badge at
/// the bottom-left, a bold headline, benefits subline, the three verification
/// benefits, and either the action button to verify NIN or bold emerald text
/// `'You're verified!'` once verified.
class IdVerificationScreen extends StatefulWidget {
  const IdVerificationScreen({super.key});

  @override
  State<IdVerificationScreen> createState() => _IdVerificationScreenState();
}

class _IdVerificationScreenState extends State<IdVerificationScreen> {
  final AccountRepository _accountRepo = AccountRepository();

  void _openNinVerificationSheet(BuildContext context, AccountProfile? profile) {
    HapticFeedback.lightImpact();
    showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => _NinEntryBottomSheet(
        accountRepo: _accountRepo,
        customerFullName: profile?.fullName ?? '',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF111827);
    final secondaryTextColor =
        isDark ? AppColors.textSecondaryDark : const Color(0xFF4B5563);
    final borderColor =
        isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB);

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : const Color(0xFFF9FAFB),
      body: SafeArea(
        child: StreamBuilder<AccountProfile?>(
          stream: _accountRepo.watchProfile(),
          initialData: customerAuthController.currentProfile,
          builder: (context, snapshot) {
            final profile =
                snapshot.data ?? customerAuthController.currentProfile;
            final isVerified = profile?.isVerified ?? false;

            return Column(
              children: [
                // ── Top Bar with Circular Back Button ──
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 12.0,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isDark ? AppColors.darkSurface : Colors.white,
                          border: Border.all(color: borderColor),
                        ),
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          icon: Icon(
                            Icons.arrow_back_ios_new_rounded,
                            color: primaryTextColor,
                            size: 18,
                          ),
                          onPressed: () {
                            if (Navigator.canPop(context)) {
                              Navigator.pop(context);
                            } else {
                              context.go(CustomerRoutePaths.profile);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 14),
                      Text(
                        'ID Verification',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: primaryTextColor,
                          letterSpacing: -0.4,
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Main Scrollable Content ──
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 22.0,
                      vertical: 8.0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── 2D Illustration (Woman Passenger & Driver Smiling Inside Car with Bottom-Left Verified Check) ──
                        const _VerificationHeroIllustration(height: 235),
                        const SizedBox(height: 26),

                        // ── Very Big Bold Headline ──
                        Text(
                          'Verify Your Identity',
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                            color: primaryTextColor,
                            height: 1.15,
                            letterSpacing: -0.7,
                          ),
                        ),
                        const SizedBox(height: 10),

                        // ── Benefits Subline ──
                        Text(
                          'Verify your account with your National Identification Number (NIN) to enjoy full access and exclusive passenger benefits:',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                            color: secondaryTextColor,
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 24),

                        // ── Benefits Section ──
                        const _VerificationBenefitsList(),

                        if (isVerified &&
                            profile?.maskedNin != null &&
                            profile!.maskedNin!.isNotEmpty) ...[
                          const SizedBox(height: 18),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.brand.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: AppColors.brand.withValues(alpha: 0.25),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.shield_rounded,
                                  color: AppColors.brand,
                                  size: 18,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Verified NIN: ${profile.maskedNin}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: isDark
                                          ? Colors.white
                                          : const Color(0xFF065F46),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),

                // ── Bottom Action Section ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
                  child: isVerified
                      ? Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            vertical: 16,
                            horizontal: 20,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.brand.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(
                              color: AppColors.brand.withValues(alpha: 0.35),
                            ),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.verified_rounded,
                                color: AppColors.brand,
                                size: 24,
                              ),
                              SizedBox(width: 10),
                              Text(
                                "You're verified!",
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.brand,
                                  letterSpacing: -0.3,
                                ),
                              ),
                            ],
                          ),
                        )
                      : SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.brand,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(28),
                              ),
                            ),
                            icon: const Icon(
                              Icons.verified_user_rounded,
                              size: 20,
                            ),
                            label: const Text(
                              'Verify with NIN',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            onPressed: () =>
                                _openNinVerificationSheet(context, profile),
                          ),
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Bottom Sheet Design Replica of [IdVerificationScreen].
///
/// Triggered when an unverified user clicks "Withdraw" on `WalletScreen` or
/// toggles "Use Subsidy Wallet" on Step 3 (`FareStep`) of ride booking.
/// Displays the replica illustration, headline, notice, and benefits list with
/// a `"Verify Now"` button that navigates to [IdVerificationScreen].
class IdVerificationPromptBottomSheet extends StatelessWidget {
  const IdVerificationPromptBottomSheet({
    super.key,
    required this.noticeMessage,
  });

  final String noticeMessage;

  static Future<void> show(
    BuildContext context, {
    String noticeMessage =
        'Only verified users can withdraw from their wallet and use the Subsidy Wallet during ride booking.',
  }) {
    HapticFeedback.mediumImpact();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => IdVerificationPromptBottomSheet(
        noticeMessage: noticeMessage,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF111827);
    final secondaryTextColor =
        isDark ? AppColors.textSecondaryDark : const Color(0xFF4B5563);

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      ),
      padding: EdgeInsets.only(
        left: 22,
        right: 22,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag Handle & Close Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox(width: 32),
                Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white24 : const Color(0xFFE5E7EB),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(
                    Icons.close_rounded,
                    color: secondaryTextColor,
                    size: 22,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // ── 2D Illustration Replica ──
            const _VerificationHeroIllustration(height: 195),
            const SizedBox(height: 20),

            // ── Contextual Notice Pill ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    color: Color(0xFFD97706),
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      noticeMessage,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: isDark
                            ? const Color(0xFFFCD34D)
                            : const Color(0xFF92400E),
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // ── Very Big Bold Headline ──
            Text(
              'Verify Your Identity',
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: primaryTextColor,
                height: 1.15,
                letterSpacing: -0.6,
              ),
            ),
            const SizedBox(height: 8),

            // ── Benefits Subline ──
            Text(
              'Complete a quick 1-minute NIN check to unlock full account privileges:',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: secondaryTextColor,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 18),

            // ── Benefits List ──
            const _VerificationBenefitsList(),
            const SizedBox(height: 24),

            // ── "Verify Now" Primary Action Button ──
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brand,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
                icon: const Icon(Icons.verified_rounded, size: 20),
                label: const Text(
                  'Verify Now',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                onPressed: () {
                  final router = GoRouter.of(context);
                  Navigator.of(context).pop();
                  router.push(CustomerRoutePaths.idVerification);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shared 2D Illustration Card with bottom-left verified check badge reinforcement.
class _VerificationHeroIllustration extends StatelessWidget {
  const _VerificationHeroIllustration({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: isDark ? const Color(0xFF0F291E) : const Color(0xFFECFDF5),
        border: Border.all(
          color: AppColors.brand.withValues(alpha: 0.22),
          width: 1.2,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'lib/assets/id_verification_hero.png',
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) {
              return Container(
                color: isDark
                    ? const Color(0xFF0F291E)
                    : const Color(0xFFECFDF5),
                child: const Center(
                  child: Icon(
                    Icons.directions_car_filled_rounded,
                    size: 72,
                    color: AppColors.brand,
                  ),
                ),
              );
            },
          ),
          // Crisp Verified Check Badge overlay at Bottom-Left
          Positioned(
            left: 14,
            bottom: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 7,
              ),
              decoration: BoxDecoration(
                color: AppColors.brand,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.22),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.verified_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'Verified Passenger',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shared 3-item benefits list for [IdVerificationScreen] and [IdVerificationPromptBottomSheet].
class _VerificationBenefitsList extends StatelessWidget {
  const _VerificationBenefitsList();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? AppColors.darkSurface : Colors.white;
    final borderColor =
        isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: borderColor),
      ),
      padding: const EdgeInsets.all(18),
      child: const Column(
        children: [
          _BenefitRow(
            icon: Icons.verified_rounded,
            title: 'Gain a verified badge',
            subtitle:
                'Stand out as a trusted passenger with an official verified badge beside your name.',
          ),
          Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Divider(height: 1),
          ),
          _BenefitRow(
            icon: Icons.account_balance_wallet_rounded,
            title: 'Be able to withdraw from your wallet',
            subtitle:
                'Transfer funds from your CaRide wallet directly to your bank account anytime.',
          ),
          Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: Divider(height: 1),
          ),
          _BenefitRow(
            icon: Icons.savings_rounded,
            title: 'Be able to use subsidy wallet during ride booking',
            subtitle:
                'Apply your Subsidy Wallet balance to discount your ride fares on every trip.',
          ),
        ],
      ),
    );
  }
}

class _BenefitRow extends StatelessWidget {
  const _BenefitRow({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF111827);
    final secondaryTextColor =
        isDark ? AppColors.textSecondaryDark : const Color(0xFF6B7280);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: AppColors.brand.withValues(alpha: 0.14),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: AppColors.brand,
            size: 22,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.w800,
                  color: primaryTextColor,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: secondaryTextColor,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Interactive Bottom Sheet where the customer enters their 11-digit NIN to verify.
class _NinEntryBottomSheet extends StatefulWidget {
  const _NinEntryBottomSheet({
    required this.accountRepo,
    required this.customerFullName,
  });

  final AccountRepository accountRepo;
  final String customerFullName;

  @override
  State<_NinEntryBottomSheet> createState() => _NinEntryBottomSheetState();
}

class _NinEntryBottomSheetState extends State<_NinEntryBottomSheet> {
  final TextEditingController _ninCtrl = TextEditingController();
  bool _submitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _ninCtrl.dispose();
    super.dispose();
  }

  Future<void> _submitNin() async {
    final raw = _ninCtrl.text.trim().replaceAll(' ', '');
    if (raw.length != 11 && raw.length != 16) {
      setState(() {
        _errorMessage =
            'Please enter a valid 11-digit National Identification Number (NIN).';
      });
      return;
    }

    setState(() {
      _submitting = true;
      _errorMessage = null;
    });

    try {
      await widget.accountRepo.verifyCustomerNin(raw);
      HapticFeedback.heavyImpact();
      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("You're verified! Your NIN verification was successful."),
          backgroundColor: AppColors.brand,
        ),
      );
    } catch (e) {
      HapticFeedback.vibrate();
      if (!mounted) return;
      final cleanErr = e.toString().replaceFirst('Exception: ', '').trim();
      setState(() {
        _submitting = false;
        _errorMessage = cleanErr.isNotEmpty
            ? cleanErr
            : 'Verification is currently unavailable at the moment, please try again later';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF111827);
    final secondaryTextColor =
        isDark ? AppColors.textSecondaryDark : const Color(0xFF4B5563);
    final borderColor =
        isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB);

    return Container(
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        left: 22,
        right: 22,
        top: 14,
        bottom: MediaQuery.of(context).viewInsets.bottom + 26,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white24 : const Color(0xFFE5E7EB),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.brand.withValues(alpha: 0.14),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.badge_rounded,
                    color: AppColors.brand,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Enter Your NIN',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: primaryTextColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Your 11-digit National Identification Number',
                        style: TextStyle(
                          fontSize: 13,
                          color: secondaryTextColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            if (widget.customerFullName.trim().isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.04)
                      : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.person_outline_rounded,
                      size: 18,
                      color: secondaryTextColor,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Matching against profile name: ${widget.customerFullName}',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: secondaryTextColor,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
            ],

            TextField(
              controller: _ninCtrl,
              enabled: !_submitting,
              keyboardType: TextInputType.number,
              maxLength: 11,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(11),
              ],
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                letterSpacing: 2.0,
                color: primaryTextColor,
              ),
              decoration: InputDecoration(
                labelText: '11-Digit NIN',
                hintText: 'e.g. 12345678901',
                counterText: '',
                filled: true,
                fillColor: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : const Color(0xFFF9FAFB),
                prefixIcon: const Icon(
                  Icons.dialpad_rounded,
                  color: AppColors.brand,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: borderColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: borderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(
                    color: AppColors.brand,
                    width: 1.8,
                  ),
                ),
              ),
              onChanged: (_) {
                if (_errorMessage != null) {
                  setState(() => _errorMessage = null);
                }
              },
            ),
            const SizedBox(height: 8),

            Row(
              children: [
                Icon(
                  Icons.lock_outline_rounded,
                  size: 14,
                  color: secondaryTextColor,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Encrypted & NDPR compliant. Dial *346# on your registered phone to check your NIN.',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: secondaryTextColor,
                    ),
                  ),
                ),
              ],
            ),

            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.error.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      color: AppColors.error,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.error,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 22),

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
                onPressed: _submitting ? null : _submitNin,
                child: _submitting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Verify Identity',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
