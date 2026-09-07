import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:navigation/navigation.dart';
import 'package:caride/app/theme_mode_controller.dart';

/// Screen for selecting and managing Application Appearance Mode (Theme).
class FleetAppearanceScreen extends StatefulWidget {
  const FleetAppearanceScreen({super.key});

  @override
  State<FleetAppearanceScreen> createState() => _FleetAppearanceScreenState();
}

class _FleetAppearanceScreenState extends State<FleetAppearanceScreen> {
  @override
  void initState() {
    super.initState();
    customerThemeMode.addListener(_handleThemeChanged);
  }

  @override
  void dispose() {
    customerThemeMode.removeListener(_handleThemeChanged);
    super.dispose();
  }

  void _handleThemeChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final currentMode = customerThemeMode.value;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFF9FAFB),
      body: SafeArea(
        child: Column(
          children: [
            // ── Top Navigation Bar with circular back button ──
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
                      'Appearance Mode',
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

            // ── Theme Selection Cards ──
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Choose Display Theme',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: primaryTextColor,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Customize the visual presentation of your CaRide Fleet portal.',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? AppColors.textSecondaryDark : const Color(0xFF6B7280),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Option 1: System Default
                    _buildThemeCard(
                      title: 'System Default',
                      subtitle: 'Automatically sync with your device\'s system appearance.',
                      icon: Icons.brightness_auto_rounded,
                      mode: ThemeMode.system,
                      isSelected: currentMode == ThemeMode.system,
                      isDark: isDark,
                      primaryTextColor: primaryTextColor,
                    ),

                    const SizedBox(height: 14),

                    // Option 2: Light Mode
                    _buildThemeCard(
                      title: 'Light Mode',
                      subtitle: 'Crisp, bright emerald interface optimized for daylight visibility.',
                      icon: Icons.light_mode_rounded,
                      mode: ThemeMode.light,
                      isSelected: currentMode == ThemeMode.light,
                      isDark: isDark,
                      primaryTextColor: primaryTextColor,
                    ),

                    const SizedBox(height: 14),

                    // Option 3: Dark Mode
                    _buildThemeCard(
                      title: 'Dark Mode',
                      subtitle: 'Sleek dark aesthetic designed for low-light comfort and battery efficiency.',
                      icon: Icons.dark_mode_rounded,
                      mode: ThemeMode.dark,
                      isSelected: currentMode == ThemeMode.dark,
                      isDark: isDark,
                      primaryTextColor: primaryTextColor,
                    ),

                    const SizedBox(height: 28),

                    // ── Visual Live Preview Box ──
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurface : Colors.white,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 10,
                                height: 10,
                                decoration: const BoxDecoration(
                                  color: AppColors.brand,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Active Mode Preview',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: primaryTextColor,
                                ),
                              ),
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.brand.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  currentMode == ThemeMode.system
                                      ? 'System (${isDark ? "Dark" : "Light"})'
                                      : currentMode == ThemeMode.light
                                          ? 'Light'
                                          : 'Dark',
                                  style: const TextStyle(
                                    color: AppColors.brand,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'CaRide features Emerald Green accents with high-contrast typography and pill geometry across all platforms.',
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? AppColors.textSecondaryDark : const Color(0xFF6B7280),
                              height: 1.4,
                            ),
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

  Widget _buildThemeCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required ThemeMode mode,
    required bool isSelected,
    required bool isDark,
    required Color primaryTextColor,
  }) {
    return InkWell(
      onTap: () {
        customerThemeMode.setTheme(mode);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Appearance changed to $title'),
            backgroundColor: AppColors.brand,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        );
      },
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isSelected
                ? AppColors.brand
                : (isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB)),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.brand.withValues(alpha: 0.15),
                    blurRadius: 14,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.brand
                    : (isDark ? Colors.white10 : const Color(0xFFF3F4F6)),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: isSelected ? Colors.white : AppColors.brand,
                size: 22,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: primaryTextColor,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppColors.textSecondaryDark : const Color(0xFF6B7280),
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? AppColors.brand : const Color(0xFF9CA3AF),
                  width: 2,
                ),
                color: isSelected ? AppColors.brand : Colors.transparent,
              ),
              child: isSelected
                  ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
