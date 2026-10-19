import 'package:design_system/design_system.dart';
import 'package:caride/core/driver/models/ride_model.dart';
import 'package:caride/core/driver/state/driver_active_ride_state.dart';
import 'package:caride/core/utils/phone_launcher.dart';
import 'package:caride/core/driver/utils/maps_launcher.dart';
import 'package:caride/features/driver/location/driver_presence_controller.dart';
import 'package:caride/features/driver/ride/data/driver_ride_repository.dart';
import 'package:caride/core/driver/widgets/customer_avatar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:caride/core/driver/config/app_env.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:navigation/navigation.dart';
import 'package:shared_widgets/shared_widgets.dart';

/// Redesigned Heading to Pickup screen featuring GlassAppBar, GlassContainers, static maps, and start-ride pin dialogs.
class TripPickupScreen extends StatefulWidget {
  const TripPickupScreen({super.key});

  @override
  State<TripPickupScreen> createState() => _TripPickupScreenState();
}

class _TripPickupScreenState extends State<TripPickupScreen> {
  final _rideRepo = DriverRideRepository();
  final _presenceController = driverPresenceController;
  bool _starting = false;

  Future<void> _openPickupDirections(RideModel ride) async {
    final currentPosition = _presenceController.currentPosition;

    await MapsLauncher.openGoogleMaps(
      destinationLat: ride.pickupLat,
      destinationLng: ride.pickupLng,
      destinationLabel: ride.pickupLabel,
      originLat: currentPosition?.latitude,
      originLng: currentPosition?.longitude,
    );
  }

  int _pinAttempts = 0;

  Future<void> _startRide(RideModel ride, String code) async {
    setState(() => _starting = true);
    try {
      await _rideRepo.startRide(ride.id, code);
      _pinAttempts = 0;
      DriverActiveRideState.instance.activeRideId = ride.id;
      if (mounted) {
        context.pushReplacement(DriverRoutePaths.tripActive);
      }
    } on FirebaseFunctionsException catch (e) {
      _pinAttempts++;
      final message = e.message ?? e.details?.toString() ?? e.toString();
      final isInvalidCode = message.toLowerCase().contains('code') || 
                            message.toLowerCase().contains('invalid');
      if (mounted) {
        if (_pinAttempts >= 3) {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.darkSurfaceRaised
                  : AppColors.lightSurfaceRaised,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
              title: const Text('Multiple Incorrect Attempts'),
              content: Text(
                'You have entered the start code incorrectly 3 times. Please call the rider to verify identity.',
                style: AppTextStyles.bodyMedium,
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('OK', style: TextStyle(color: AppColors.brand)),
                ),
              ],
            ),
          );
        } else {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              backgroundColor: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.darkSurfaceRaised
                  : AppColors.lightSurfaceRaised,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
              title: const Text('Invalid Code'),
              content: Text(
                isInvalidCode
                    ? 'The start code you entered is incorrect (Attempt $_pinAttempts/3). Please verify with the customer.'
                    : 'Failed to start ride: $message',
                style: AppTextStyles.bodyMedium,
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Try Again', style: TextStyle(color: AppColors.brand)),
                ),
              ],
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        final raw = e.toString().toLowerCase();
        String message = 'Unable to start ride. Please try again.';
        if (raw.contains('code') || raw.contains('invalid')) {
          message = 'The start code you entered is incorrect. Please verify the code with the customer.';
        } else if (raw.contains('network') || raw.contains('unavailable') || raw.contains('connection')) {
          message = 'Network connection issue. Please check your internet connection and try again.';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  Future<void> _showStartRideConfirmation(BuildContext context, RideModel ride) async {
    // Check if customer has startCode enabled
    bool startCodeEnabled = true;
    try {
      final customerDoc = await FirebaseFirestore.instance
          .collection('customers')
          .doc(ride.customerUid)
          .get();
      if (customerDoc.exists && customerDoc.data()?['startCodeEnabled'] == false) {
        startCodeEnabled = false;
      }
    } catch (_) {}

    if (!startCodeEnabled) {
      // Direct start without PIN prompt
      await _startRide(ride, '');
      return;
    }

    if (!context.mounted) return;

    BottomSheetShell.show(
      context: context,
      title: 'Start Ride?',
      child: Builder(
        builder: (sheetContext) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
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
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    color: AppColors.brand,
                    size: 40,
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Enter 4-digit start code from customer to begin the trip.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyMedium,
                ),
                const SizedBox(height: AppSpacing.md),
                PinInput(
                  length: 4,
                  onCompleted: (code) {
                    Navigator.pop(sheetContext);
                    _startRide(ride, code);
                  },
                ),
                const SizedBox(height: AppSpacing.xl),
                SecondaryButton(
                  label: 'Go Back',
                  onPressed: () => Navigator.pop(sheetContext),
                ),
                const SizedBox(height: AppSpacing.xl),
              ],
            ),
          );
        },
      ),
    );
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
        title: 'Heading to Pickup',
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
                  message: 'You have no active ride to navigate to.',
                  icon: Icons.navigation_outlined,
                ),
              );
            }
            if (ride.status == 'rideStarted') {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                context.pushReplacement(DriverRoutePaths.tripActive);
              });
              return const Center(child: AppLoader());
            }

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
                                    onPressed: () => _openPickupDirections(ride),
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
                                          NgnFormat.whole(ride.amountNaira ?? ride.customerOffer),
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
                                            Icons.circle,
                                            color: AppColors.brand,
                                            size: 14,
                                          ),
                                        ),
                                        const SizedBox(width: AppSpacing.sm),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                'PICKUP ADDRESS',
                                                style: AppTextStyles.caption.copyWith(
                                                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                ride.pickupLabel,
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
                                            Clipboard.setData(ClipboardData(text: ride.pickupLabel));
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(content: Text('Pickup address copied!')),
                                            );
                                          },
                                        ),
                                      ],
                                    ),
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
                              if (ride.status == 'driverArrived') ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: AppColors.brandGlass,
                                    borderRadius: BorderRadius.circular(AppRadius.md),
                                    border: Border.all(color: AppColors.brand.withValues(alpha: 0.3)),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.check_circle_rounded, color: AppColors.brand, size: 18),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Arrived — Waiting for rider to meet you',
                                        style: AppTextStyles.bodySmall.copyWith(
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.brand,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.md),
                              ],
                              Row(
                                children: [
                                  if (ride.status == 'driverEnRoute') ...[
                                    Expanded(
                                      child: PrimaryButton(
                                        label: "I've Arrived",
                                        icon: Icons.pin_drop_rounded,
                                        onPressed: () async {
                                          try {
                                            await _rideRepo.markDriverArrived(ride.id);
                                            if (!context.mounted) return;
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(content: Text("Marked as arrived at pickup!")),
                                            );
                                          } catch (e) {
                                            if (!context.mounted) return;
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text('Failed: $e'), backgroundColor: AppColors.error),
                                            );
                                          }
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: AppSpacing.xs),
                                  ],
                                  Expanded(
                                    child: PrimaryButton(
                                      label: 'Start Ride',
                                      isLoading: _starting,
                                      onPressed: () =>
                                          _showStartRideConfirmation(context, ride),
                                    ),
                                  ),
                                ],
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
}

