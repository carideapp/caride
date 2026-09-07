import 'dart:async';
import 'package:caride/core/utils/phone_launcher.dart';
import 'package:caride/features/chat/conversation_screen.dart';
import 'package:caride/features/chat/data/chat_repository.dart';
import 'package:caride/features/profile/data/driver_public_profile_repository.dart';
import 'package:caride/features/ride_booking/booking_shell/booking_shell_controller.dart';
import 'package:caride/features/ride_booking/booking_shell/steps/trip_arrived_screen.dart';
import 'package:caride/features/ride_booking/booking_shell/widgets/booking_end_state.dart';
import 'package:caride/features/ride_booking/data/arrival_calculator.dart';
import 'package:caride/features/ride_booking/data/ride_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:caride/features/profile/rate_driver_screen.dart';
import 'package:caride/features/ride_booking/booking_shell/widgets/pickup_code_card.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_widgets/shared_widgets.dart';

/// Live Ride Tracking Step (Step 5) styled exactly like the provided mock UI.
class TrackingStep extends StatefulWidget {
  const TrackingStep({super.key, required this.controller});

  final BookingShellController controller;

  @override
  State<TrackingStep> createState() => _TrackingStepState();
}

class _TrackingStepState extends State<TrackingStep> {
  Stream<DriverPublicProfile?>? _driverProfStream;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _presenceSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _vehicleSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _reviewSub;
  StreamSubscription<int>? _unreadSub;

  final ChatRepository _chatRepo = ChatRepository();
  final ArrivalCalculator _arrivalCalculator = ArrivalCalculator();
  String _etaText = 'Calculating...';
  String? _cachedDriverUid;
  int _unreadCount = 0;
  int _lastUnreadCount = 0;
  bool _hasPromptedRate = false;

  // Vehicle info fields
  String? _color;
  String? _make;
  String? _model;
  String? _plateNumber;

