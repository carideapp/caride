import 'package:design_system/design_system.dart';
import 'package:caride/core/driver/models/driver_bank_account.dart';
import 'package:caride/features/driver/wallet/data/driver_bank_account_repository.dart';
import 'package:flutter/material.dart';
import 'package:navigation/navigation.dart';
import 'package:shared_widgets/shared_widgets.dart';

class DriverManageBankAccountsScreen extends StatelessWidget {
  const DriverManageBankAccountsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bankRepo = DriverBankAccountRepository();

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: GlassAppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: 'Payout Accounts',
      ),
      body: SafeArea(
        child: ResponsiveContainer(
          child: StreamBuilder<List<DriverBankAccount>>(
            stream: bankRepo.streamBankAccounts(),
            builder: (context, snapshot) {
              final accounts = snapshot.data ?? const <DriverBankAccount>[];
              final hasAccount = accounts.isNotEmpty;

              return ListView(
                padding: const EdgeInsets.all(AppSpacing.pagePadding),
                children: [
                  Text(
                    'Manage your payout accounts',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  if (!hasAccount) ...[
                    const EmptyState(
                      title: 'No Accounts Added',
                      message: 'Add a verified bank account to receive your payouts seamlessly.',
                      icon: Icons.account_balance_rounded,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ] else ...[
                    Column(
                      children: accounts.map((account) => _BankAccountTile(account: account)).toList(growable: false),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                  ],
                  PrimaryButton(
                    label: hasAccount ? 'Update Bank Account' : 'Add Bank Account',
                    onPressed: () => context.push(DriverRoutePaths.walletBankAccount),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _BankAccountTile extends StatelessWidget {
  const _BankAccountTile({required this.account});

  final DriverBankAccount account;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GlassContainer(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.brandGlass,
              borderRadius: BorderRadius.circular(AppRadius.sm),
            ),
            child: const Icon(Icons.account_balance, color: AppColors.brand, size: 20),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  account.bankName,
                  style: AppTextStyles.titleSmall.copyWith(
                    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${account.accountNumber} • ${account.accountName}',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
