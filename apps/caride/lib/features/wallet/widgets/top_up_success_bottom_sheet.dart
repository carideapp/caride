import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:shared_widgets/shared_widgets.dart';

class TopUpSuccessBottomSheet extends StatelessWidget {
  const TopUpSuccessBottomSheet({
    super.key,
    required this.creditedAmount,
  });

  final double creditedAmount;

  static Future<void> show(
    BuildContext context, {
    required double creditedAmount,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TopUpSuccessBottomSheet(creditedAmount: creditedAmount),
    );
  }

  @override
  Widget build(BuildContext context) {
    final formatted =
        '₦${creditedAmount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';

    return BottomSheetShell(
      title: 'Top Up Successful',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pagePadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: AppSpacing.md),
            Center(
              child: Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: const BoxDecoration(
                  color: Color(0xFF10B981),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_rounded,
                  color: Colors.white,
                  size: 48,
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Top Up Successful!',
              textAlign: TextAlign.center,
              style: AppTextStyles.headlineSmall.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '$formatted has been credited to your CaRide Wallet.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyLarge,
            ),
            const SizedBox(height: AppSpacing.xl),
            PrimaryButton(
              label: 'Done',
              onPressed: () => Navigator.pop(context),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }
}