  void _updateStreams(String driverUid, RideModel ride) {
    if (_cachedDriverUid != driverUid || _vehicleSub == null) {
      _cachedDriverUid = driverUid;

      // Watch driver profile (profilePhotoUrl, fullName, phone)
      _driverProfStream = driverUid.isEmpty
          ? Stream<DriverPublicProfile?>.value(null)
          : DriverPublicProfileRepository().watchDriver(driverUid);

      // Watch driver presence for live distance and ETA
      _presenceSub?.cancel();
      _presenceSub = null;
      if (driverUid.isNotEmpty) {
        _presenceSub = FirebaseFirestore.instance
            .collection('driverPresence')
            .doc(driverUid)
            .snapshots()
            .listen((doc) {
          if (!mounted) return;
          final data = doc.data();
          if (data != null) {
            final GeoPoint? lastLoc = data['lastLocation'] as GeoPoint?;

            if (lastLoc != null) {
              final isTripInProgress = ride.status == 'inProgress' ||
                  ride.status == 'tripStarted' ||
                  ride.status == 'rideStarted';
              final destLat = isTripInProgress
                  ? (ride.dropoffLat ?? ride.pickupLat ?? 7.0581922)
                  : (ride.pickupLat ?? 7.0581922);
              final destLng = isTripInProgress
                  ? (ride.dropoffLng ?? ride.pickupLng ?? 6.2855659)
                  : (ride.pickupLng ?? 6.2855659);

              // Use ArrivalCalculator for accurate Google Maps-based ETA
              _arrivalCalculator
                  .calculateEta(
                    driverLat: lastLoc.latitude,
                    driverLng: lastLoc.longitude,
                    destinationLat: destLat,
                    destinationLng: destLng,
                    isToPickup: !isTripInProgress,
                  )
                  .then((eta) {
                if (!mounted) return;
                setState(() => _etaText = eta);
              });
            }
          }
        });
      }

      // Watch vehicle info (color, make, model, plateNumber)
      _vehicleSub?.cancel();
      _vehicleSub = null;
      _reviewSub?.cancel();
      _reviewSub = null;
      _color = null;
      _make = null;
      _model = null;
      _plateNumber = null;

      if (driverUid.isNotEmpty) {
        _vehicleSub = FirebaseFirestore.instance
            .collection('drivers')
            .doc(driverUid)
            .collection('vehicle')
            .doc('info')
            .snapshots()
            .listen((doc) {
          if (!mounted) return;
          final data = doc.data();
          if (data != null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              setState(() {
                _color = (data['color'] as String?)?.trim() ?? _color;
                _make = (data['make'] as String?)?.trim() ?? _make;
                _model = (data['model'] as String?)?.trim() ?? _model;
                _plateNumber = (data['plateNumber'] as String?)?.trim() ?? (data['licensePlate'] as String?)?.trim() ?? _plateNumber;
              });
            });
          }
        });

        // Fallback listener for vehicle/review
        _reviewSub = FirebaseFirestore.instance
            .collection('drivers')
            .doc(driverUid)
            .collection('vehicle')
            .doc('review')
            .snapshots()
            .listen((doc) {
          if (!mounted) return;
          final data = doc.data();
          if (data != null) {
            final newVals = data['newValues'] as Map<String, dynamic>?;
            if (newVals != null) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                setState(() {
                  _color ??= (newVals['color'] as String?)?.trim();
                  _make ??= (newVals['make'] as String?)?.trim();
                  _model ??= (newVals['model'] as String?)?.trim();
                  _plateNumber ??= (newVals['plateNumber'] as String?)?.trim() ?? (newVals['licensePlate'] as String?)?.trim();
                });
              });
            }
          }
        });
      }
    }
  }

  void _listenUnreadCount(String rideId) {
    if (rideId.isEmpty) return;
    _unreadSub?.cancel();
    _unreadSub = _chatRepo.watchUnreadCountForRide(rideId).listen((unreadVal) {
      if (!mounted) return;
      if (unreadVal > _lastUnreadCount) {
        SystemSound.play(SystemSoundType.alert);
        HapticFeedback.vibrate();
      }
      _lastUnreadCount = unreadVal;
      setState(() => _unreadCount = unreadVal);
    });
  }

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
    final rideId = widget.controller.rideId;
    if (rideId != null && rideId.isNotEmpty) {
      _listenUnreadCount(rideId);
    }
  }

  void _onControllerChanged() {
    final rideId = widget.controller.rideId;
    if (rideId != null && rideId.isNotEmpty && _unreadSub == null) {
      _listenUnreadCount(rideId);
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    _presenceSub?.cancel();
    _vehicleSub?.cancel();
    _reviewSub?.cancel();
    _unreadSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final ride = widget.controller.ride;
    final rideId = widget.controller.rideId;
    if (rideId == null) {
      return const Center(child: Text('No ride yet.'));
    }
    if (ride == null) {
      return const Center(child: AppLoader());
    }
    if (ride.status == 'cancelled' || ride.status == 'completed') {
      if (ride.status == 'completed' && !_hasPromptedRate) {
        _hasPromptedRate = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          Navigator.of(context, rootNavigator: true).push(
            MaterialPageRoute(
              builder: (_) => RateDriverScreen(rideId: rideId),
            ),
          );
        });
      }
      return BookingEndState(
        status: ride.status,
        pickupLabel: ride.pickupLabel,
        dropoffLabel: ride.dropoffLabel,
      );
    }

    final driverUid = ride.driverUid ?? '';
    _updateStreams(driverUid, ride);

    if (ride.status == 'driverArrived') {
      return TripArrivedScreen(
        ride: ride,
        rideId: rideId,
        unreadCount: _unreadCount,
      );
    }

    final code = ride.startCode ?? ride.deliveryPin ?? (ride.id.replaceAll(RegExp(r'\D'), '').padLeft(4, '0').substring(0, 4));

    return StreamBuilder<DriverPublicProfile?>(
          stream: _driverProfStream,
          builder: (context, profSnap) {
            final profile = profSnap.data;
            final driverName = (profile?.fullName.trim().isNotEmpty ?? false)
                ? profile!.fullName
                : (ride.driverName?.trim().isNotEmpty ?? false)
                    ? ride.driverName!
                    : 'Driver';

            final photoUrl = profile?.profilePhotoUrl ?? '';

            // Formatting Make + Model + Color
            final vehicleDesc = [
              if (_color != null && _color!.isNotEmpty) _color,
              if (_make != null && _make!.isNotEmpty) _make,
              if (_model != null && _model!.isNotEmpty) _model,
            ].join(' ');

            final isTripStarted = ride.status == 'inProgress' ||
                ride.status == 'tripStarted' ||
                ride.status == 'rideStarted';

            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 8),
                // 1. Dynamic ETA / Driver Status Title
                Text(
                  isTripStarted ? 'Heading to your Destination' : _etaText,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : AppColors.slate900,
                    fontSize: isTripStarted ? 20 : 22,
                    letterSpacing: -0.6,
                  ),
                ),
                if (isTripStarted) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Estimated arrival: $_etaText',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.primaryGreen,
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                ],

                const SizedBox(height: 16),

                // 2. Driver Detail Row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Driver photo with verification checkmark badge
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isDark ? Colors.white24 : Colors.black12,
                              width: 1.0,
                            ),
                          ),
                          child: CircleAvatar(
                            radius: 36,
                            backgroundColor: isDark ? const Color(0xFF2E2E2E) : const Color(0xFFF1F5F9),
                            backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                            child: photoUrl.isEmpty
                                ? Icon(
                                    Icons.person_rounded,
                                    size: 36,
                                    color: isDark ? Colors.white30 : Colors.black26,
                                  )
                                : null,
                          ),
                        ),
                        // Verified gold badge
                        Positioned(
                          right: -3,
                          bottom: -1,
                          child: Container(
                            padding: const EdgeInsets.all(1.5),
                            decoration: const BoxDecoration(
                              color: Colors.white, // White border ring
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.verified_rounded,
                              size: 18,
                              color: Color(0xFFFFB100), // Premium gold/amber color
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 18),

                    // Plate, vehicle spec, and driver name
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Plate Number Badge
                          if (_plateNumber != null && _plateNumber!.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: isDark ? const Color(0xFF2E2E2E) : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.08),
                                  width: 0.8,
                                ),
                              ),
                              child: Text(
                                _plateNumber!,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  color: isDark ? Colors.white.withValues(alpha: 0.9) : AppColors.slate900,
                                  letterSpacing: 0.5,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          const SizedBox(height: 6),

                          // Color · Make Model
                          Text(
                            vehicleDesc.isNotEmpty ? vehicleDesc : 'Vehicle info loading...',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : AppColors.slate900,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 2),

                          // Driver Full Name
                          Text(
                            driverName,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: isDark ? Colors.white60 : Colors.grey[600],
                              fontWeight: FontWeight.w500,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                if (!isTripStarted) ...[
                  const SizedBox(height: 16),
                  // 3. Green Pickup Code Card
                  PickupCodeCard(code: code),
                ],

                const SizedBox(height: 16),

                // 4. Action Buttons Row (Chat with Driver and Phone Call)
                Row(
                  children: [
                    // Chat Button
                    Expanded(
                      child: SizedBox(
                        height: 52,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.of(context, rootNavigator: true).push(
                              MaterialPageRoute(
                                builder: (_) => ConversationScreen(
                                  driverName: driverName,
                                  rideId: rideId,
                                  driverUid: driverUid,
                                ),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isDark ? const Color(0xFF2E2E2E) : const Color(0xFFF1F5F9),
                            foregroundColor: isDark ? Colors.white : AppColors.slate900,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(26),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.chat_bubble_rounded,
                                size: 18,
                                color: isDark ? Colors.white70 : AppColors.slate900,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'Chat with driver',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                              if (_unreadCount > 0) ...[
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.all(5),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFDC2626), // Badge red
                                    shape: BoxShape.circle,
                                  ),
                                  constraints: const BoxConstraints(
                                    minWidth: 20,
                                    minHeight: 20,
                                  ),
                                  child: Center(
                                    child: Text(
                                      '$_unreadCount',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Phone Call Button
                    SizedBox(
                      width: 52,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: (profile?.phone.trim().isNotEmpty ?? false)
                            ? () async {
                                final ok = await PhoneLauncher.call(profile!.phone);
                                if (!context.mounted) return;
                                if (!ok) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Unable to place call.'),
                                    ),
                                  );
                                }
                              }
                            : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isDark ? const Color(0xFF2E2E2E) : const Color(0xFFF1F5F9),
                          foregroundColor: isDark ? Colors.white : AppColors.slate900,
                          elevation: 0,
                          shape: const CircleBorder(),
                          padding: EdgeInsets.zero,
                        ),
                        child: Icon(
                          Icons.call_rounded,
                          size: 20,
                          color: isDark ? Colors.white70 : AppColors.slate900,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      );
  }
}
