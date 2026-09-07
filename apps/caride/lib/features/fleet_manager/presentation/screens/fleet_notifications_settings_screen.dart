import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:navigation/navigation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Screen for managing Fleet Manager notification alerts & preferences.
class FleetNotificationsSettingsScreen extends StatefulWidget {
  const FleetNotificationsSettingsScreen({super.key});

  @override
  State<FleetNotificationsSettingsScreen> createState() =>
      _FleetNotificationsSettingsScreenState();
}

class _FleetNotificationsSettingsScreenState
    extends State<FleetNotificationsSettingsScreen> {
  bool _bookings = true;
  bool _driverDispatch = true;
  bool _maintenance = true;
  bool _payouts = true;
  bool _marketing = false;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _bookings = prefs.getBool('fleet_notif_bookings') ?? true;
        _driverDispatch = prefs.getBool('fleet_notif_dispatch') ?? true;
        _maintenance = prefs.getBool('fleet_notif_maintenance') ?? true;
        _payouts = prefs.getBool('fleet_notif_payouts') ?? true;
        _marketing = prefs.getBool('fleet_notif_marketing') ?? false;
      });
    } catch (_) {}
  }

  Future<void> _toggle(String key, bool value, void Function(bool) setter) async {
    setState(() => setter(value));
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(key, value);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : const Color(0xFFF9FAFB),
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
                      'Notifications & Alerts',
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

            // ── Notification Items List ──
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Operational Alerts',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: primaryTextColor,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Manage push notifications for real-time rental and fleet activities.',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? AppColors.textSecondaryDark : const Color(0xFF6B7280),
                      ),
                    ),
                    const SizedBox(height: 16),

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
                          _buildSwitchTile(
                            title: 'New Booking Inquiries',
                            subtitle: 'Instant alerts when customers request your vehicles',
                            icon: Icons.calendar_month_rounded,
                            value: _bookings,
                            isDark: isDark,
                            primaryTextColor: primaryTextColor,
                            onChanged: (v) => _toggle('fleet_notif_bookings', v, (val) => _bookings = val),
                          ),
                          _buildDivider(isDark),
                          _buildSwitchTile(
                            title: 'Driver & Chauffeur Dispatch',
                            subtitle: 'Updates on driver acceptance, trip starts, and completions',
                            icon: Icons.directions_car_rounded,
                            value: _driverDispatch,
                            isDark: isDark,
                            primaryTextColor: primaryTextColor,
                            onChanged: (v) => _toggle('fleet_notif_dispatch', v, (val) => _driverDispatch = val),
                          ),
                          _buildDivider(isDark),
                          _buildSwitchTile(
                            title: 'Vehicle Maintenance Reminders',
                            subtitle: 'Scheduled servicing, return inspections, and document renewals',
                            icon: Icons.build_circle_outlined,
                            value: _maintenance,
                            isDark: isDark,
                            primaryTextColor: primaryTextColor,
                            onChanged: (v) => _toggle('fleet_notif_maintenance', v, (val) => _maintenance = val),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    Text(
                      'Financial & Account Updates',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: primaryTextColor,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 14),

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
                          _buildSwitchTile(
                            title: 'Payout & Settlement Alerts',
                            subtitle: 'Notifications when revenue is transferred to your bank account',
                            icon: Icons.account_balance_wallet_rounded,
                            value: _payouts,
                            isDark: isDark,
                            primaryTextColor: primaryTextColor,
                            onChanged: (v) => _toggle('fleet_notif_payouts', v, (val) => _payouts = val),
                          ),
                          _buildDivider(isDark),
                          _buildSwitchTile(
                            title: 'CaRide Fleet Partner News',
                            subtitle: 'Insights, market demand surges, and feature releases',
                            icon: Icons.campaign_rounded,
                            value: _marketing,
                            isDark: isDark,
                            primaryTextColor: primaryTextColor,
                            onChanged: (v) => _toggle('fleet_notif_marketing', v, (val) => _marketing = val),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required bool isDark,
    required Color primaryTextColor,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark ? Colors.white10 : const Color(0xFFF3F4F6),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.brand, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: primaryTextColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.textSecondaryDark : const Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Switch(
            value: value,
            activeTrackColor: AppColors.brand,
            activeThumbColor: Colors.white,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Divider(
      height: 1,
      indent: 64,
      endIndent: 18,
      color: isDark ? Colors.white10 : const Color(0xFFF3F4F6),
    );
  }
}
