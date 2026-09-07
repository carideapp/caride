import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:navigation/navigation.dart';
import 'package:shared_widgets/shared_widgets.dart';
import 'package:caride/features/profile/data/wallet_repository.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AddNewPaymentScreen extends StatefulWidget {
  const AddNewPaymentScreen({super.key});

  @override
  State<AddNewPaymentScreen> createState() => _AddNewPaymentScreenState();
}

class _AddNewPaymentScreenState extends State<AddNewPaymentScreen> {
  final _walletRepo = WalletRepository();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _startCardSetup() async {
    if (_loading) return;
    setState(() => _loading = true);

    try {
      // ₦100 setup verification fee to validate and save card details.
      final result = await _walletRepo.initializeTopUp(
        amountNaira: 100.0,
        channels: ['card'],
      );
      if (!mounted) return;

      final userEmail = FirebaseAuth.instance.currentUser?.email ?? '';
      final success = await context.push<bool>(
        CustomerRoutePaths.topUpWebview,
        extra: {
          'url': result.authorizationUrl,
          'reference': result.reference,
          'amountNaira': 100.0,
          'isSetupCard': true,
          'email': userEmail,
        },
      );

      if (success == true && mounted) {
        context.pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Card verification failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Add New Payment',
          style: AppTextStyles.titleLarge.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: () {},
          ),
        ],
      ),
      body: SafeArea(
        child: ResponsiveContainer(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: AppSpacing.xl),
              Icon(Icons.add_card_rounded, size: 80, color: AppColors.primaryGreen.withValues(alpha: 0.8)),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Link Your Card',
                textAlign: TextAlign.center,
                style: AppTextStyles.headlineSmall.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'To verify your card, a small refundable charge of ₦100 will be made. '
                'This amount will be immediately credited to your CaRide Wallet.',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyLarge.copyWith(color: Colors.grey[600]),
              ),
              const SizedBox(height: AppSpacing.xl),
              const Divider(),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Supported Payments:',
                style: AppTextStyles.titleMedium.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Wrap(
                spacing: AppSpacing.md,
                runSpacing: AppSpacing.md,
                children: [
                  _buildPaymentIcon(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(width: 15, height: 15, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle)),
                        Transform.translate(offset: const Offset(-5, 0), child: Container(width: 15, height: 15, decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.8), shape: BoxShape.circle))),
                      ],
                    ),
                  ),
                  _buildPaymentIcon(child: const Text('VISA', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontStyle: FontStyle.italic))),
                  _buildPaymentIcon(child: const Text('Verve', style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold, fontStyle: FontStyle.italic))),
                ],
              ),
            ],
          ),
        ),
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: PrimaryButton(
          label: _loading ? 'Processing...' : 'Proceed to Verify Card',
          onPressed: _loading ? null : _startCardSetup,
        ),
      ),
    );
  }

  Widget _buildPaymentIcon({required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: AppSpacing.xs),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: child,
    );
  }
}
