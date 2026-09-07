import 'package:caride/features/profile/data/emergency_repository.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:shared_widgets/shared_widgets.dart';

/// Bottom sheet for managing the Pickup Code (startCode) feature.
/// Allows the passenger to toggle startCode verification on or off.
class PickupCodeSettingsSheet extends StatefulWidget {
  const PickupCodeSettingsSheet({super.key});

  @override
  State<PickupCodeSettingsSheet> createState() => _PickupCodeSettingsSheetState();
}

class _PickupCodeSettingsSheetState extends State<PickupCodeSettingsSheet> {
  final EmergencyRepository _repo = EmergencyRepository();
  bool? _enabled;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final enabled = await _repo.isStartCodeEnabled();
    if (mounted) setState(() => _enabled = enabled);
  }

  Future<void> _toggle(bool value) async {
    setState(() => _loading = true);
    try {
      await _repo.setStartCodeEnabled(value);
      if (mounted) setState(() => _enabled = value);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update setting: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.pagePadding, AppSpacing.md, AppSpacing.pagePadding, AppSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.brand.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: const Icon(Icons.shield_rounded, color: AppColors.brand, size: 22),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Pickup Code', style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.w800)),
                    Text(
                      'Verify your driver at pickup',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          // Explanation card
          GlassContainer(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'How it works',
                  style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: AppSpacing.sm),
                _bulletPoint('A unique 4-digit code is generated when you book a ride.'),
                _bulletPoint('You share the code with your driver at pickup.'),
                _bulletPoint('Your driver enters the code to start the trip — verifying your identity before departure.'),
                _bulletPoint('If the code is wrong, the driver cannot start the trip.'),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),

          // Toggle row
          GlassContainer(
            padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md, vertical: AppSpacing.sm),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Require Pickup Code',
                        style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _enabled == null
                            ? 'Loading...'
                            : _enabled!
                                ? 'Your driver must enter the correct code to start'
                                : 'Driver can start without a code',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                        ),
                      ),
                    ],
                  ),
                ),
                if (_enabled == null || _loading)
                  const SizedBox(
                      width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                else
                  Switch.adaptive(
                    value: _enabled!,
                    activeThumbColor: AppColors.brand,
                    onChanged: _toggle,
                  ),
              ],
            ),
          ),

          if (_enabled == false) ...[
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md, vertical: AppSpacing.sm),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 18),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Pickup Code is recommended for your safety. Enable it to ensure only the right driver starts your ride.',
                      style: AppTextStyles.bodySmall
                          .copyWith(color: Colors.amber.shade800),
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: SecondaryButton(
              label: 'Done',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 5),
            child: Icon(Icons.circle, size: 6, color: AppColors.brand),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: AppTextStyles.bodySmall),
          ),
        ],
      ),
    );
  }
}
