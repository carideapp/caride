import 'package:caride/features/profile/data/payment_repository.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:navigation/navigation.dart';

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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryTextColor = isDark ? Colors.white : const Color(0xFF111827);
    final secondaryTextColor = isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280);
    final cardBg = isDark ? AppColors.darkSurface : Colors.white;
    final borderColor = isDark ? AppColors.glassBorderDark : const Color(0xFFE5E7EB);
    final iconBg = isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFF3F4F6);

    final isRideFlow = widget.flow == PaymentMethodFlow.ride;
    final formattedAmount = widget.amount.toStringAsFixed(2).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );

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
                  Expanded(
                    child: Text(
                      isRideFlow ? 'Choose Payment Method' : 'Top Up Method',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: primaryTextColor,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => context.push(CustomerRoutePaths.viewPaymentMethods),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.darkSurface : Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: borderColor),
                      ),
                      child: Icon(
                        Icons.add_rounded,
                        size: 22,
                        color: primaryTextColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Stream List
            Expanded(
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
                      'wallet' => Icons.account_balance_wallet_rounded,
                      'cash' => Icons.payments_rounded,
                      _ => Icons.credit_card_rounded,
                    };
                  }

                  return Column(
                    children: [
                      Expanded(
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          itemCount: methods.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final method = methods[index];
                            final isSelected = _selectedMethodId == method.id;

                            return GestureDetector(
                              onTap: () => setState(() => _selectedMethodId = method.id),
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: cardBg,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isSelected ? AppColors.brand : borderColor,
                                    width: isSelected ? 1.8 : 1.0,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? AppColors.brand.withValues(alpha: 0.12)
                                            : iconBg,
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        iconForType(method.type),
                                        color: isSelected ? AppColors.brand : primaryTextColor,
                                        size: 22,
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Text(
                                        method.name,
                                        style: TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w700,
                                          color: primaryTextColor,
                                        ),
                                      ),
                                    ),
                                    Icon(
                                      isSelected
                                          ? Icons.check_circle_rounded
                                          : Icons.radio_button_off_rounded,
                                      color: isSelected
                                          ? AppColors.brand
                                          : secondaryTextColor.withValues(alpha: 0.5),
                                      size: 22,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                      // Confirm Action Button
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                        child: SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
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
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.brand,
                              elevation: 0,
                              disabledBackgroundColor: AppColors.brand.withValues(alpha: 0.4),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(28),
                              ),
                            ),
                            child: Text(
                              isRideFlow
                                  ? 'Use ${selectedSelection?.name ?? 'Payment Method'}'
                                  : 'Confirm Top Up • ₦$formattedAmount',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
