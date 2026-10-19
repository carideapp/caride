import 'package:design_system/design_system.dart';
import 'package:caride/core/driver/models/ride_model.dart';
import 'package:caride/core/driver/state/driver_active_ride_state.dart';
import 'package:caride/core/driver/utils/maps_launcher.dart';
import 'package:caride/features/driver/location/driver_presence_controller.dart';
import 'package:caride/features/driver/ride/data/driver_ride_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData, HapticFeedback;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:caride/core/driver/config/app_env.dart';
import 'package:caride/core/utils/phone_launcher.dart';
import 'package:caride/core/driver/widgets/customer_avatar.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:navigation/navigation.dart';
import 'package:shared_widgets/shared_widgets.dart';

/// Redesigned Trip Active Screen with GlassAppBar, GlassContainers, and iOS-style dialogs.
class TripActiveScreen extends StatefulWidget {
  const TripActiveScreen({super.key});

  @override
  State<TripActiveScreen> createState() => _TripActiveScreenState();
}

class _TripActiveScreenState extends State<TripActiveScreen> {
  final _rideRepo = DriverRideRepository();
  final _presenceController = driverPresenceController;
  bool _completing = false;

  Future<void> _openDropoffDirections(RideModel ride) async {
    final currentPosition = _presenceController.currentPosition;

    await MapsLauncher.openGoogleMaps(
      destinationLat: ride.dropoffLat,
      destinationLng: ride.dropoffLng,
      destinationLabel: ride.dropoffLabel,
      originLat: currentPosition?.latitude,
      originLng: currentPosition?.longitude,
    );
  }

