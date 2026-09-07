import 'package:confetti/confetti.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:caride/features/driver/earnings/data/driver_withdraw_repository.dart';
import 'package:shared_widgets/shared_widgets.dart';

class DriverWithdrawSuccessScreen extends StatefulWidget {
  const DriverWithdrawSuccessScreen({
    super.key,
    required this.resolved,
    required this.amountNaira,
    required this.reference,
  });

  final ResolvedAccount resolved;
  final double amountNaira;
  final String reference;

  @override
  State<DriverWithdrawSuccessScreen> createState() => _DriverWithdrawSuccessScreenState();
}

class _DriverWithdrawSuccessScreenState extends State<DriverWithdrawSuccessScreen>
    with TickerProviderStateMixin {
  late final ConfettiController _confettiController;
  late final AnimationController _scaleController;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 5));
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _scaleAnim = CurvedAnimation(
      parent: _scaleController,
      curve: Curves.elasticOut,
    );

    // Fire confetti & scale animation after a short delay
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _confettiController.play();
        _scaleController.forward();
      }
    });
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  String _formatNaira(double value) {
    final rounded = value.round().toString();
    return '₦${rounded.replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: Stack(
        children: [
          // Main content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.pagePadding),
              child: Column(
                children: [
                  const Spacer(),

                  // Animated success icon
                  ScaleTransition(
                    scale: _scaleAnim,
                    child: Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [Color(0xFF16A34A), Color(0xFF1db954)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.brand.withValues(alpha: 0.40),
                            blurRadius: 32,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.check_rounded,
                        color: Colors.white,
                        size: 60,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // Headline
                  Text(
                    'Transfer Initiated! 🎉',
                    style: AppTextStyles.headlineMedium.copyWith(
                      fontWeight: FontWeight.w900,
                      height: 1.2,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Your withdrawal has been processed successfully.\nYou will receive your money within 24 hours.',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: isDark
                          ? AppColors.textSecondaryDark
                          : AppColors.textSecondaryLight,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: AppSpacing.xl),

                  // Transfer summary card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : const Color(0xFFE5E7EB),
                      ),
                      boxShadow: isDark
                          ? null
                          : [
                              const BoxShadow(
                                color: Color(0x0A000000),
                                blurRadius: 20,
                                offset: Offset(0, 8),
                                                        ),
                            ],
                    ),
                    child: Column(
                      children: [
                        _SummaryRow(
                          label: 'Amount',
                          value: _formatNaira(widget.amountNaira),
                          valueColor: AppColors.brand,
                          valueBold: true,
                        ),
                        const Divider(height: AppSpacing.lg),
                        _SummaryRow(
                          label: 'Account Name',
                          value: widget.resolved.accountName,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        _SummaryRow(
                          label: 'Bank',
                          value: widget.resolved.bankName,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        _SummaryRow(
                          label: 'Account Number',
                          value: widget.resolved.accountNumber,
                        ),
                        const Divider(height: AppSpacing.lg),
                        _SummaryRow(
                          label: 'Reference',
                          value: widget.reference,
                          mono: true,
                        ),
                        const SizedBox(height: AppSpacing.xs),
                        _SummaryRow(
                          label: 'Status',
                          value: 'Processing',
                          valueColor: const Color(0xFFD97706),
                          valueBold: true,
                        ),
                      ],
                    ),
                  ),

                  const Spacer(),

                  // Done button
                  PrimaryButton(
                    label: 'Done',
                    onPressed: () {
                      // Pop all withdraw screens back to wallet
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    },
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
              ),
            ),
          ),

          // Confetti layer (top center, rendered over main content)
          IgnorePointer(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confettiController,
                blastDirectionality: BlastDirectionality.explosive,
                particleDrag: 0.05,
                emissionFrequency: 0.07,
                numberOfParticles: 24,
                gravity: 0.18,
                colors: const [
                  Color(0xFF16A34A),
                  Color(0xFF1db954),
                  Color(0xFFFFD700),
                  Colors.white,
                  Color(0xFF22c55e),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.valueBold = false,
    this.mono = false,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final bool valueBold;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: AppTextStyles.bodySmall.copyWith(
            color: isDark
                ? AppColors.textSecondaryDark
                : AppColors.textSecondaryLight,
          ),
        ),
        Flexible(
          child: Text(
            value,
            style: AppTextStyles.bodySmall.copyWith(
              fontWeight: valueBold ? FontWeight.w800 : FontWeight.w600,
              color: valueColor,
              fontFamily: mono ? 'monospace' : null,
            ),
            textAlign: TextAlign.end,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
