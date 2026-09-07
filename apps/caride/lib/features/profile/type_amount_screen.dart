import 'package:caride/core/config/app_config_repository.dart';
import 'package:caride/features/profile/data/account_repository.dart';
import 'package:caride/features/wallet/top_up_method_screen.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:navigation/navigation.dart';
import 'package:shared_widgets/shared_widgets.dart';

class TypeAmountScreen extends StatefulWidget {
  const TypeAmountScreen({super.key});

  @override
  State<TypeAmountScreen> createState() => _TypeAmountScreenState();
}

class _TypeAmountScreenState extends State<TypeAmountScreen> {
  final AccountRepository _accountRepo = AccountRepository();
  final AppConfigRepository _configRepo = AppConfigRepository();
  String _amountText = '0.00';

  void _onKeyTap(String key) {
    setState(() {
      if (key == '<') {
        if (_amountText.length > 4) {
          _amountText = _amountText.substring(0, _amountText.length - 1);
          if (_amountText.endsWith('.')) {
            _amountText = _amountText.substring(0, _amountText.length - 1);
          }
          if (!_amountText.contains('.')) {
            _amountText = '0.00';
          }
        } else {
          _amountText = '0.00';
        }
      } else if (key == '*') {
        // no-op
      } else {
        if (_amountText == '0.00') {
          _amountText = '$key.00';
        } else {
          final parts = _amountText.split('.');
          _amountText = '${parts[0]}$key.${parts[1]}';
        }
      }
    });
  }

  void _selectAmount(double amount) {
    setState(() => _amountText = amount.toStringAsFixed(2));
  }

  String _formatWithCommas(String amountText) {
    final parts = amountText.split('.');
    final whole = parts.first;
    final decimal = parts.length > 1 ? parts[1] : '00';
    final wholeWithCommas = whole.replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
    return '$wholeWithCommas.${decimal.padRight(2, '0').substring(0, 2)}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return StreamBuilder<WalletTopUpConfig>(
      stream: _configRepo.watchWalletTopUpConfig(),
      initialData: WalletTopUpConfig.defaults,
      builder: (context, topUpSnap) {
        final topUpConfig = topUpSnap.data ?? WalletTopUpConfig.defaults;
        final quick = topUpConfig.quickAmountsNaira.take(3).toList(growable: false);
        return Scaffold(
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.pop(),
            ),
            title: Text(
              'Top Up',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            centerTitle: true,
          ),
          body: SafeArea(
            child: Column(
              children: [
                const SizedBox(height: AppSpacing.xl),
                Container(
                  margin:
                      const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(
                      color: theme.colorScheme.outlineVariant
                          .withValues(alpha: 0.5),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              '₦',
                              style: theme.textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _formatWithCommas(_amountText),
                            style: theme.textTheme.displayMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                              width: 2,
                              height: 40,
                              color: AppColors.primaryGreen),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.md),
                      StreamBuilder<double>(
                        stream: _accountRepo.watchWalletBalance(),
                        builder: (context, snap) {
                          final bal = snap.data ?? 0.0;
                          final formatted =
                              _formatWithCommas(bal.toStringAsFixed(2));
                          return Text(
                            'Available balance: ₦$formatted',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md),
                          child: Row(
                            children: [
                              for (int i = 0; i < quick.length; i++) ...[
                                if (i > 0)
                                  const SizedBox(width: AppSpacing.sm),
                                Expanded(
                                  child: SecondaryButton(
                                    label:
                                        '₦${_formatWithCommas(quick[i].toStringAsFixed(2))}',
                                    onPressed: () =>
                                        _selectAmount(quick[i]),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xl),
                        _buildKeypad(),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: PrimaryButton(
                    label: 'Continue',
                    onPressed: () {
                      final amount = double.tryParse(_amountText) ?? 0.0;
                      if (amount < topUpConfig.minAmountNaira) {
                        final minFormatted = _formatWithCommas(
                            topUpConfig.minAmountNaira.toStringAsFixed(2));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                                'Minimum top-up is ₦$minFormatted.'),
                          ),
                        );
                        return;
                      }
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              TopUpMethodScreen(amountNaira: amount),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildKeypad() {
    return Column(
      children: [
        _buildKeypadRow(['1', '2', '3']),
        _buildKeypadRow(['4', '5', '6']),
        _buildKeypadRow(['7', '8', '9']),
        _buildKeypadRow(['*', '0', '<']),
      ],
    );
  }

  Widget _buildKeypadRow(List<String> keys) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: keys.map((key) {
        return InkWell(
          onTap: () => _onKeyTap(key),
          borderRadius: BorderRadius.circular(50),
          child: SizedBox(
            width: 80,
            height: 80,
            child: Center(
              child: key == '<'
                  ? const Icon(Icons.backspace_outlined)
                  : Text(
                      key,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
