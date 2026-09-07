import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:shared_widgets/shared_widgets.dart';

enum TopUpMethodOption { bankTransfer, card }

class TopUpMethodBottomSheet extends StatefulWidget {
  const TopUpMethodBottomSheet({
    super.key,
    required this.amountNaira,
  });

  final double amountNaira;

  static Future<TopUpMethodOption?> show(
    BuildContext context, {
    required double amountNaira,
  }) {
    return showModalBottomSheet<TopUpMethodOption>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TopUpMethodBottomSheet(amountNaira: amountNaira),
    );
  }

  @override
  State<TopUpMethodBottomSheet> createState() => _TopUpMethodBottomSheetState();
}

class _TopUpMethodBottomSheetState extends State<TopUpMethodBottomSheet> {
  TopUpMethodOption _selected = TopUpMethodOption.bankTransfer;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final formattedAmount =
        '₦${widget.amountNaira.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},')}';

    return BottomSheetShell(
      title: 'Top Up Payment Method',
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pagePadding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Amount preview banner
            GlassContainer(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Top Up Amount',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    ),
                  ),
                  Text(
                    formattedAmount,
                    style: AppTextStyles.titleLarge.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.brand,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Bank Transfer Option
            _MethodTile(
              icon: Icons.account_balance_outlined,
              title: 'Bank Transfer',
              subtitle: 'Pay via bank account transfer',
              selected: _selected == TopUpMethodOption.bankTransfer,
              onTap: () => setState(() => _selected = TopUpMethodOption.bankTransfer),
            ),
            const SizedBox(height: AppSpacing.sm),

            // Card Option
            _MethodTile(
              icon: Icons.credit_card_rounded,
              title: 'Debit / Credit Card',
              subtitle: 'Pay with saved or new card',
              selected: _selected == TopUpMethodOption.card,
              onTap: () => setState(() => _selected = TopUpMethodOption.card),
            ),
            const SizedBox(height: AppSpacing.xl),

            PrimaryButton(
              label: 'Continue',
              onPressed: () {
                Navigator.pop(context, _selected);
              },
            ),
            const SizedBox(height: AppSpacing.md),
          ],
        ),
      ),
    );
  }
}

class _MethodTile extends StatelessWidget {
  const _MethodTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: GlassContainer(
        padding: const EdgeInsets.all(AppSpacing.md),
        borderColor: selected
            ? AppColors.brand
            : (isDark ? AppColors.glassBorderDark : AppColors.glassBorderLight),
        borderWidth: selected ? 2 : 1,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.brandGlass
                    : (isDark ? const Color(0xFF2E2E2E) : const Color(0xFFF1F5F9)),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: selected
                    ? AppColors.brand
                    : (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    subtitle,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
              color: selected ? AppColors.brand : Colors.grey,
            ),
          ],
        ),
      ),
    );
  }
}
