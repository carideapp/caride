import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:navigation/navigation.dart';
import 'package:shared_widgets/shared_widgets.dart';

/// Redesigned Customer Help & Support FAQ Screen.
class HelpSupportScreen extends StatefulWidget {
  const HelpSupportScreen({super.key});

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen> {
  final List<FAQItem> _faqs = [
    FAQItem(
      question: 'How do I book a ride?',
      answer: 'On the home screen, tap the search bar to enter your destination. Set your target price, select a ride type, and tap "Request Ride" to start receiving offers from drivers nearby.',
    ),
    FAQItem(
      question: 'How is the fare calculated?',
      answer: 'CaRide uses a unique driver-bidding model where you suggest an initial price, and drivers bid with their best offers. You can choose the driver with the rating, vehicle, or price that matches your preference.',
    ),
    FAQItem(
      question: 'Can I cancel a ride?',
      answer: 'Yes. You can cancel a ride request before it is accepted or after a driver has been matched. Please note that cancellations should only be made if necessary to keep the platform fair for everyone.',
    ),
    FAQItem(
      question: 'How do I top up my wallet?',
      answer: 'Navigate to Account > Wallet > Top Up. Select your top-up amount, choose a payment method (e.g. Paystack Card or Bank Transfer), and follow the prompt to secure your top up.',
    ),
    FAQItem(
      question: 'How do I save a card?',
      answer: 'When topping up your wallet with a credit/debit card, the system will automatically prompt you to save the card if you proceed with a card transaction. Reusable cards will then appear in your payment methods list.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: GlassAppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
        title: 'Help & Support',
      ),
      body: SafeArea(
        child: ResponsiveContainer(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.pagePadding,
                    vertical: AppSpacing.lg,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionHeader(
                        context: context,
                        title: 'Frequently Asked Questions',
                        subtitle: 'Tap a question below to read the helpful answer',
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      GlassContainer(
                        padding: EdgeInsets.zero,
                        child: ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _faqs.length,
                          separatorBuilder: (context, index) => Divider(
                            height: 1,
                            color: isDark ? AppColors.glassBorderDark : AppColors.glassBorderLight,
                          ),
                          itemBuilder: (context, index) => _buildFAQTile(_faqs[index]),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.pagePadding,
                  vertical: AppSpacing.md,
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: PrimaryButton(
                    label: 'Chat with Support',
                    onPressed: () => context.push(CustomerRoutePaths.supportChat),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader({
    required BuildContext context,
    required String title,
    required String subtitle,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTextStyles.titleMedium,
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: AppTextStyles.bodySmall.copyWith(
            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
          ),
        ),
      ],
    );
  }

  Widget _buildFAQTile(FAQItem item) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Theme(
      data: theme.copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        title: Text(
          item.question,
          style: AppTextStyles.bodyLarge.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        iconColor: AppColors.brand,
        collapsedIconColor: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
        childrenPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Text(
              item.answer,
              style: AppTextStyles.bodyMedium.copyWith(
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class FAQItem {
  FAQItem({required this.question, required this.answer});
  final String question;
  final String answer;
}
