import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:shared_widgets/shared_widgets.dart';
import 'package:url_launcher/url_launcher.dart';
import 'driver_terms_screen.dart';
import 'driver_privacy_policy_screen.dart';

class DriverAboutScreen extends StatelessWidget {
  const DriverAboutScreen({super.key});

  Future<void> _openUrl(String urlString) async {
    final cleaned = urlString.trim();
    if (cleaned.isEmpty) return;
    final uri = Uri.parse(cleaned.startsWith('http') ? cleaned : 'https://$cleaned');
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  Future<void> _openEmail(String email) async {
    final cleaned = email.trim();
    if (cleaned.isEmpty) return;
    final uri = Uri(scheme: 'mailto', path: cleaned);
    try {
      await launchUrl(uri);
    } catch (_) {}
  }

  Future<void> _openPhone(String phone) async {
    final cleaned = phone.trim().replaceAll(RegExp(r'[^\d+]'), '');
    if (cleaned.isEmpty) return;
    final uri = Uri(scheme: 'tel', path: cleaned);
    try {
      await launchUrl(uri);
    } catch (_) {}
  }

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
          'About CaRide',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: SafeArea(
        child: ResponsiveContainer(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.xs,
              vertical: AppSpacing.sm,
            ),
            child: Column(
              children: [
                // Top logo / introduction card
                Container(
                  width: double.infinity,
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
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: AppColors.primaryGreen.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(AppRadius.xl),
                        ),
                        child: const Icon(
                          Icons.local_taxi_rounded,
                          color: AppColors.primaryGreen,
                          size: 40,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'CaRide Driver',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: isDark ? Colors.white : AppColors.slate900,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        'Version 1.0.4',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isDark ? Colors.grey[400] : const Color(0xFF6E7191),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        'CaRide is a premium ride-hailing platform connecting '
                        'drivers and riders across Nigeria. Earn on your own '
                        'schedule with competitive commission rates and a '
                        'transparent tier system.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: isDark ? Colors.grey[300] : const Color(0xFF4A4D70),
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Link details card with live Firestore streaming
                StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('config')
                      .doc('appSupport')
                      .snapshots(),
                  builder: (context, snapshot) {
                    final data = snapshot.data?.data();
                    final website = data?['website'] as String? ?? 'www.caride.ng';
                    final supportEmail = data?['supportEmail'] as String? ?? 'support@caride.ng';
                    final supportPhone = data?['supportPhone'] as String? ?? '+234 800 CARIDE';

                    return Container(
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
                        children: [
                          _aboutTile(
                            context,
                            icon: Icons.language_rounded,
                            title: 'Website',
                            subtitle: website,
                            onTap: () => _openUrl(website),
                          ),
                          _aboutTile(
                            context,
                            icon: Icons.email_outlined,
                            title: 'Support Email',
                            subtitle: supportEmail,
                            onTap: () => _openEmail(supportEmail),
                          ),
                          _aboutTile(
                            context,
                            icon: Icons.phone_android_rounded,
                            title: 'Support Line',
                            subtitle: supportPhone,
                            onTap: () => _openPhone(supportPhone),
                          ),
                          _aboutTile(
                            context,
                            icon: Icons.gavel_rounded,
                            title: 'Terms of Service',
                            subtitle: 'View terms and conditions',
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const DriverTermsScreen(),
                                ),
                              );
                            },
                          ),
                          _aboutTile(
                            context,
                            icon: Icons.privacy_tip_outlined,
                            title: 'Privacy Policy',
                            subtitle: 'View privacy policy and data practices',
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const DriverPrivacyPolicyScreen(),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: AppSpacing.xl),
                Text(
                  '© 2026 CaRide Technologies Ltd.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: isDark ? Colors.grey[500] : const Color(0xFF8A90A6),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _aboutTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final mutedTextColor = isDark ? Colors.grey[400]! : const Color(0xFF6E7191);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(
                  icon,
                  color: AppColors.primaryGreen,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : AppColors.slate900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: mutedTextColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Icon(
                Icons.chevron_right_rounded,
                color: Colors.grey[400],
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
