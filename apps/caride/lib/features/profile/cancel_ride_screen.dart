import 'package:caride/core/config/app_config_repository.dart';
import 'package:caride/features/ride_booking/data/ride_repository.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:navigation/navigation.dart';
import 'package:shared_widgets/shared_widgets.dart';

class CancelRideScreen extends StatefulWidget {
  const CancelRideScreen({super.key, this.rideId});

  /// The Firestore ride document ID. If null the cancellation is local-only.
  final String? rideId;

  @override
  State<CancelRideScreen> createState() => _CancelRideScreenState();
}

class _CancelRideScreenState extends State<CancelRideScreen> {
  final RideRepository _rideRepository = RideRepository();
  final AppConfigRepository _configRepository = AppConfigRepository();

  String? _selectedReason;
  bool _cancelling = false;

  Future<void> _cancelRide() async {
    final reason = _selectedReason;
    if (reason == null) return;
    setState(() => _cancelling = true);
    try {
      final rideId = widget.rideId;
      if (rideId != null) {
        await _rideRepository.cancelRide(rideId, reason: reason);
      }
      if (!mounted) return;
      await _showCancelledPopup();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to cancel: ${e.toString()}'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  Future<void> _showCancelledPopup() async {
    final theme = Theme.of(context);
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.xl),
          ),
          child: AppCard(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
              AppSpacing.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'lib/assets/emoji/sad.png',
                  width: 100,
                  height: 100,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'We\'re so sad about your cancellation',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: AppColors.primaryGreen,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'We will continue to improve our service and satisfy you on the next order.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge,
                ),
                const SizedBox(height: AppSpacing.lg),
                PrimaryButton(
                  label: 'OK',
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    context.go(CustomerRoutePaths.rideHistory);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cancel Ride'),
      ),
      body: SafeArea(
        child: StreamBuilder<List<String>>(
          stream: _configRepository.watchCancelRideReasons(),
          initialData: AppConfigRepository.fallbackCancelReasons,
          builder: (context, snapshot) {
            final reasons = (snapshot.data == null || snapshot.data!.isEmpty)
                ? AppConfigRepository.fallbackCancelReasons
                : snapshot.data!;
            final hasReasons = reasons.isNotEmpty;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: AppSpacing.sm),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                  child: Text(
                    'Why are you cancelling?',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Expanded(
                  child: !hasReasons
                      ? const Center(
                          child: Text(
                            'No cancellation reasons configured.',
                            textAlign: TextAlign.center,
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                          itemCount: reasons.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: AppSpacing.sm),
                          itemBuilder: (context, index) {
                            final reason = reasons[index];
                            final selected = _selectedReason == reason;
                            return NeumorphicContainer(
                              onTap: () => setState(() => _selectedReason = reason),
                              radius: AppRadius.md,
                              padding: const EdgeInsets.all(AppSpacing.sm),
                              child: Row(
                                children: [
                                  Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: AppColors.primaryGreen,
                                        width: 2,
                                      ),
                                    ),
                                    child: selected
                                        ? Center(
                                            child: Container(
                                              width: 12,
                                              height: 12,
                                              decoration: const BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: AppColors.primaryGreen,
                                              ),
                                            ),
                                          )
                                        : null,
                                  ),
                                  const SizedBox(width: AppSpacing.md),
                                  Expanded(
                                    child: Text(
                                      reason,
                                      style: theme.textTheme.titleMedium,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: PrimaryButton(
                    label: _cancelling ? 'Cancelling...' : 'Confirm',
                    onPressed:
                        (!hasReasons || _selectedReason == null || _cancelling)
                            ? null
                            : _cancelRide,
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
