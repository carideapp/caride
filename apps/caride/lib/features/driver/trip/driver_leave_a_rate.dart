import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:caride/core/driver/widgets/customer_avatar.dart';
import 'package:caride/features/driver/profile/widgets/success_dialog.dart';
import 'package:design_system/design_system.dart';
import 'package:caride/core/driver/state/driver_active_ride_state.dart';
import 'package:caride/features/driver/ride/data/driver_ride_repository.dart';
import 'package:flutter/material.dart';
import 'package:navigation/navigation.dart';
import 'package:shared_widgets/shared_widgets.dart';

/// Redesigned Driver Leave A Rate Screen with large stars, custom comments text box inside a GlassContainer, and app bar styling.
class DriverLeaveARateScreen extends StatefulWidget {
  const DriverLeaveARateScreen({super.key});

  @override
  State<DriverLeaveARateScreen> createState() => _DriverLeaveARateScreenState();
}

class _DriverLeaveARateScreenState extends State<DriverLeaveARateScreen> {
  final _rideRepo = DriverRideRepository();
  int _rating = 0;
  final _commentController = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final rideId = DriverActiveRideState.instance.lastCompletedRide?.id;
    if (rideId == null) {
      if (mounted) {
        DriverActiveRideState.instance.lastCompletedRide = null;
        context.go(DriverRoutePaths.home);
      }
      return;
    }

    setState(() => _submitting = true);
    try {
      await _rideRepo.rateCustomer(
        rideId: rideId,
        rating: _rating,
        comment: _commentController.text.trim().isEmpty
            ? null
            : _commentController.text.trim(),
      );
      if (!mounted) return;
      
      await SuccessDialog.show(
        context,
        title: 'Thanks for your rating',
        description: 'Your feedback helps improve our community.',
        buttonLabel: 'Done',
        onButtonPressed: () {
          DriverActiveRideState.instance.lastCompletedRide = null;
          context.go(DriverRoutePaths.home);
        },
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to submit rating: $e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lastCompletedRide = DriverActiveRideState.instance.lastCompletedRide;
    final customerUid = lastCompletedRide?.customerUid ?? '';

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: GlassAppBar(
        title: 'Rate Customer',
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: ResponsiveContainer(
          child: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>?>(
            future: customerUid.isNotEmpty
                ? FirebaseFirestore.instance
                    .collection('customers')
                    .doc(customerUid)
                    .get()
                : Future<DocumentSnapshot<Map<String, dynamic>>?>.value(null),
            builder: (context, userSnap) {
              final userData = userSnap.data?.data();
              final fullName = userData?['fullName'] as String? ?? 'Customer';

              return ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.pagePadding,
                  vertical: AppSpacing.xl,
                ),
                children: [
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: AppColors.brandGlass,
                        shape: BoxShape.circle,
                      ),
                      child: customerUid.isNotEmpty
                          ? CustomerAvatar(
                              customerUid: customerUid,
                              fallbackLetter: fullName,
                              radius: 40,
                            )
                          : const CircleAvatar(
                              radius: 40,
                              backgroundColor: AppColors.brand,
                              child: Icon(Icons.person, size: 40, color: Colors.white),
                            ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Center(
                    child: Text(
                      'How was $fullName?',
                      textAlign: TextAlign.center,
                      style: AppTextStyles.headlineMedium.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (index) {
                  final isSelected = index < _rating;
                  return IconButton(
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    onPressed: () => setState(() => _rating = index + 1),
                    icon: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                      child: Icon(
                        isSelected
                            ? Icons.star_rounded
                            : Icons.star_outline_rounded,
                        size: 44,
                        color: isSelected
                            ? Colors.orangeAccent
                            : (isDark ? AppColors.textTertiaryDark : AppColors.textTertiaryLight),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: AppSpacing.xl),

              GlassContainer(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: TextField(
                  controller: _commentController,
                  maxLines: 4,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Add a comment (optional)',
                    hintStyle: AppTextStyles.bodyMedium.copyWith(
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),

              PrimaryButton(
                label: 'Submit Feedback',
                isLoading: _submitting,
                onPressed: _rating > 0 ? _submit : null,
              ),
              Center(
                child: TextButton(
                  onPressed: () {
                    DriverActiveRideState.instance.lastCompletedRide = null;
                    context.go(DriverRoutePaths.home);
                  },
                  child: Text(
                    'Skip',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    ),
  ),
);
  }
}
