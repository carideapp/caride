import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:navigation/navigation.dart';
import 'package:shared_widgets/shared_widgets.dart';

/// Redesigned Customer Linked Accounts settings screen.
class LinkedAccountsScreen extends StatelessWidget {
  const LinkedAccountsScreen({super.key});

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
        title: 'Linked Accounts',
      ),
      body: SafeArea(
        child: ResponsiveContainer(
          child: ListView(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.pagePadding,
              vertical: AppSpacing.lg,
            ),
            children: [
              _buildAccountCard(
                context,
                icon: Icons.g_mobiledata,
                name: 'Google',
                isConnected: true,
              ),
              const SizedBox(height: AppSpacing.md),
              _buildAccountCard(
                context,
                icon: Icons.apple,
                name: 'Apple',
                isConnected: true,
              ),
              const SizedBox(height: AppSpacing.md),
              _buildAccountCard(
                context,
                icon: Icons.facebook,
                name: 'Facebook',
                isConnected: false,
              ),
              const SizedBox(height: AppSpacing.md),
              _buildAccountCard(
                context,
                icon: Icons.alternate_email,
                name: 'Twitter',
                isConnected: false,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAccountCard(BuildContext context, {required IconData icon, required String name, required bool isConnected}) {
    return GlassContainer(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.brandGlass,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 30, color: AppColors.brand),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              name,
              style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          GhostButton(
            label: isConnected ? 'Connected' : 'Connect',
            onPressed: () {},
          ),
        ],
      ),
    );
  }
}
