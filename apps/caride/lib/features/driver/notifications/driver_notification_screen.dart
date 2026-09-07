import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:shared_widgets/shared_widgets.dart';

/// Redesigned Notifications screen utilizing GlassAppBar, EmptyState, and design system tokens.
class DriverNotificationScreen extends StatelessWidget {
  const DriverNotificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: GlassAppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: 'Notifications',
      ),
      body: const SafeArea(
        child: ResponsiveContainer(
          child: EmptyState(
            title: 'No Notifications',
            message: "You'll see notifications here when you receive them.",
            icon: Icons.notifications_none_rounded,
          ),
        ),
      ),
    );
  }
}
