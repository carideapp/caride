import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:design_system/design_system.dart';
import 'package:shared_models/shared_models.dart';

import '../buttons/slide_to_action.dart';
import 'app_card.dart';

/// A premium ride offer card with urgency animation, countdown,
/// and slide-to-accept interaction.
class DriverOfferCard extends StatefulWidget {
  const DriverOfferCard({
    super.key,
    required this.request,
    required this.onAccept,
    required this.onDecline,
  });

  final DriverIncomingRequest request;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  State<DriverOfferCard> createState() => _DriverOfferCardState();
}

class _DriverOfferCardState extends State<DriverOfferCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final pulse = _pulseController.value * 0.03;
        return Transform.scale(
          scale: 1.0 + pulse,
          child: child,
        );
      },
      child: AppCard(
        useBlur: true,
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header: Route + Fare
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.brandGlass,
                    border: Border.all(
                      color: AppColors.brandGlassBorder,
                      width: 1.5,
                    ),
                  ),
                  child: const Center(
                    child: Icon(
                      CupertinoIcons.car_fill,
                      color: AppColors.brand,
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.request.routeLabel,
                        style: AppTextStyles.titleMedium.copyWith(
                          color: isDark
                              ? AppColors.textPrimaryDark
                              : AppColors.textPrimaryLight,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(
                            CupertinoIcons.clock,
                            size: 12,
                            color: isDark
                                ? AppColors.textTertiaryDark
                                : AppColors.textTertiaryLight,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${widget.request.pickupEtaMinutes} min pickup',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: isDark
                                  ? AppColors.textTertiaryDark
                                  : AppColors.textTertiaryLight,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Icon(
                            CupertinoIcons.star_fill,
                            size: 12,
                            color: AppColors.accent,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            widget.request.passengerRating.toStringAsFixed(1),
                            style: AppTextStyles.bodySmall.copyWith(
                              color: isDark
                                  ? AppColors.textTertiaryDark
                                  : AppColors.textTertiaryLight,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Text(
                  '₦${widget.request.customerOffer.toStringAsFixed(0)}',
                  style: AppTextStyles.statMedium.copyWith(
                    color: AppColors.brand,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xl),
            // Slide to accept
            SlideToAction(
              label: 'Slide to accept',
              onCompleted: widget.onAccept,
            ),
            const SizedBox(height: AppSpacing.sm),
            // Decline
            Center(
              child: TextButton(
                onPressed: widget.onDecline,
                child: Text(
                  'Decline',
                  style: AppTextStyles.titleSmall.copyWith(
                    color: isDark
                        ? AppColors.textTertiaryDark
                        : AppColors.textTertiaryLight,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
