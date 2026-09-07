import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:navigation/navigation.dart';
import 'package:shared_widgets/shared_widgets.dart';

class DriverHelpFaqScreen extends StatelessWidget {
  const DriverHelpFaqScreen({super.key});

  static const _faqs = [
    _FaqItem(
      question: 'How do I start accepting ride requests?',
      answer:
          'After completing your onboarding and uploading all required documents, '
          'go to the Drive tab, toggle yourself online, and ride requests from '
          'nearby customers will start appearing.',
    ),
    _FaqItem(
      question: 'How do I withdraw my earnings?',
      answer:
          'Navigate to Wallet → Withdraw funds. Enter your bank account details '
          'and the amount you wish to withdraw. Payouts are processed within 24 hours.',
    ),
    _FaqItem(
      question: 'What documents are required?',
      answer:
          'You need a valid Nigeria Driver Licence, National Identity Card, '
          'LASRRA Card, LASDRI Card, and a clear profile picture. '
          'Lagos State Driver Badge is optional but recommended.',
    ),
    _FaqItem(
      question: 'How do driver tiers work?',
      answer:
          'CaRide has four tiers: Bronze, Silver, Gold, and Platinum. '
          'Higher tiers unlock lower commission rates and priority access '
          'to premium ride requests. Tiers are based on trip count and ratings.',
    ),
    _FaqItem(
      question: 'How is my rating calculated?',
      answer:
          'Your rating is the average of all rider reviews over the last 500 trips. '
          'Maintaining a rating above 4.7 helps you unlock higher tiers.',
    ),
    _FaqItem(
      question: 'What if I need to cancel a trip?',
      answer:
          'You can cancel before arriving at the pickup point, but frequent '
          'cancellations may affect your acceptance rate and tier standing. '
          "Contact support if there's an emergency.",
    ),
    _FaqItem(
      question: 'How do I contact support?',
      answer:
          'You can reach CaRide Driver Support via the in-app chat, '
          'or email us at drivers@caride.ng. Our support team is available 24/7.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final backgroundColor =
        isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final surfaceColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final borderColor =
        isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFE9EAF0);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        title: Text(
          'Help & FAQs',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SafeArea(
        child: ResponsiveContainer(
          child: ListView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xs,
              vertical: AppSpacing.sm,
            ),
            children: [
              // Styled Info Banner / Header Card
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: borderColor),
                  boxShadow: isDark
                      ? null
                      : [
                          const BoxShadow(
                            color: Color(0x0F0F172A),
                            blurRadius: 18,
                            offset: Offset(0, 8),
                          ),
                        ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.sm),
                      decoration: BoxDecoration(
                        color: AppColors.primaryGreen.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.support_agent_rounded,
                        color: AppColors.primaryGreen,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Need support?',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : AppColors.slate900,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Email us at drivers@caride.ng',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: isDark ? Colors.grey[400] : const Color(0xFF6E7191),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.lg),

              // FAQ List Card
              Container(
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: borderColor),
                  boxShadow: isDark
                      ? null
                      : [
                          const BoxShadow(
                            color: Color(0x0F0F172A),
                            blurRadius: 18,
                            offset: Offset(0, 8),
                          ),
                        ],
                ),
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                child: Column(
                  children: _faqs.map((faq) {
                    return Theme(
                      data: theme.copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        tilePadding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.md,
                          vertical: AppSpacing.xs,
                        ),
                        childrenPadding: const EdgeInsets.fromLTRB(
                          AppSpacing.md,
                          0,
                          AppSpacing.md,
                          AppSpacing.md,
                        ),
                        leading: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.primaryGreen.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(AppRadius.md),
                          ),
                          child: const Icon(
                            Icons.help_outline_rounded,
                            color: AppColors.primaryGreen,
                            size: 18,
                          ),
                        ),
                        title: Text(
                          faq.question,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : AppColors.slate900,
                          ),
                        ),
                        iconColor: AppColors.primaryGreen,
                        collapsedIconColor: Colors.grey[400],
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(left: 48.0),
                            child: Text(
                              faq.answer,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: isDark ? Colors.grey[300] : const Color(0xFF4A4D70),
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                child: PrimaryButton(
                  label: 'Contact Customer Care',
                  onPressed: () => context.push(DriverRoutePaths.helpSupport),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
            ],
          ),
        ),
      ),
    );
  }
}

class _FaqItem {
  const _FaqItem({required this.question, required this.answer});
  final String question;
  final String answer;
}
