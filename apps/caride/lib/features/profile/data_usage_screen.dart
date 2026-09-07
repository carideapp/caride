import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:navigation/navigation.dart';
import 'package:shared_widgets/shared_widgets.dart';

/// Redesigned Customer Data Usage Settings Screen.
class DataUsageScreen extends StatefulWidget {
  const DataUsageScreen({super.key});

  @override
  State<DataUsageScreen> createState() => _DataUsageScreenState();
}

class _DataUsageScreenState extends State<DataUsageScreen> {
  bool _diagnosticsEnabled = true;
  bool _personalizationEnabled = true;
  bool _locationCachingEnabled = true;
  bool _cellularDataSaving = false;

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
        title: 'Data Usage',
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
                  title: 'Manage Data Preferences',
                  subtitle: 'Configure how CaRide uses data and analytics to optimize performance',
                ),
                const SizedBox(height: AppSpacing.sm),
                GlassContainer(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
                  child: Column(
                    children: [
                      _buildSwitchTile(
                        title: 'Usage & Diagnostics',
                        subtitle: 'Share performance and crash reports to help resolve platform issues.',
                        value: _diagnosticsEnabled,
                        onChanged: (val) => setState(() => _diagnosticsEnabled = val),
                      ),
                      Divider(
                        height: 1,
                        color: isDark ? AppColors.glassBorderDark : AppColors.glassBorderLight,
                      ),
                      _buildSwitchTile(
                        title: 'Personalized Features',
                        subtitle: 'Allow search history and frequent destinations to prioritize routes.',
                        value: _personalizationEnabled,
                        onChanged: (val) => setState(() => _personalizationEnabled = val),
                      ),
                      Divider(
                        height: 1,
                        color: isDark ? AppColors.glassBorderDark : AppColors.glassBorderLight,
                      ),
                      _buildSwitchTile(
                        title: 'Local Place Caching',
                        subtitle: 'Save map visual layers and queries locally to conserve active bandwidth.',
                        value: _locationCachingEnabled,
                        onChanged: (val) => setState(() => _locationCachingEnabled = val),
                      ),
                      Divider(
                        height: 1,
                        color: isDark ? AppColors.glassBorderDark : AppColors.glassBorderLight,
                      ),
                      _buildSwitchTile(
                        title: 'Cellular Data Saver',
                        subtitle: 'Reduce background map quality and limit API updates on cellular data.',
                        value: _cellularDataSaving,
                        onChanged: (val) => setState(() => _cellularDataSaving = val),
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

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Switch.adaptive(
            value: value,
            activeTrackColor: AppColors.brand,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
