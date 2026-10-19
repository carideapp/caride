import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

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
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF111827);
    final secondaryTextColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
    final cardBg = isDark ? AppColors.darkSurface : Colors.white;
    final borderColor = isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB);

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFFAFAFA),
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.only(left: 20, right: 20, top: 14, bottom: 8),
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
                    'Data Usage Settings',
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
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 12),
                      child: Text(
                        'DATA & PERFORMANCE PREFERENCES',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: secondaryTextColor,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: cardBg,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: borderColor),
                      ),
                      child: Column(
                        children: [
                          _buildSwitchRow(
                            title: 'Usage & Diagnostics',
                            subtitle: 'Share crash telemetry to improve app performance and route accuracy.',
                            value: _diagnosticsEnabled,
                            primaryTextColor: primaryTextColor,
                            secondaryTextColor: secondaryTextColor,
                            onChanged: (val) => setState(() => _diagnosticsEnabled = val),
                          ),
                          Divider(height: 1, indent: 16, endIndent: 16, color: borderColor),
                          _buildSwitchRow(
                            title: 'Personalized Routing',
                            subtitle: 'Remember frequent pickup and dropoff destinations for faster booking.',
                            value: _personalizationEnabled,
                            primaryTextColor: primaryTextColor,
                            secondaryTextColor: secondaryTextColor,
                            onChanged: (val) => setState(() => _personalizationEnabled = val),
                          ),
                          Divider(height: 1, indent: 16, endIndent: 16, color: borderColor),
                          _buildSwitchRow(
                            title: 'Offline Map Caching',
                            subtitle: 'Save active zone map tiles locally to save cellular data usage.',
                            value: _locationCachingEnabled,
                            primaryTextColor: primaryTextColor,
                            secondaryTextColor: secondaryTextColor,
                            onChanged: (val) => setState(() => _locationCachingEnabled = val),
                          ),
                          Divider(height: 1, indent: 16, endIndent: 16, color: borderColor),
                          _buildSwitchRow(
                            title: 'Cellular Data Saver',
                            subtitle: 'Limit map animation framerate when not connected to Wi-Fi.',
                            value: _cellularDataSaving,
                            primaryTextColor: primaryTextColor,
                            secondaryTextColor: secondaryTextColor,
                            onChanged: (val) => setState(() => _cellularDataSaving = val),
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

  Widget _buildSwitchRow({
    required String title,
    required String subtitle,
    required bool value,
    required Color primaryTextColor,
    required Color secondaryTextColor,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: primaryTextColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: secondaryTextColor,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
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
