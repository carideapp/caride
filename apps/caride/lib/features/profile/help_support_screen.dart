import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

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
      answer:
          'On the home screen, tap the search bar to enter your destination. Set your target price, select a ride type, and tap "Request Ride" to start receiving offers from drivers nearby.',
    ),
    FAQItem(
      question: 'How is the fare calculated?',
      answer:
          'CaRide uses a unique driver-bidding model where you suggest an initial price, and drivers bid with their best offers. You can choose the driver with the rating, vehicle, or price that matches your preference.',
    ),
    FAQItem(
      question: 'Can I cancel a ride?',
      answer:
          'Yes. You can cancel a ride request before it is accepted or after a driver has been matched. Please note that cancellations should only be made if necessary to keep the platform fair for everyone.',
    ),
    FAQItem(
      question: 'How do I top up my wallet?',
      answer:
          'Navigate to Account > Wallet > Top Up. Select your top-up amount, choose a payment method (e.g. Card or Bank Transfer via TransactPay), and follow the prompt to secure your top up.',
    ),
    FAQItem(
      question: 'How do I save a card?',
      answer:
          'When topping up your wallet with a credit/debit card, the system will automatically prompt you to save the card if you proceed with a card transaction. Reusable cards will then appear in your payment methods list.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF111827);
    final secondaryTextColor =
        isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
    final cardBg = isDark ? AppColors.darkSurface : Colors.white;
    final borderColor =
        isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB);

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : const Color(0xFFFAFAFA),
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.only(
                  left: 20, right: 20, top: 14, bottom: 8),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurface : Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: borderColor),
                      ),
                      child: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 18,
                        color: primaryTextColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    'Help & Support',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: primaryTextColor,
                      letterSpacing: -0.3,
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 6),
                      child: Text(
                        'FREQUENTLY ASKED QUESTIONS',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: secondaryTextColor,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 14),
                      child: Text(
                        'Tap a question below to read the helpful answer',
                        style: TextStyle(
                          fontSize: 13,
                          color: secondaryTextColor,
                        ),
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: borderColor),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _faqs.length,
                          separatorBuilder: (context, index) => Divider(
                            height: 1,
                            thickness: 1,
                            indent: 16,
                            endIndent: 16,
                            color: borderColor,
                          ),
                          itemBuilder: (context, index) =>
                              _buildFAQTile(_faqs[index], isDark, borderColor),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFAQTile(FAQItem item, bool isDark, Color borderColor) {
    final theme = Theme.of(context);
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF111827);
    final secondaryTextColor =
        isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);

    return Theme(
      data: theme.copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        title: Text(
          item.question,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: primaryTextColor,
          ),
        ),
        iconColor: AppColors.brand,
        collapsedIconColor: secondaryTextColor,
        tilePadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
        childrenPadding:
            const EdgeInsets.only(left: 18, right: 18, bottom: 16),
        children: [
          Text(
            item.answer,
            style: TextStyle(
              fontSize: 14,
              color: secondaryTextColor,
              height: 1.45,
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
