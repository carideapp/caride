import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:navigation/navigation.dart';

/// Screen displaying Fleet Partner Legal Agreements, navigating to individual dedicated screens.
class FleetLegalScreen extends StatelessWidget {
  const FleetLegalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF111827);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFFAFAFA),
      body: SafeArea(
        child: Column(
          children: [
            // ── Top Navigation Bar ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface : Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB),
                      ),
                    ),
                    child: IconButton(
                      icon: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 18,
                        color: primaryTextColor,
                      ),
                      onPressed: () => context.pop(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Legal & Compliance',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: primaryTextColor,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Legal Policy Menu List Card ──
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurface : Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB),
                        ),
                      ),
                      child: Column(
                        children: [
                          _buildLegalMenuItem(
                            title: 'Terms of Use',
                            icon: Icons.description_outlined,
                            isDark: isDark,
                            primaryTextColor: primaryTextColor,
                            onTap: () => context.push(FleetRoutePaths.legalTerms),
                          ),
                          _buildDivider(isDark),
                          _buildLegalMenuItem(
                            title: 'Vehicle Rental & Chauffeur Protocol',
                            icon: Icons.rule_rounded,
                            isDark: isDark,
                            primaryTextColor: primaryTextColor,
                            onTap: () => context.push(FleetRoutePaths.legalRentalProtocol),
                          ),
                          _buildDivider(isDark),
                          _buildLegalMenuItem(
                            title: 'Insurance & Damage Liability Guidelines',
                            icon: Icons.shield_outlined,
                            isDark: isDark,
                            primaryTextColor: primaryTextColor,
                            onTap: () => context.push(FleetRoutePaths.legalInsurancePolicy),
                          ),
                          _buildDivider(isDark),
                          _buildLegalMenuItem(
                            title: 'Privacy Policy',
                            icon: Icons.privacy_tip_outlined,
                            isDark: isDark,
                            primaryTextColor: primaryTextColor,
                            onTap: () => context.push(FleetRoutePaths.legalPrivacyPolicy),
                          ),
                        ],
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

  Widget _buildLegalMenuItem({
    required String title,
    required IconData icon,
    required bool isDark,
    required Color primaryTextColor,
    required VoidCallback onTap,
  }) {
    final iconBgColor = isDark ? Colors.white10 : const Color(0xFFF3F4F6);
    final iconColor = isDark ? Colors.white70 : const Color(0xFF374151);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconBgColor,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: iconColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: primaryTextColor,
                  letterSpacing: -0.2,
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: Color(0xFF9CA3AF),
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 68, right: 18),
      child: Divider(
        height: 1,
        color: isDark ? Colors.white10 : const Color(0xFFF3F4F6),
      ),
    );
  }
}
