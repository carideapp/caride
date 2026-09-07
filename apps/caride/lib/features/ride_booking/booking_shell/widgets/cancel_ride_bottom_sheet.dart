import 'package:caride/core/config/app_config_repository.dart';
import 'package:caride/features/ride_booking/booking_shell/booking_shell_controller.dart';
import 'package:caride/features/ride_booking/booking_shell/models/booking_shell_step.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:navigation/navigation.dart';
import 'package:shared_widgets/shared_widgets.dart';

/// Redesigned Customer Cancel Ride Bottom Sheet.
class CancelRideBottomSheet extends StatefulWidget {
  const CancelRideBottomSheet({
    super.key,
    required this.controller,
    this.closeOnCancel = false,
  });

  final BookingShellController controller;
  final bool closeOnCancel;

  static Future<void> show(
    BuildContext context, {
    required BookingShellController controller,
    bool closeOnCancel = false,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CancelRideBottomSheet(
        controller: controller,
        closeOnCancel: closeOnCancel,
      ),
    );
  }

  @override
  State<CancelRideBottomSheet> createState() => _CancelRideBottomSheetState();
}

class _CancelRideBottomSheetState extends State<CancelRideBottomSheet> {
  final AppConfigRepository _config = AppConfigRepository();
  String? _selectedReason;
  bool _submitting = false;

  Future<void> _confirm() async {
    final reason = _selectedReason;
    if (reason == null) return;
    setState(() => _submitting = true);
    try {
      await widget.controller.cancelRide(reason: reason);
      HapticFeedback.lightImpact();
      if (!mounted) return;
      Navigator.of(context).pop();
      if (widget.closeOnCancel) {
        context.go(CustomerRoutePaths.home);
      } else {
        widget.controller.goTo(BookingShellStep.fromTo);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to cancel: ${e.toString()}'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BottomSheetShell(
      title: 'Cancel Ride',
      child: StreamBuilder<List<String>>(
        stream: _config.watchCancelRideReasons(),
        initialData: AppConfigRepository.fallbackCancelReasons,
        builder: (context, snap) {
          final reasons = (snap.data == null || snap.data!.isEmpty)
              ? AppConfigRepository.fallbackCancelReasons
              : snap.data!;
          final hasReasons = reasons.isNotEmpty;

          return Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.lg,
              AppSpacing.xl,
              AppSpacing.md,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Why are you cancelling?'),
                const SizedBox(height: AppSpacing.md),
                if (!hasReasons)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                    child: Text('No cancellation reasons configured.'),
                  )
                else
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 280),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: reasons.length,
                      separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.xs),
                      itemBuilder: (context, index) {
                        final reason = reasons[index];
                        final selected = _selectedReason == reason;
                        return Material(
                          color: Colors.transparent,
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                              color: selected ? AppColors.brand : Colors.grey,
                            ),
                            title: Text(
                              reason,
                              style: AppTextStyles.bodyLarge.copyWith(
                                fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                              ),
                            ),
                            onTap: () => setState(() => _selectedReason = reason),
                          ),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: AppSpacing.md),
                PrimaryButton(
                  label: _submitting ? 'Cancelling...' : 'Confirm cancellation',
                  onPressed: (!hasReasons || _selectedReason == null || _submitting) ? null : _confirm,
                ),
                const SizedBox(height: AppSpacing.sm),
                SecondaryButton(
                  label: 'Go back',
                  onPressed: _submitting ? null : () => Navigator.of(context).pop(),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