  Future<void> _completeRide(RideModel ride) async {
    setState(() => _completing = true);
    try {
      final fare = ride.finalFare ?? ride.amountNaira ?? ride.customerOffer;
      await _rideRepo.completeRide(ride.id, finalFare: fare);
      DriverActiveRideState.instance.lastCompletedRide = ride.copyWith(
        status: 'completed',
        finalFare: fare,
      );
      if (mounted) {
        context.pushReplacement(DriverRoutePaths.rateCustomer);
      }
    } catch (e) {
      if (mounted) {
        final raw = e.toString().toLowerCase();
        String userFriendlyError = 'Unable to complete ride. Please check your connection and try again.';
        if (raw.contains('network') || raw.contains('unavailable') || raw.contains('connection')) {
          userFriendlyError = 'Network connection issue. Please check your internet connection and tap "End Ride" again.';
        } else if (raw.contains('not the assigned driver')) {
          userFriendlyError = 'You are not listed as the assigned driver for this ride.';
        } else if (raw.contains('not in started state') || raw.contains('failed-precondition')) {
          userFriendlyError = 'The ride status has changed. Please refresh your trip status.';
        } else if (raw.contains('not found')) {
          userFriendlyError = 'Ride details could not be found. Please refresh your trip status.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(userFriendlyError),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _completing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      appBar: GlassAppBar(
        leading: Navigator.of(context).canPop()
            ? IconButton(
                icon: Icon(
                  Icons.arrow_back_rounded,
                  color: isDark ? Colors.white : AppColors.slate900,
                ),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
        title: 'Ride in Progress',
      ),
      body: SafeArea(
        child: StreamBuilder<RideModel?>(
          stream: _rideRepo.streamAssignedRide(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: AppLoader());
            }
            final ride = snapshot.data;
            if (ride == null) {
              return const Center(
                child: EmptyState(
                  title: 'No active ride',
                  message: 'No ride in progress.',
                  icon: Icons.directions_outlined,
                ),
              );
            }
            if (ride.status == 'driverEnRoute' || ride.status == 'driverArrived') {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                context.pushReplacement(DriverRoutePaths.tripPickup);
              });
              return const Center(child: AppLoader());
            }

            final displayFare = ride.finalFare ?? ride.amountNaira ?? ride.customerOffer;

            Widget mapPreview;
            if (ride.pickupLat != null &&
                ride.pickupLng != null &&
                ride.dropoffLat != null &&
                ride.dropoffLng != null) {
              final staticMapUrl = 'https://maps.googleapis.com/maps/api/staticmap'
                  '?size=600x340'
                  '&scale=2'
                  '&theme=dark'
                  '&path=color:0x16A34Aff|weight:5|${ride.pickupLat},${ride.pickupLng}|${ride.dropoffLat},${ride.dropoffLng}'
                  '&markers=color:green|label:P|${ride.pickupLat},${ride.pickupLng}'
                  '&markers=color:red|label:D|${ride.dropoffLat},${ride.dropoffLng}'
                  '&key=${AppEnv.googleMapsApiKey}';
              mapPreview = ClipRRect(
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: Image.network(
                  staticMapUrl,
                  fit: BoxFit.cover,
                  height: 180,
                  width: double.infinity,
                  errorBuilder: (context, error, stackTrace) => Container(
                    height: 180,
                    color: isDark ? AppColors.darkSurfaceRaised : AppColors.lightSurfaceRaised,
                    child: const Center(
                      child: Icon(Icons.map_outlined, size: 48, color: AppColors.brand),
                    ),
                  ),
                ),
              );
            } else {
              mapPreview = Container(
                height: 180,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurfaceRaised : AppColors.lightSurfaceRaised,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: const Center(
                  child: Icon(Icons.map_outlined, size: 48, color: AppColors.brand),
                ),
              );
            }

            return ResponsiveContainer(
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pagePadding, vertical: AppSpacing.md),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          GlassContainer(
                            padding: const EdgeInsets.all(AppSpacing.md),
                            child: Column(
                              children: [
                                mapPreview,
                                const SizedBox(height: AppSpacing.md),
                                SizedBox(
                                  width: double.infinity,
                                  child: PrimaryButton(
                                    onPressed: () => _openDropoffDirections(ride),
                                    icon: Icons.navigation_rounded,
                                    label: 'Get Route Directions',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pagePadding, vertical: AppSpacing.md),
                    child: FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                      future: FirebaseFirestore.instance
                          .collection('customers')
                          .doc(ride.customerUid)
                          .get(),
                      builder: (context, userSnap) {
                        final userData = userSnap.data?.data();
                        final fullName = userData?['fullName'] as String? ?? 'Customer';
                        final phone = userData?['phone'] as String? ?? '';
                        return GlassContainer(
                          padding: const EdgeInsets.all(AppSpacing.md),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  CustomerAvatar(
                                    customerUid: ride.customerUid,
                                    fallbackLetter: fullName,
                                    radius: 20,
                                  ),
                                  const SizedBox(width: AppSpacing.sm),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          fullName,
                                          style: AppTextStyles.titleMedium,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        if (phone.isNotEmpty)
                                          Text(
                                            phone,
                                            style: AppTextStyles.bodySmall.copyWith(
                                              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                            ),
                                          )
                                        else
                                          Text(
                                            'Customer',
                                            style: AppTextStyles.bodySmall,
                                          ),
                                        const SizedBox(height: 4),
                                        Text(
                                          NgnFormat.whole(displayFare),
                                          style: AppTextStyles.titleMedium.copyWith(
                                            color: AppColors.brand,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Call icon button
                                  Container(
                                    decoration: BoxDecoration(
                                      color: AppColors.brand.withValues(alpha: 0.12),
                                      shape: BoxShape.circle,
                                    ),
                                    child: IconButton(
                                      icon: const Icon(Icons.phone_rounded, color: AppColors.brand, size: 20),
                                      tooltip: 'Call Rider',
                                      onPressed: () async {
                                        if (phone.isNotEmpty) {
                                          final phoneUri = Uri(scheme: 'tel', path: phone);
                                          if (await canLaunchUrl(phoneUri)) {
                                            await launchUrl(phoneUri);
                                          }
                                        } else {
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            const SnackBar(content: Text('Rider phone number not available.')),
                                          );
                                        }
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: AppSpacing.xs),
                                  // Chat icon button
                                  Container(
                                    decoration: BoxDecoration(
                                      color: AppColors.brand.withValues(alpha: 0.12),
                                      shape: BoxShape.circle,
                                    ),
                                    child: IconButton(
                                      icon: const Icon(Icons.chat_bubble_rounded, color: AppColors.brand, size: 20),
                                      tooltip: 'Chat with Rider',
                                      onPressed: () => context.push(
                                        DriverRoutePaths.conversation,
                                        extra: {
                                          'rideId': ride.id,
                                          'customerName': fullName,
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.md),
                              GlassContainer(
                                tint: isDark ? AppColors.darkSurfaceRaised : AppColors.lightSurfaceRaised,
                                padding: const EdgeInsets.all(AppSpacing.md),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Padding(
                                          padding: EdgeInsets.only(top: 2),
                                          child: Icon(
                                            Icons.location_on,
                                            color: AppColors.error,
                                            size: 16,
                                          ),
                                        ),
                                        const SizedBox(width: AppSpacing.sm),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'DROPOFF ADDRESS',
                                                style: AppTextStyles.caption.copyWith(
                                                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                ride.dropoffLabel,
                                                style: AppTextStyles.bodyMedium,
                                              ),
                                            ],
                                          ),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.copy_rounded, size: 18),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          onPressed: () {
                                            Clipboard.setData(ClipboardData(text: ride.dropoffLabel));
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(content: Text('Dropoff address copied!')),
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                    if (ride.rideType.toLowerCase() == 'courier') ...[
                                      const Padding(
                                        padding: EdgeInsets.symmetric(vertical: AppSpacing.xs),
                                        child: Divider(),
                                      ),
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.center,
                                        children: [
                                          const Padding(
                                            padding: EdgeInsets.only(top: 2),
                                            child: Icon(
                                              Icons.person_outline_rounded,
                                              color: AppColors.brand,
                                              size: 16,
                                            ),
                                          ),
                                          const SizedBox(width: AppSpacing.sm),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'RECEIVER DETAILS',
                                                  style: AppTextStyles.caption.copyWith(
                                                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  '${ride.receiverName ?? "—"} (${ride.receiverPhone ?? "—"})',
                                                  style: AppTextStyles.bodyMedium,
                                                ),
                                              ],
                                            ),
                                          ),
                                          if (ride.receiverPhone != null && ride.receiverPhone!.isNotEmpty) ...[
                                            IconButton(
                                              icon: const Icon(Icons.phone_enabled_rounded, size: 18, color: AppColors.brand),
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(),
                                              onPressed: () async {
                                                final ok = await PhoneLauncher.call(ride.receiverPhone!);
                                                if (!context.mounted) return;
                                                if (!ok) {
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    const SnackBar(content: Text('Unable to place call.')),
                                                  );
                                                }
                                              },
                                            ),
                                            const SizedBox(width: AppSpacing.md),
                                            IconButton(
                                              icon: const Icon(Icons.copy_rounded, size: 18),
                                              padding: EdgeInsets.zero,
                                              constraints: const BoxConstraints(),
                                              onPressed: () {
                                                Clipboard.setData(ClipboardData(text: '${ride.receiverName ?? ""} - ${ride.receiverPhone ?? ""}'));
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  const SnackBar(content: Text('Receiver details copied!')),
                                                );
                                              },
                                            ),
                                          ],
                                        ],
                                      ),
                                      if (ride.deliveryPin != null && ride.deliveryPin!.isNotEmpty) ...[
                                        const Padding(
                                          padding: EdgeInsets.symmetric(vertical: AppSpacing.xs),
                                          child: Divider(),
                                        ),
                                        Row(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Padding(
                                              padding: EdgeInsets.only(top: 2),
                                              child: Icon(
                                                Icons.lock_outline_rounded,
                                                color: AppColors.brand,
                                                size: 16,
                                              ),
                                            ),
                                            const SizedBox(width: AppSpacing.sm),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    'DELIVERY PIN',
                                                    style: AppTextStyles.caption.copyWith(
                                                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                                      fontWeight: FontWeight.bold,
                                                  ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    ride.deliveryPin!,
                                                    style: AppTextStyles.bodyMedium,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              PrimaryButton(
                                label: 'End Ride',
                                isLoading: _completing,
                                onPressed: () =>
                                    _showCompleteConfirmation(context, ride),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void _showCompleteConfirmation(BuildContext context, RideModel ride) {
    final hasPin = ride.deliveryPin != null && ride.deliveryPin!.isNotEmpty;

    BottomSheetShell.show<void>(
      context: context,
      title: hasPin ? 'Enter Delivery PIN' : 'End Ride?',
      child: Builder(
        builder: (sheetContext) {
          return Padding(
            padding: EdgeInsets.only(
              left: AppSpacing.pagePadding,
              right: AppSpacing.pagePadding,
              top: AppSpacing.md,
              bottom: AppSpacing.md + MediaQuery.of(sheetContext).viewInsets.bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.brandGlass,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    hasPin ? Icons.pin_outlined : Icons.check_circle_rounded,
                    color: AppColors.brand,
                    size: 40,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  hasPin
                      ? 'Ask the recipient for the 4-digit delivery PIN to complete the delivery.'
                      : 'Confirm that you have arrived at the dropoff location and the ride is complete.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.md),
                if (hasPin) ...[
                  PinInput(
                    length: 4,
                    onCompleted: (code) {
                      if (code == ride.deliveryPin) {
                        Navigator.pop(sheetContext);
                        _completeRide(ride);
                      } else {
                        HapticFeedback.vibrate();
                        ScaffoldMessenger.of(sheetContext).showSnackBar(
                          const SnackBar(
                            content: Text('Incorrect Delivery PIN. Please try again.'),
                            backgroundColor: AppColors.error,
                          ),
                        );
                      }
                    },
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  SecondaryButton(
                    label: 'Go Back',
                    onPressed: () => Navigator.pop(sheetContext),
                  ),
                ] else ...[
                  Row(
                    children: [
                      Expanded(
                        child: SecondaryButton(
                          label: 'Cancel',
                          onPressed: () => Navigator.pop(sheetContext),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: PrimaryButton(
                          label: 'Yes, End Ride',
                          isLoading: _completing,
                          onPressed: () {
                            Navigator.pop(sheetContext);
                            _completeRide(ride);
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}
