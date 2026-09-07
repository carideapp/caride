import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:navigation/navigation.dart';
import 'package:shared_widgets/shared_widgets.dart';
import 'package:caride/features/profile/data/card_repository.dart';
import 'package:caride/features/profile/data/wallet_repository.dart';

class ViewPaymentMethodScreen extends StatefulWidget {
  const ViewPaymentMethodScreen({super.key});

  @override
  State<ViewPaymentMethodScreen> createState() => _ViewPaymentMethodScreenState();
}

class _ViewPaymentMethodScreenState extends State<ViewPaymentMethodScreen> {
  final _cardRepository = CardRepository();
  final _walletRepo = WalletRepository();
  String? _selectedMethod = 'wallet';
  bool _isDeleting = false;
  bool _isAddingCard = false;

  /// Directly launches Paystack card-only checkout to add and save a new card.
  Future<void> _startAddCard() async {
    if (_isAddingCard) return;
    setState(() => _isAddingCard = true);
    try {
      final result = await _walletRepo.initializeTopUp(
        amountNaira: 100.0,
        channels: ['card'],
      );
      if (!mounted) return;
      final success = await context.push<bool>(
        CustomerRoutePaths.topUpWebview,
        extra: {
          'url': result.authorizationUrl,
          'reference': result.reference,
          'amountNaira': 100.0,
          'isSetupCard': true,
        },
      );
      if (success == true && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Card added successfully!'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.primaryGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to add card: $e'),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isAddingCard = false);
    }
  }

  Future<void> _deleteCard(String id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Card?'),
        content: const Text('Are you sure you want to delete this saved card?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isDeleting = true);
    try {
      await _cardRepository.deleteCard(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Card deleted successfully.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete card: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isDeleting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Payment Methods',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ResponsiveContainer(
          child: Column(
            children: [
              Expanded(
                child: StreamBuilder<List<SavedCard>>(
                  stream: _cardRepository.watchSavedCards(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation(AppColors.primaryGreen),
                        ),
                      );
                    }

                    final cards = snapshot.data ?? [];
                    final methods = [
                      ...cards.map((c) => {
                            'id': c.id,
                            'name': c.brand.toUpperCase(),
                            'icon': Icons.credit_card_outlined,
                            'number': '•••• •••• •••• ${c.last4}',
                            'isCard': true,
                          }),
                      {
                        'id': 'wallet',
                        'name': 'CaRide Wallet',
                        'icon': Icons.account_balance_wallet_outlined,
                        'number': 'Default Payment',
                        'isCard': false,
                      },
                    ];

                    return ListView.separated(
                      padding: const EdgeInsets.all(AppSpacing.md),
                      itemCount: methods.length,
                      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.md),
                      itemBuilder: (context, index) {
                        final method = methods[index];
                        final isSelected = _selectedMethod == method['id'];
                        final isCard = method['isCard'] as bool;

                        return Material(
                          color: theme.colorScheme.surface,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.lg),
                            side: BorderSide(
                              color: isSelected ? AppColors.primaryGreen : theme.colorScheme.outlineVariant,
                              width: isSelected ? 2.0 : 1.0,
                            ),
                          ),
                          clipBehavior: Clip.hardEdge,
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: AppSpacing.md,
                              vertical: AppSpacing.xs,
                            ),
                            leading: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(method['icon'] as IconData, color: theme.colorScheme.onSurface),
                            ),
                            title: Text(
                              method['name'] as String,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              method['number'] as String,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (isCard)
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: AppColors.error),
                                    onPressed: _isDeleting ? null : () => _deleteCard(method['id'] as String),
                                  ),
                                Icon(
                                  isSelected ? Icons.check_circle : Icons.radio_button_off,
                                  color: isSelected ? AppColors.primaryGreen : Colors.grey,
                                ),
                              ],
                            ),
                            onTap: () => setState(() => _selectedMethod = method['id'] as String),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: PrimaryButton(
                  label: _isAddingCard ? 'Setting up...' : 'Add New Card',
                  onPressed: _isAddingCard ? null : _startAddCard,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
