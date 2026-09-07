import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:navigation/navigation.dart';
import 'package:shared_widgets/shared_widgets.dart';

/// Redesigned Customer Data & Analytics Screen.
class DataAnalyticsScreen extends StatelessWidget {
  const DataAnalyticsScreen({super.key});

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
        title: 'Data & Analytics',
      ),
      body: SafeArea(
        child: ResponsiveContainer(
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
                  title: 'Privacy & Control',
                  subtitle: 'Manage how your data is processed and request copy of records',
                ),
                const SizedBox(height: AppSpacing.sm),
                GlassContainer(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      _buildMenuItem(
                        context,
                        icon: Icons.bar_chart_rounded,
                        title: 'Data Usage Settings',
                        subtitle: 'Control data usage for optimized analytics',
                        onTap: () => context.push(CustomerRoutePaths.dataUsage),
                      ),
                      Divider(
                        height: 1,
                        color: isDark ? AppColors.glassBorderDark : AppColors.glassBorderLight,
                      ),
                      _buildMenuItem(
                        context,
                        icon: Icons.cloud_download_outlined,
                        title: 'Download My Data',
                        subtitle: 'Request a copy of your personal data records',
                        onTap: () => context.push(CustomerRoutePaths.downloadData),
                      ),
                    ],
                  ),
                ),
              ],
            ),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTextStyles.titleMedium,
        ),
      ],
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.brandGlass,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(
                  icon,
                  color: AppColors.brand,
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
                      style: AppTextStyles.bodyLarge.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
              Icon(
                Icons.chevron_right_rounded,
                color: isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
