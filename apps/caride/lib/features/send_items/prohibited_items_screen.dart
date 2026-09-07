import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:shared_widgets/shared_widgets.dart';

/// Screen listing prohibited items for CaRide Courier/Connect deliveries.
class ProhibitedItemsScreen extends StatelessWidget {
  const ProhibitedItemsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final bgColor = isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final primaryTextColor = isDark ? Colors.white : AppColors.slate900;
    final mutedTextColor = isDark ? Colors.grey[400]! : const Color(0xFF6E7191);

    final bulletItems = [
      'Illegal items',
      'Firearms, weaponry, and their parts',
      'Alcohol',
      'Highly perishable food or beverages (e.g., raw meat or dairy products)',
      'Pharmaceutical products, over-the-counter medications, vitamins or supplements',
      'Recreational drugs, drug paraphernalia, or tobacco products',
      'Money, giftcards, lottery tickets or transferable securities',
      'Dangerous or hazardous items, including explosives, items that are poisonous or flammable, medical waste and other dangerous or hazardous items as described in the applicable regulations',
      'Stolen goods',
      'Fragile items',
    ];

    return Scaffold(
      backgroundColor: bgColor,
      appBar: const GlassAppBar(
        title: 'Prohibited Items',
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.pagePadding,
            vertical: AppSpacing.md,
          ),
          children: [
            // ── Header/Cover Image ──
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              child: Image.asset(
                'lib/assets/prohibited_items_header.png',
                height: 180,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  height: 180,
                  color: AppColors.error.withValues(alpha: 0.1),
                  child: const Icon(
                    Icons.warning_amber_rounded,
                    size: 48,
                    color: AppColors.error,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // ── Main Heading ──
            Text(
              'Items prohibited from package delivery',
              style: AppTextStyles.titleLarge.copyWith(
                fontWeight: FontWeight.w800,
                color: primaryTextColor,
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // ── Policy Intro ──
            Text(
              'Items sent via CaRide Connect must comply with all laws and regulations and with CaRide\'s policies. Sending illegal, unsafe, or other prohibited items listed on this page is strictly prohibited.',
              style: AppTextStyles.bodyMedium.copyWith(
                color: mutedTextColor,
                height: 1.5,
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            Text(
              'If you send an item in violation of the law or any of our policies, including those listed on this page, we will take corrective actions, as appropriate, including but not limited to, immediately suspending or terminating your account. Sending illegal or unsafe products can also lead to legal action, including civil and criminal penalties.',
              style: AppTextStyles.bodyMedium.copyWith(
                color: mutedTextColor,
                height: 1.5,
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            Text(
              'CaRide encourages you to report items that violate CaRide\'s policies or applicable law by contacting us. We will investigate each report thoroughly and take appropriate action.',
              style: AppTextStyles.bodyMedium.copyWith(
                color: mutedTextColor,
                height: 1.5,
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // ── Illustration/Grid Image ──
            Text(
              'Prohibited Categories',
              style: AppTextStyles.titleMedium.copyWith(
                fontWeight: FontWeight.w700,
                color: primaryTextColor,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadius.lg),
              child: Image.asset(
                'lib/assets/prohibited_items_grid.png',
                height: 140,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // ── List of Prohibited Items ──
            Text(
              'The following items are prohibited from package delivery:',
              style: AppTextStyles.bodyMedium.copyWith(
                fontWeight: FontWeight.bold,
                color: primaryTextColor,
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            GlassContainer(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                children: bulletItems.map((item) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6.0),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 6.0),
                          child: Icon(
                            Icons.cancel_rounded,
                            size: 14,
                            color: AppColors.error,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: Text(
                            item,
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: primaryTextColor,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // ── Disclaimer ──
            Text(
              'The above list of prohibited items is not exhaustive. CaRide retains the discretion to prohibit additional items that are not on the above list.',
              style: AppTextStyles.bodySmall.copyWith(
                color: mutedTextColor,
                fontStyle: FontStyle.italic,
                height: 1.4,
              ),
            ),
            const SizedBox(height: AppSpacing.xxl),
          ],
        ),
      ),
    );
  }
}
