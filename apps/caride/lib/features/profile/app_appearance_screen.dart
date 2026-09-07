import 'package:caride/app/theme_mode_controller.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:navigation/navigation.dart';
import 'package:shared_widgets/shared_widgets.dart';

/// Redesigned Customer App Appearance Settings Screen.
class AppAppearanceScreen extends StatefulWidget {
  const AppAppearanceScreen({super.key});

  @override
  State<AppAppearanceScreen> createState() => _AppAppearanceScreenState();
}

class _AppAppearanceScreenState extends State<AppAppearanceScreen> {
  @override
  void initState() {
    super.initState();
    customerThemeMode.addListener(_updateTheme);
  }

  @override
  void dispose() {
    customerThemeMode.removeListener(_updateTheme);
    super.dispose();
  }

  void _updateTheme() {
    if (mounted) setState(() {});
  }

  String get _currentTheme {
    return switch (customerThemeMode.value) {
      ThemeMode.system => 'System Default',
      ThemeMode.light => 'Light',
      ThemeMode.dark => 'Dark',
    };
  }

  ThemeMode _parseThemeName(String name) {
    return switch (name) {
      'System Default' => ThemeMode.system,
      'Light' => ThemeMode.light,
      'Dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  void _showThemePicker() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        String tempTheme = _currentTheme;
        return StatefulBuilder(
          builder: (context, setModalState) {
            return BottomSheetShell(
              title: 'Choose Theme',
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pagePadding),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildThemeOption('System Default', tempTheme, (v) => setModalState(() => tempTheme = v)),
                    _buildThemeOption('Light', tempTheme, (v) => setModalState(() => tempTheme = v)),
                    _buildThemeOption('Dark', tempTheme, (v) => setModalState(() => tempTheme = v)),
                    const SizedBox(height: AppSpacing.lg),
                    Row(
                      children: [
                        Expanded(
                          child: SecondaryButton(
                            label: 'Cancel',
                            onPressed: () => Navigator.pop(context),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Expanded(
                          child: PrimaryButton(
                            label: 'Apply',
                            onPressed: () {
                              customerThemeMode.setTheme(_parseThemeName(tempTheme));
                              Navigator.pop(context);
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildThemeOption(String title, String current, ValueChanged<String> onChanged) {
    final isSelected = title == current;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onChanged(title),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.md,
          ),
          child: Row(
            children: [
              Icon(
                isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                color: isSelected ? AppColors.brand : Colors.grey,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  title,
                  style: AppTextStyles.bodyLarge.copyWith(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

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
        title: 'App Appearance',
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
                  title: 'Visual Settings',
                  subtitle: 'Personalize the theme mode and application language',
                ),
                const SizedBox(height: AppSpacing.sm),
                GlassContainer(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      _buildMenuItem(
                        context,
                        icon: Icons.brightness_6_outlined,
                        title: 'Theme Mode',
                        trailingText: _currentTheme,
                        onTap: _showThemePicker,
                      ),
                      Divider(
                        height: 1,
                        color: isDark ? AppColors.glassBorderDark : AppColors.glassBorderLight,
                      ),
                      _buildMenuItem(
                        context,
                        icon: Icons.language_rounded,
                        title: 'App Language',
                        trailingText: 'English (US)',
                        onTap: () => context.push(CustomerRoutePaths.appLanguage),
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

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String trailingText,
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
                child: Text(
                  title,
                  style: AppTextStyles.bodyLarge.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                trailingText,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  fontWeight: FontWeight.w500,
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
