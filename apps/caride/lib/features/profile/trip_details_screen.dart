import 'dart:async';
import 'package:caride/features/chat/conversation_screen.dart';
import 'package:caride/core/utils/phone_launcher.dart';
import 'package:caride/features/profile/driver_tracking_screen.dart';
import 'package:caride/features/profile/data/driver_public_profile_repository.dart';
import 'package:caride/features/profile/data/driver_location_repository.dart';
import 'package:caride/features/profile/share_receipt_screen.dart';
import 'package:caride/features/profile/customer_support_screen.dart';
import 'package:caride/features/profile/rate_driver_screen.dart';
import 'package:caride/features/profile/data/shared_trip_repository.dart';
import 'package:caride/features/ride_booking/data/ride_repository.dart';
import 'package:caride/features/ride_booking/data/arrival_calculator.dart';
import 'package:caride/features/ride_booking/booking_shell/booking_shell_screen.dart';
import 'package:caride/features/ride_booking/booking_shell/models/booking_shell_step.dart';
import 'package:caride/features/profile/emergency_screen.dart';
import 'package:caride/features/profile/share_trip_sheet.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:shared_widgets/shared_widgets.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:navigation/navigation.dart';

class TripDetailsScreen extends StatefulWidget {
  const TripDetailsScreen({super.key, required this.rideId});

  final String rideId;

  @override
  State<TripDetailsScreen> createState() => _TripDetailsScreenState();
}

class _TripDetailsScreenState extends State<TripDetailsScreen> {
  final RideRepository _rideRepository = RideRepository();
  final DriverPublicProfileRepository _driverProfileRepository = DriverPublicProfileRepository();
  final DriverLocationRepository _driverLocationRepository = DriverLocationRepository();
  final ArrivalCalculator _arrivalCalculator = ArrivalCalculator();

  StreamSubscription<DriverRideLocation?>? _locationSub;
  String _etaText = '';
  String? _cachedRideId;
  bool _hasAutoPromptedRate = false;

  void _updateLocationSubscription(RideModel ride) {
    if (ride.status == 'driverEnRoute') {
      if (_cachedRideId != ride.id) {
        _cachedRideId = ride.id;
        _locationSub?.cancel();
        _locationSub = _driverLocationRepository.watchRideDriverLocation(ride.id).listen((loc) {
          if (loc != null && ride.pickupLat != null && ride.pickupLng != null) {
            _arrivalCalculator.calculateEta(
              driverLat: loc.latitude,
              driverLng: loc.longitude,
              destinationLat: ride.pickupLat!,
              destinationLng: ride.pickupLng!,
            ).then((eta) {
              if (mounted && eta != _etaText) {
                setState(() {
                  _etaText = eta;
                });
              }
            });
          }
        });
      }
    } else {
      _locationSub?.cancel();
      _locationSub = null;
      _cachedRideId = null;
    }
  }
  String _formatDuration(int totalMinutes) {
    if (totalMinutes < 60) {
      return '$totalMinutes min';
    }
    final hours = totalMinutes ~/ 60;
    final mins = totalMinutes % 60;
    if (mins == 0) {
      return '$hours hr${hours > 1 ? 's' : ''}';
    }
    return '$hours hr${hours > 1 ? 's' : ''} $mins min';
  }

  Future<void> _shareTrip(BuildContext context, String rideId) async {
    final repo = SharedTripRepository();
    BuildContext? loadingCtx;
    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (c) {
          loadingCtx = c;
          return const Center(child: CircularProgressIndicator());
        },
      );
      final code = await repo.createShareCode(rideId);
      if (loadingCtx != null && loadingCtx!.mounted) {
        Navigator.pop(loadingCtx!);
      } else if (context.mounted) {
        Navigator.pop(context);
      }

      if (!context.mounted) return;

      final formatted = code.length == 6 ? '${code.substring(0, 3)} ${code.substring(3, 6)}' : code;

      showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.share_location_rounded,
                  color: AppColors.primaryGreen,
                  size: 40,
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                'Share Your Trip',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Send this code to a friend so they can monitor your ride live.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.md),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border.all(color: AppColors.primaryGreen.withValues(alpha: 0.3)),
                ),
                child: Center(
                  child: Text(
                    formatted,
                    style: Theme.of(dialogContext).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: AppColors.primaryGreen,
                          letterSpacing: 4,
                        ),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xl),
              SizedBox(
                width: double.infinity,
                child: PrimaryButton(
                  label: 'Done',
                  onPressed: () => Navigator.pop(dialogContext),
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Pop loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to share trip: ${e.toString()}')),
        );
      }
    }
  }

  @override
  void dispose() {
    _locationSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final backgroundColor = isDark ? AppColors.darkBackground : AppColors.lightBackground;

    return StreamBuilder<RideModel?>(
      stream: _rideRepository.watchRide(widget.rideId),
      builder: (context, snap) {
        if (snap.hasError) {
          return Scaffold(
            backgroundColor: backgroundColor,
            appBar: AppBar(title: const Text('Ride Details')),
            body: const Center(child: Text('Unable to load ride details.')),
          );
        }
        if (!snap.hasData) {
          return Scaffold(
            backgroundColor: backgroundColor,
            body: const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryGreen),
              ),
            ),
          );
        }

        final ride = snap.data;
        if (ride == null) {
          return Scaffold(
            backgroundColor: backgroundColor,
            appBar: AppBar(title: const Text('Ride Details')),
            body: const Center(child: Text('Ride not found.')),
          );
        }

        final isOngoing = ride.status != 'completed' && ride.status != 'cancelled';
        final driverUid = ride.driverUid ?? '';
        final isDriverEnRoute = ride.status == 'driverEnRoute';

        if (ride.status == 'completed' && ride.driverRating == null && ride.ratedAt == null && !_hasAutoPromptedRate) {
          _hasAutoPromptedRate = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => RateDriverScreen(rideId: ride.id),
              ),
            );
          });
        }

        _updateLocationSubscription(ride);

        // Date & Time formatting for AppBar
        final displayDate = ride.completedAt != null
            ? DateFormat('EEE, d MMM yyyy').format(ride.completedAt!)
            : (ride.createdAt != null
                ? DateFormat('EEE, d MMM yyyy').format(ride.createdAt!)
                : 'Ride Details');

        final displayTime = ride.completedAt != null
            ? DateFormat('hh:mm a').format(ride.completedAt!)
            : (ride.createdAt != null
                ? DateFormat('hh:mm a').format(ride.createdAt!)
                : '');

        // Duration calculation
        final durationMinutes = ride.completedAt != null && ride.createdAt != null
            ? ride.completedAt!.difference(ride.createdAt!).inMinutes
            : 15;
        final durationDisplay = _formatDuration(durationMinutes);

        // Distance calculation
        double distanceInMeters = 0.0;
        if (ride.pickupLat != null && ride.pickupLng != null && ride.dropoffLat != null && ride.dropoffLng != null) {
          distanceInMeters = Geolocator.distanceBetween(
            ride.pickupLat!,
            ride.pickupLng!,
            ride.dropoffLat!,
            ride.dropoffLng!,
          );
        }
        final distanceKm = distanceInMeters > 0 ? (distanceInMeters / 1000) : 5.8;

        return Scaffold(
          backgroundColor: backgroundColor,
          floatingActionButton: isOngoing
              ? FloatingActionButton.extended(
                  heroTag: 'safety_fab_trip_details',
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => EmergencyScreen(rideId: ride.id),
                      ),
                    );
                  },
                  backgroundColor: AppColors.error,
                  icon: const Icon(Icons.shield_rounded, color: Colors.white, size: 20),
                  label: const Text(
                    'Safety',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                )
              : null,
          appBar: AppBar(
            automaticallyImplyLeading: true,
            backgroundColor: backgroundColor,
            elevation: 0,
            scrolledUnderElevation: 0,
            centerTitle: true,
            title: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  displayDate,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : AppColors.slate900,
                  ),
                ),
                if (displayTime.isNotEmpty)
                  Text(
                    displayTime,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: isDark ? Colors.white : const Color(0xFF6E7191),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              children: [
                // 1. Route Map & Details Card
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(
                      color: isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFE9EAF0),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Map View container
                      if (ride.pickupLat != null && ride.pickupLng != null && ride.dropoffLat != null && ride.dropoffLng != null)
                        SizedBox(
                          height: 180,
                          child: ClipRRect(
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
                            child: GoogleMap(
                              initialCameraPosition: CameraPosition(
                                target: LatLng(
                                  (ride.pickupLat! + ride.dropoffLat!) / 2,
                                  (ride.pickupLng! + ride.dropoffLng!) / 2,
                                ),
                                zoom: 12,
                              ),
                              markers: {
                                Marker(
                                  markerId: const MarkerId('pickup'),
                                  position: LatLng(ride.pickupLat!, ride.pickupLng!),
                                  icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
                                ),
                                Marker(
                                  markerId: const MarkerId('dropoff'),
                                  position: LatLng(ride.dropoffLat!, ride.dropoffLng!),
                                  icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
                                ),
                              },
                              zoomControlsEnabled: false,
                              myLocationButtonEnabled: false,
                              compassEnabled: false,
                              mapToolbarEnabled: false,
                              rotateGesturesEnabled: false,
                              scrollGesturesEnabled: false,
                              tiltGesturesEnabled: false,
                              zoomGesturesEnabled: false,
                            ),
                          ),
                        ),
                      
                      Padding(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'City ride',
                                      style: theme.textTheme.titleLarge?.copyWith(
                                        fontWeight: FontWeight.w900,
                                        color: isDark ? Colors.white : AppColors.slate900,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Ride • ${_statusLabel(ride.status)}',
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: isDark ? Colors.white : Colors.grey[700],
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                Image.asset(
                                  _rideTypeAsset(ride.rideType),
                                  height: 52,
                                  fit: BoxFit.contain,
                                ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.md),
                            
                            // Pickup Info
                            Row(
                              children: [
                                const Icon(Icons.circle_outlined, size: 16, color: AppColors.primaryGreen),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    ride.pickupLabel,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: isDark ? Colors.white : AppColors.slate900,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                if (ride.createdAt != null)
                                  Text(
                                    DateFormat('hh:mm a').format(ride.createdAt!),
                                    style: theme.textTheme.bodySmall?.copyWith(color: isDark ? Colors.white : Colors.grey[700], fontWeight: FontWeight.w600),
                                  ),
                              ],
                            ),
                            // Connector line
                            Container(
                              margin: const EdgeInsets.only(left: 7, top: 4, bottom: 4),
                              width: 1.5,
                              height: 16,
                              color: isDark ? Colors.white54 : const Color(0xFFE2E8F0),
                            ),
                            // Dropoff Info
                            Row(
                              children: [
                                const Icon(Icons.location_on_rounded, size: 16, color: AppColors.error),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    ride.dropoffLabel,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: isDark ? Colors.white : AppColors.slate900,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                if (ride.completedAt != null)
                                  Text(
                                    DateFormat('hh:mm a').format(ride.completedAt!),
                                    style: theme.textTheme.bodySmall?.copyWith(color: isDark ? Colors.white : Colors.grey[700], fontWeight: FontWeight.w600),
                                  ),
                              ],
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            
                            // Duration & Distance Row
                            Row(
                              children: [
                                Expanded(
                                  child: Row(
                                    children: [
                                      Icon(Icons.access_time_rounded, color: isDark ? Colors.white : Colors.grey[700], size: 18),
                                      const SizedBox(width: 6),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Duration',
                                            style: theme.textTheme.bodySmall?.copyWith(color: isDark ? Colors.white : Colors.grey[700], fontWeight: FontWeight.w600),
                                          ),
                                          Text(
                                            durationDisplay,
                                            style: theme.textTheme.bodyMedium?.copyWith(
                                              fontWeight: FontWeight.bold,
                                              color: isDark ? Colors.white : AppColors.slate900,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Expanded(
                                  child: Row(
                                    children: [
                                      Icon(Icons.swap_calls_rounded, color: isDark ? Colors.white : Colors.grey[700], size: 18),
                                      const SizedBox(width: 6),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Distance',
                                            style: theme.textTheme.bodySmall?.copyWith(color: isDark ? Colors.white : Colors.grey[700], fontWeight: FontWeight.w600),
                                          ),
                                          Text(
                                            '${distanceKm.toStringAsFixed(1).replaceAll('.', ',')} km',
                                            style: theme.textTheme.bodyMedium?.copyWith(
                                              fontWeight: FontWeight.bold,
                                              color: isDark ? Colors.white : AppColors.slate900,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),

                // Arrival Banner for driverArrived
                if (ride.status == 'driverArrived') ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.primaryGreen.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      border: Border.all(color: AppColors.primaryGreen.withValues(alpha: 0.35), width: 1.2),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: AppColors.primaryGreen,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.check_rounded, color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Your Driver has arrived!',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.primaryGreen,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Please meet your driver at the pickup address.',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: isDark ? Colors.grey[300] : const Color(0xFF4A4D70),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],

                // 2. Driver Card
                if (driverUid.isNotEmpty)
                  StreamBuilder<DriverPublicProfile?>(
                    stream: _driverProfileRepository.watchDriver(driverUid),
                    builder: (context, driverSnap) {
                      final profile = driverSnap.data;
                      final driverName = profile?.fullName ?? ride.driverName ?? 'Driver';
                      final phone = profile?.phone ?? '';
                      final rating = profile?.averageRating ?? 0.0;

                      return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                        stream: FirebaseFirestore.instance
                            .collection('drivers')
                            .doc(driverUid)
                            .collection('vehicle')
                            .doc('info')
                            .snapshots(),
                        builder: (context, vehicleSnap) {
                          final vehicleData = vehicleSnap.data?.data();
                          return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                            stream: FirebaseFirestore.instance
                                .collection('drivers')
                                .doc(driverUid)
                                .collection('vehicle')
                                .doc('review')
                                .snapshots(),
                            builder: (context, reviewSnap) {
                              final reviewData = reviewSnap.data?.data();
                              final newVals = reviewData?['newValues'] as Map<String, dynamic>?;

                              final color = (vehicleData?['color'] as String?)?.trim() ?? (newVals?['color'] as String?)?.trim() ?? '';
                              final make = (vehicleData?['make'] as String?)?.trim() ?? (newVals?['make'] as String?)?.trim() ?? '';
                              final model = (vehicleData?['model'] as String?)?.trim() ?? (newVals?['model'] as String?)?.trim() ?? '';
                              final plate = (vehicleData?['plateNumber'] as String?)?.trim() ?? (vehicleData?['licensePlate'] as String?)?.trim() ?? (newVals?['plateNumber'] as String?)?.trim() ?? (newVals?['licensePlate'] as String?)?.trim() ?? '';

                              final vehicleParts = <String>[
                                if (color.isNotEmpty) color,
                                if (make.isNotEmpty) make,
                                if (model.isNotEmpty) model,
                              ];
                              final vehicleDesc = vehicleParts.isNotEmpty ? vehicleParts.join(' ') : 'Vehicle details registered';

                              return Container(
                                decoration: BoxDecoration(
                                  color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                                  borderRadius: BorderRadius.circular(AppRadius.lg),
                                  border: Border.all(
                                    color: isDark ? Colors.white.withValues(alpha: 0.12) : const Color(0xFFE9EAF0),
                                  ),
                                ),
                                padding: const EdgeInsets.all(AppSpacing.md),
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 24,
                                          backgroundImage: (profile?.profilePhotoUrl ?? '').isNotEmpty
                                              ? NetworkImage(profile!.profilePhotoUrl)
                                              : null,
                                          backgroundColor: isDark ? const Color(0xFF2E2E2E) : const Color(0xFFF1F5F9),
                                          child: (profile?.profilePhotoUrl ?? '').isEmpty
                                              ? Text(
                                                  driverName.isEmpty ? '?' : driverName.substring(0, 1),
                                                  style: theme.textTheme.titleMedium?.copyWith(
                                                    color: isDark ? Colors.white : AppColors.slate900,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                )
                                              : null,
                                        ),
                                        const SizedBox(width: AppSpacing.sm),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              if (plate.isNotEmpty) ...[
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                  decoration: BoxDecoration(
                                                    color: isDark ? const Color(0xFF2E2E2E) : const Color(0xFFF1F5F9),
                                                    borderRadius: BorderRadius.circular(6),
                                                    border: Border.all(
                                                      color: isDark ? Colors.white24 : Colors.black.withValues(alpha: 0.08),
                                                      width: 0.8,
                                                    ),
                                                  ),
                                                  child: Text(
                                                    plate,
                                                    style: theme.textTheme.bodyMedium?.copyWith(
                                                      fontWeight: FontWeight.w900,
                                                      color: isDark ? Colors.white : AppColors.slate900,
                                                      letterSpacing: 0.5,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                              ],
                                              Text(
                                                driverName,
                                                style: theme.textTheme.titleMedium?.copyWith(
                                                  fontWeight: FontWeight.w800,
                                                  color: isDark ? Colors.white : AppColors.slate900,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                vehicleDesc,
                                                style: theme.textTheme.bodySmall?.copyWith(
                                                  color: isDark ? Colors.white : const Color(0xFF6E7191),
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (rating > 0 || (profile?.completedRides ?? 0) > 0)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppColors.primaryGreen.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(AppRadius.sm),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.star_rounded, color: AppColors.primaryGreen, size: 14),
                                            const SizedBox(width: 2),
                                            Text(
                                              '${rating > 0 ? rating.toStringAsFixed(1) : '5.0'} (${profile?.completedRides ?? 0})',
                                              style: theme.textTheme.bodySmall?.copyWith(
                                                color: AppColors.primaryGreen,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    if (isOngoing) ...[
                                      const Divider(height: AppSpacing.lg),
                                      Row(
                                        children: [
                                          Expanded(
                                            child: SecondaryButton(
                                              label: 'Chat',
                                              onPressed: () {
                                                Navigator.of(context, rootNavigator: true).push(
                                                  MaterialPageRoute(
                                                    builder: (_) => ConversationScreen(
                                                      driverName: driverName,
                                                      rideId: ride.id,
                                                      driverUid: driverUid,
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                          if (phone.trim().isNotEmpty) ...[
                                            const SizedBox(width: AppSpacing.sm),
                                            Expanded(
                                              child: SecondaryButton(
                                                label: 'Call',
                                                onPressed: () async {
                                                  final ok = await PhoneLauncher.call(phone);
                                                  if (!context.mounted) return;
                                                  if (!ok) {
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      const SnackBar(content: Text('Unable to place call.')),
                                                    );
                                                  }
                                                },
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              );
                            },
                          );
                        },
                      );
                    },
                  ),
                
                // 3. Start Code Card (For driverEnRoute or driverArrived)
                if ((ride.status == 'driverEnRoute' || ride.status == 'driverArrived') && ride.startCode != null && ride.startCode!.isNotEmpty) ...[
                  const SizedBox(height: AppSpacing.sm),
                  _StartCodeCard(startCode: ride.startCode!),
                ],

                const SizedBox(height: AppSpacing.md),

                // 4. Action Buttons Row (Share Trip, Receipt, Support, Repeat, Rate)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    // Share Trip Action (only during active ongoing trips)
                    if (isOngoing)
                      _buildCircularAction(
                        icon: Icons.share_location_rounded,
                        label: 'Share Trip',
                        onTap: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (_) => ShareTripSheet(
                              rideId: ride.id,
                              pickupLabel: ride.pickupLabel,
                              dropoffLabel: ride.dropoffLabel,
                              driverName: ride.driverName,
                            ),
                          );
                        },
                        isDark: isDark,
                      ),
                    // Receipt Action
                    _buildCircularAction(
                      icon: Icons.receipt_long_rounded,
                      label: 'Receipt',
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ShareReceiptScreen(rideId: ride.id),
                          ),
                        );
                      },
                      isDark: isDark,
                    ),
                    // Support Action
                    _buildCircularAction(
                      icon: Icons.chat_bubble_outline_rounded,
                      label: 'Support',
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const CustomerSupportScreen(),
                          ),
                        );
                      },
                      isDark: isDark,
                    ),
                    // Repeat Ride
                    _buildCircularAction(
                      icon: Icons.replay_rounded,
                      label: 'Repeat ride',
                      onTap: () {
                        context.go(CustomerRoutePaths.home);
                      },
                      isDark: isDark,
                    ),
                    // Rate Driver / Driver Rated
                    _buildCircularAction(
                      icon: Icons.star_border_rounded,
                      label: (ride.driverRating != null || ride.ratedAt != null) ? 'Driver Rated' : 'Rate Driver',
                      onTap: () {
                        if (ride.status != 'completed') {
                          showDialog(
                            context: context,
                            builder: (dialogContext) => AlertDialog(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(AppRadius.lg),
                              ),
                              content: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(AppSpacing.md),
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryGreen.withValues(alpha: 0.10),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.star_rounded,
                                      color: AppColors.primaryGreen,
                                      size: 40,
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.lg),
                                  Text(
                                    'Rate Driver',
                                    style: theme.textTheme.headlineSmall?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: AppSpacing.md),
                                  Text(
                                    'You can rate the driver after the ride is completed.',
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.bodyMedium,
                                  ),
                                  const SizedBox(height: AppSpacing.xl),
                                  SizedBox(
                                    width: double.infinity,
                                    child: PrimaryButton(
                                      label: 'OK',
                                      onPressed: () => Navigator.pop(dialogContext),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        } else if (ride.driverRating != null || ride.ratedAt != null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text("You've rated this driver already")),
                          );
                        } else {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => RateDriverScreen(rideId: ride.id),
                            ),
                          );
                        }
                      },
                      isDark: isDark,
                    ),
                  ],
                ),

                const SizedBox(height: AppSpacing.lg),

                // 5. Payment details card
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(
                      color: isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFE9EAF0),
                    ),
                  ),
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'I paid',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : AppColors.slate900,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Fare',
                            style: theme.textTheme.bodyMedium?.copyWith(color: isDark ? Colors.white : Colors.grey[700], fontWeight: FontWeight.w600),
                          ),
                          Text(
                            'NGN ${(ride.finalFare ?? ride.customerOffer).toStringAsFixed(2).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: isDark ? Colors.white : AppColors.slate900,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: AppSpacing.lg),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.payments_rounded, color: AppColors.primaryGreen, size: 20),
                              const SizedBox(width: 6),
                              Text(
                                'Total paid',
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : AppColors.slate900,
                                ),
                              ),
                            ],
                          ),
                          Text(
                            'NGN ${(ride.finalFare ?? ride.customerOffer).toStringAsFixed(2).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (Match m) => '${m[1]},')}',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : AppColors.slate900,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // 6. Support Actions for Driver En Route
                if (isOngoing) ...[
                  const SizedBox(height: AppSpacing.md),
                  if (isDriverEnRoute) ...[
                    PrimaryButton(
                      label: 'Track Driver',
                      onPressed: ride.id.isEmpty
                          ? null
                          : () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => DriverTrackingScreen(rideId: ride.id),
                                ),
                              );
                            },
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  PrimaryButton(
                    label: 'Monitor my Trip',
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => BookingShellScreen(
                            extra: {
                              'rideId': ride.id,
                              'step': BookingShellStep.tracking,
                              'pickupLat': ride.pickupLat,
                              'pickupLng': ride.pickupLng,
                              'pickupLabel': ride.pickupLabel,
                              'dropoffLat': ride.dropoffLat,
                              'dropoffLng': ride.dropoffLng,
                              'dropoffLabel': ride.dropoffLabel,
                            },
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  SecondaryButton(
                    label: 'Share my Trip',
                    onPressed: () => _shareTrip(context, ride.id),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCircularAction({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(30),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2E2E2E) : const Color(0xFFF1F5F9),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: isDark ? Colors.white : AppColors.slate900,
              size: 24,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }
}

class _StartCodeCard extends StatelessWidget {
  const _StartCodeCard({required this.startCode});

  final String startCode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final borderColor = isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFE9EAF0);
    final primaryTextColor = isDark ? Colors.white : AppColors.slate900;
    final mutedTextColor = isDark ? Colors.white : const Color(0xFF6E7191);

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: borderColor),
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primaryGreen.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.pin_outlined,
                  color: AppColors.primaryGreen,
                  size: 24,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ride Start Code',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: primaryTextColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Share this code with the driver to start the trip.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: mutedTextColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.md,
            ),
            decoration: BoxDecoration(
              color: AppColors.primaryGreen.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border.all(
                color: AppColors.primaryGreen.withValues(alpha: 0.3),
              ),
            ),
            child: Center(
              child: Text(
                startCode,
                style: theme.textTheme.headlineLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: AppColors.primaryGreen,
                  letterSpacing: 8,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Helpers ──────────────────────────────────────────────────────────────────

String _statusLabel(String status) {
  return switch (status) {
    'requested' => 'Requested',
    'bidding' => 'Bidding',
    'driverEnRoute' => 'Driver en route',
    'rideStarted' => 'Ride started',
    'completed' => 'Completed',
    'cancelled' => 'Cancelled',
    _ => status,
  };
}

String _rideTypeAsset(String rideType) {
  final cleaned = rideType.trim().toLowerCase();
  return switch (cleaned) {
    'comfort' => 'lib/assets/ride_options/comfort.png',
    'luxury' => 'lib/assets/ride_options/luxury.png',
    'courier' => 'lib/assets/ride_options/courier.png',
    _ => 'lib/assets/ride_options/regular.png',
  };
}
