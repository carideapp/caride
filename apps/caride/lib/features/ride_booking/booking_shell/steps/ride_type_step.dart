import 'package:caride/features/ride_booking/booking_shell/booking_shell_controller.dart';
import 'package:caride/features/ride_booking/booking_shell/models/booking_shell_step.dart';
import 'package:caride/features/ride_booking/data/ride_options_repository.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:shared_widgets/shared_widgets.dart';

/// Redesigned Customer Ride Type Selection Step.
class RideTypeStep extends StatefulWidget {
  const RideTypeStep({super.key, required this.controller});

  final BookingShellController controller;

  @override
  State<RideTypeStep> createState() => _RideTypeStepState();
}

class _RideTypeStepState extends State<RideTypeStep> {
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.controller.receiverName);
    _phoneController = TextEditingController(text: widget.controller.receiverPhone);
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: AppDurations.slow,
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final info = widget.controller.routeInfo;
    final summary = info == null
        ? 'Route summary unavailable'
        : '${info.distanceKm.toStringAsFixed(1)} km • ${info.durationMinutes.round()} min';

    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final options = (widget.controller.rideOptions.isEmpty
            ? RideOptionsRepository.fallbackOptions
            : widget.controller.rideOptions)
            .where((o) => o.type.toLowerCase() != 'courier')
            .toList();

        if (options.isNotEmpty &&
            !options.any((o) => o.type == widget.controller.rideType)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (options.isNotEmpty) widget.controller.setRideType(options.first.type);
          });
        }

        final isCourier = widget.controller.rideType.toLowerCase() == 'courier';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Choose a ride',
              style: AppTextStyles.headlineSmall.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              summary,
              style: AppTextStyles.bodyMedium.copyWith(
                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Expanded(
              child: options.isEmpty
                  ? const Center(child: AppLoader())
                  : ListView(
                      controller: _scrollController,
                      padding: EdgeInsets.zero,
                      children: [
                        ...options.map((opt) {
                          final selected = widget.controller.rideType == opt.type;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                            child: InkWell(
                              onTap: () {
                                widget.controller.setRideType(opt.type);
                                if (opt.type.toLowerCase() == 'courier') {
                                  _scrollToBottom();
                                }
                              },
                              borderRadius: BorderRadius.circular(AppRadius.lg),
                              child: AnimatedContainer(
                                duration: AppDurations.fast,
                                padding: const EdgeInsets.all(AppSpacing.md),
                                decoration: BoxDecoration(
                                  color: selected ? AppColors.brandGlass : Colors.transparent,
                                  borderRadius: BorderRadius.circular(AppRadius.lg),
                                  border: Border.all(
                                    color: selected
                                        ? AppColors.brand
                                        : (isDark ? AppColors.glassBorderDark : AppColors.glassBorderLight),
                                    width: selected ? 1.5 : 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Image.asset(
                                      opt.assetPath,
                                      width: 44,
                                      height: 44,
                                      fit: BoxFit.contain,
                                    ),
                                    const SizedBox(width: AppSpacing.md),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            opt.type,
                                            style: AppTextStyles.titleMedium.copyWith(
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            opt.subtitle,
                                            style: AppTextStyles.bodySmall.copyWith(
                                              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (selected)
                                      const Icon(
                                        Icons.check_circle_rounded,
                                        color: AppColors.brand,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),
                        if (isCourier) ...[
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            'Receiver Information',
                            style: AppTextStyles.titleMedium.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          AppTextField(
                            controller: _nameController,
                            hint: 'Receiver\'s Full Name',
                            obscureText: false,
                            onChanged: (val) => widget.controller
                                .setReceiverDetails(val, widget.controller.receiverPhone),
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          AppTextField(
                            controller: _phoneController,
                            hint: 'Receiver\'s Phone Number',
                            keyboardType: TextInputType.phone,
                            obscureText: false,
                            onChanged: (val) => widget.controller
                                .setReceiverDetails(widget.controller.receiverName, val),
                          ),
                        ],
                      ],
                    ),
            ),
            const SizedBox(height: AppSpacing.md),
            PrimaryButton(
              label: 'Continue',
              onPressed: widget.controller.from != null && widget.controller.to != null
                  ? () {
                      if (isCourier) {
                        if ((widget.controller.receiverName ?? '').trim().isEmpty ||
                            (widget.controller.receiverPhone ?? '').trim().isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please enter receiver\'s name and phone number.'),
                              backgroundColor: AppColors.error,
                            ),
                          );
                          return;
                        }
                      }
                      widget.controller.goTo(BookingShellStep.fare);
                    }
                  : null,
            ),
          ],
        );
      },
    );
  }
}
