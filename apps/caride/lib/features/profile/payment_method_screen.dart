import 'package:caride/features/profile/data/payment_repository.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:navigation/navigation.dart';
import 'package:shared_widgets/shared_widgets.dart';

enum PaymentMethodFlow { topUp, ride }

class PaymentMethodSelection {
  const PaymentMethodSelection({
    required this.id,
    required this.name,
  });

  final String id;
  final String name;
}

class PaymentMethodScreen extends StatefulWidget {
  const PaymentMethodScreen({
    super.key,
    required this.amount,
    this.flow = PaymentMethodFlow.topUp,
    this.initialMethodId,
  });

  final double amount;
  final PaymentMethodFlow flow;
  final String? initialMethodId;

  @override
  State<PaymentMethodScreen> createState() => _PaymentMethodScreenState();
}

class _PaymentMethodScreenState extends State<PaymentMethodScreen> {
  String? _selectedMethodId;
  final PaymentRepository _repo = PaymentRepository();

  @override
  void initState() {
    super.initState();
    _selectedMethodId = widget.initialMethodId;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isRideFlow = widget.flow == PaymentMethodFlow.ride;
    final formattedAmount = widget.amount.toStringAsFixed(2).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Text(
          isRideFlow ? 'Choose Payment Method' : 'Choose Top Up Method',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {
              context.push(CustomerRoutePaths.viewPaymentMethods);
            },
          ),
        ],
      ),
      body: SafeArea(
        child: StreamBuilder<List<PaymentMethod>>(
          stream: _repo.watchPaymentMethods(),
          builder: (context, snapshot) {
            final methods = (snapshot.data ?? PaymentMethod.builtInMethods)
                .where((m) => m.id != 'cash')
                .toList();
            final selected = _selectedMethodId != null
                ? methods.where((m) => m.id == _selectedMethodId).firstOrNull
                : null;
            final selectedSelection = selected != null
                ? PaymentMethodSelection(id: selected.id, name: selected.name)
                : null;

            IconData iconForType(String type) {
              return switch (type) {
                'wallet' => Icons.account_balance_wallet_outlined,
                'cash' => Icons.money,
                _ => Icons.credit_card,
              };
            }

            return Column(
              children: [
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    itemCount: methods.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppSpacing.md),
                    itemBuilder: (context, index) {
                      final method = methods[index];
                      final isSelected = _selectedMethodId == method.id;
                      return InkWell(
                        onTap: () =>
                            setState(() => _selectedMethodId = method.id),
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        child: Container(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            borderRadius: BorderRadius.circular(AppRadius.lg),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.primaryGreen
                                  : theme.colorScheme.outlineVariant,
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surfaceContainerHighest
                                      .withValues(alpha: 0.3),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(iconForType(method.type),
                                    color: theme.colorScheme.onSurface),
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: Text(
                                  method.name,
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              if (isSelected)
                                const Icon(Icons.check_circle,
                                    color: AppColors.primaryGreen)
                              else
                                const Icon(Icons.radio_button_off,
                                    color: Colors.grey),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: PrimaryButton(
                    label: isRideFlow
                        ? 'Use ${selectedSelection?.name ?? 'Payment Method'}'
                        : 'Confirm Top Up - ₦$formattedAmount',
                    onPressed: selectedSelection == null
                        ? null
                        : () {
                            if (isRideFlow) {
                              Navigator.of(context).pop(selectedSelection);
                              return;
                            }
                            final router = GoRouter.of(context);
                            context
                                .push(CustomerRoutePaths.topUpWebview,
                                    extra: widget.amount)
                                .then((result) {
                              if (!mounted) return;
                              if (result != null) router.pop(result);
                            });
                          },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
