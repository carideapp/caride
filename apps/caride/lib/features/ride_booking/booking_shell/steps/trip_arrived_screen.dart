import 'dart:async';
import 'package:caride/core/utils/phone_launcher.dart';
import 'package:caride/features/chat/conversation_screen.dart';
import 'package:caride/features/profile/data/driver_public_profile_repository.dart';
import 'package:caride/features/ride_booking/data/ride_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:caride/features/ride_booking/booking_shell/widgets/pickup_code_card.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';

/// Uber / inDrive inspired Arrival Screen component displayed in Step 5 when driver has arrived.
class TripArrivedScreen extends StatefulWidget {
  const TripArrivedScreen({
    super.key,
    required this.ride,
    required this.rideId,
    required this.unreadCount,
  });

  final RideModel ride;
  final String rideId;
  final int unreadCount;

  @override
  State<TripArrivedScreen> createState() => _TripArrivedScreenState();
}

class _TripArrivedScreenState extends State<TripArrivedScreen> {
  Stream<DriverPublicProfile?>? _driverProfStream;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _vehicleSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _reviewSub;

  String? _color;
  String? _make;
  String? _model;
  String? _plateNumber;

  @override
  void initState() {
    super.initState();
    final driverUid = widget.ride.driverUid ?? '';
    if (driverUid.isNotEmpty) {
      _driverProfStream = DriverPublicProfileRepository().watchDriver(driverUid);
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
          setState(() {
            _color = (data['color'] as String?)?.trim() ?? _color;
            _make = (data['make'] as String?)?.trim() ?? _make;
            _model = (data['model'] as String?)?.trim() ?? _model;
            _plateNumber = (data['plateNumber'] as String?)?.trim() ?? (data['licensePlate'] as String?)?.trim() ?? _plateNumber;
          });
        }
      });

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
            setState(() {
              _color ??= (newVals['color'] as String?)?.trim();
              _make ??= (newVals['make'] as String?)?.trim();
              _model ??= (newVals['model'] as String?)?.trim();
              _plateNumber ??= (newVals['plateNumber'] as String?)?.trim() ?? (newVals['licensePlate'] as String?)?.trim();
            });
          }
        }
      });
    }
  }

  @override
  void dispose() {
    _vehicleSub?.cancel();
    _reviewSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final driverUid = widget.ride.driverUid ?? '';
    final code = widget.ride.startCode ?? widget.ride.deliveryPin ?? (widget.ride.id.replaceAll(RegExp(r'\D'), '').padLeft(4, '0').substring(0, 4));

    return StreamBuilder<DriverPublicProfile?>(
      stream: _driverProfStream,
      builder: (context, profSnap) {
        final profile = profSnap.data;
        final driverName = (profile?.fullName.trim().isNotEmpty ?? false)
            ? profile!.fullName
            : (widget.ride.driverName?.trim().isNotEmpty ?? false)
                ? widget.ride.driverName!
                : 'Driver';
        final photoUrl = profile?.profilePhotoUrl ?? '';

        final vehicleDesc = [
          if (_color != null && _color!.isNotEmpty) _color,
          if (_make != null && _make!.isNotEmpty) _make,
          if (_model != null && _model!.isNotEmpty) _model,
        ].join(' ');

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 4),

              // Title
              Text(
                'Your driver has arrived!',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: isDark ? Colors.white : AppColors.slate900,
                  fontSize: 24,
                  letterSpacing: -0.6,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Please meet your driver at the pickup location.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: isDark ? Colors.grey[400] : const Color(0xFF6E7191),
                  fontWeight: FontWeight.w500,
                ),
              ),

              const SizedBox(height: 16),

              // Green Pickup Code Card
              PickupCodeCard(code: code),

              const SizedBox(height: 18),

              // Driver & Vehicle Card
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
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
                          radius: 32,
                          backgroundColor: isDark ? const Color(0xFF2E2E2E) : const Color(0xFFF1F5F9),
                          backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                          child: photoUrl.isEmpty
                              ? Icon(
                                  Icons.person_rounded,
                                  size: 32,
                                  color: isDark ? Colors.white30 : Colors.black26,
                                )
                              : null,
                        ),
                      ),
                      Positioned(
                        right: -2,
                        bottom: -1,
                        child: Container(
                          padding: const EdgeInsets.all(1.5),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.verified_rounded,
                            size: 16,
                            color: Color(0xFFFFB100),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 14),

                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_plateNumber != null && _plateNumber!.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
                                fontSize: 12,
                              ),
                            ),
                          ),
                        const SizedBox(height: 4),
                        Text(
                          vehicleDesc.isNotEmpty ? vehicleDesc : 'Vehicle info loading...',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : AppColors.slate900,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          driverName,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: isDark ? Colors.white60 : Colors.grey[600],
                            fontWeight: FontWeight.w500,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Action Buttons (Chat & Call)
              Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context, rootNavigator: true).push(
                            MaterialPageRoute(
                              builder: (_) => ConversationScreen(
                                driverName: driverName,
                                rideId: widget.rideId,
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
                            borderRadius: BorderRadius.circular(25),
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
                                fontSize: 14,
                              ),
                            ),
                            if (widget.unreadCount > 0) ...[
                              const Spacer(),
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Color(0xFFDC2626),
                                  shape: BoxShape.circle,
                                ),
                                constraints: const BoxConstraints(
                                  minWidth: 20,
                                  minHeight: 20,
                                ),
                                child: Center(
                                  child: Text(
                                    '${widget.unreadCount}',
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
                  SizedBox(
                    width: 50,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: (profile?.phone.trim().isNotEmpty ?? false)
                          ? () async {
                              final ok = await PhoneLauncher.call(profile!.phone);
                              if (!context.mounted) return;
                              if (!ok) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Unable to place call.')),
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
