import 'dart:async';

import 'package:caride/core/driver/models/driver_presence.dart';
import 'package:caride/core/driver/models/ride_model.dart';
import 'package:caride/core/driver/notifications/driver_alert_controller.dart';
import 'package:caride/core/driver/services/driver_floating_overlay_service.dart';
import 'package:caride/core/driver/utils/distance_helper.dart';
import 'package:caride/core/notifications/pending_notification_intent_service.dart';
import 'package:caride/features/driver/chat/data/driver_chat_repository.dart';
import 'package:caride/features/driver/location/data/driver_presence_repository.dart';
import 'package:caride/features/driver/ride/data/driver_ride_repository.dart';
import 'package:caride/features/driver/widgets/incoming_ride_alert_modal.dart';
import 'package:flutter/material.dart';
import 'package:navigation/navigation.dart';
import 'package:shared_widgets/shared_widgets.dart';

class DriverMainShell extends StatefulWidget {
  const DriverMainShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  State<DriverMainShell> createState() => _DriverMainShellState();
}

class _DriverMainShellState extends State<DriverMainShell>
    with WidgetsBindingObserver {
  final DriverChatRepository _chatRepo = DriverChatRepository();
  final DriverPresenceRepository _presenceRepo = DriverPresenceRepository();
  final DriverRideRepository _rideRepo = DriverRideRepository();

  StreamSubscription<void>? _overlayTapSub;
  StreamSubscription<DriverPresence?>? _presenceSub;
  StreamSubscription<List<RideModel>>? _ridesSub;
  StreamSubscription<RideModel?>? _assignedRideSub;

  AppLifecycleState _lifecycleState =
      WidgetsBinding.instance.lifecycleState ?? AppLifecycleState.resumed;
  int _lastOfferCount = 0;
  String? _lastOverlayRideId;
  bool _showingOfferDialog = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(DriverAlertController.instance.initialize());
    DriverAlertController.instance.activeForegroundOffer.addListener(
      _onActiveForegroundOfferChanged,
    );

    _overlayTapSub = DriverFloatingOverlayService.instance.onOverlayTapped
        .listen((_) {
          if (!mounted) return;
          if (PendingNotificationIntentService.instance.hasPending) return;
          widget.navigationShell.goBranch(2);
        });
    _checkPendingOverlayTap();
    _listenForAssignedRide();
    _listenForRideOffers();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycleState = state;
    if (state == AppLifecycleState.resumed && _lastOfferCount > 0) {
      _lastOfferCount = 0;
      _lastOverlayRideId = null;
      unawaited(DriverFloatingOverlayService.instance.clearRideOffer());
    }
  }

  void _onActiveForegroundOfferChanged() {
    if (!mounted) return;
    final offer = DriverAlertController.instance.activeForegroundOffer.value;

    if (offer == null) {
      if (_showingOfferDialog) {
        Navigator.of(context, rootNavigator: true).maybePop();
      }
      return;
    }

    if (_showingOfferDialog || _lifecycleState != AppLifecycleState.resumed) {
      return;
    }

    final currentPath = GoRouter.of(
      context,
    ).routeInformationProvider.value.uri.path;
    if (currentPath == DriverRoutePaths.requestDetail) {
      return;
    }

    _showingOfferDialog = true;
    IncomingRideAlertModal.show(
      context,
      initialRide: offer,
      distanceKm: DriverAlertController.instance.activeOfferDistanceKm.value,
    ).whenComplete(() {
      _showingOfferDialog = false;
    });
  }

  void _listenForAssignedRide() {
    _assignedRideSub?.cancel();
    _assignedRideSub = _rideRepo.streamAssignedRide().listen((assignedRide) {
      if (assignedRide != null) {
        DriverAlertController.instance.stopAlert();
        if (_lastOfferCount > 0) {
          _lastOfferCount = 0;
          _lastOverlayRideId = null;
          unawaited(DriverFloatingOverlayService.instance.clearRideOffer());
        }
      }
    });
  }

  void _listenForRideOffers() {
    _presenceSub = _presenceRepo.streamPresence().listen((presence) {
      _ridesSub?.cancel();
      final isOnline = presence != null && presence.isAvailableForRequests;
      DriverAlertController.instance.setDriverOnline(isOnline);

      if (!isOnline) {
        if (_lastOfferCount > 0) {
          _lastOfferCount = 0;
          _lastOverlayRideId = null;
          unawaited(DriverFloatingOverlayService.instance.clearRideOffer());
        }
        return;
      }

      _ridesSub = _rideRepo
          .streamAvailableRides(
            enabled: presence.isAvailableForRequests,
            vehicleType: presence.vehicleType,
            driverLat: presence.latitude,
            driverLng: presence.longitude,
          )
          .listen((rides) {
            DriverAlertController.instance.onRidesUpdated(
              rides,
              driverLat: presence.latitude,
              driverLng: presence.longitude,
              isOnline: presence.isAvailableForRequests,
            );

            if (_lifecycleState == AppLifecycleState.resumed) {
              if (_lastOfferCount > 0) {
                _lastOfferCount = 0;
                _lastOverlayRideId = null;
                unawaited(
                  DriverFloatingOverlayService.instance.clearRideOffer(),
                );
              }
              return;
            }

            final now = DateTime.now();
            final openRides = rides.where((r) {
              final isOpen =
                  r.status == 'searching' ||
                  r.status == 'requested' ||
                  r.status == 'bidding';
              final notExpired =
                  r.expiresAt == null || r.expiresAt!.isAfter(now);
              return isOpen &&
                  notExpired &&
                  !DriverAlertController.instance.isRideDeclined(r.id);
            }).toList();

            final count = openRides.length;
            if (count > 0) {
              final topRide = openRides.first;
              if (count != _lastOfferCount ||
                  topRide.id != _lastOverlayRideId) {
                _lastOfferCount = count;
                _lastOverlayRideId = topRide.id;

                String? distanceText;
                if (presence.latitude != null &&
                    presence.longitude != null &&
                    topRide.pickupLat != null &&
                    topRide.pickupLng != null) {
                  final km = calculateDistance(
                    presence.latitude!,
                    presence.longitude!,
                    topRide.pickupLat!,
                    topRide.pickupLng!,
                  );
                  distanceText = km.toStringAsFixed(1);
                }

                int? remainingMs;
                if (topRide.expiresAt != null) {
                  remainingMs = topRide.expiresAt!
                      .difference(now)
                      .inMilliseconds
                      .clamp(5000, 45000);
                }

                unawaited(
                  DriverFloatingOverlayService.instance.notifyRideOffer(
                    title: count == 1
                        ? 'New ${topRide.rideType} Ride • ₦${topRide.customerOffer.toStringAsFixed(0)}'
                        : '$count Ride Offers Available',
                    count: count,
                    rideId: topRide.id,
                    pickupLabel: topRide.pickupLabel,
                    dropoffLabel: topRide.dropoffLabel,
                    distanceKm: distanceText,
                    paymentMethod: topRide.paymentMethod,
                    remainingMs: remainingMs,
                  ),
                );
              }
            } else if (_lastOfferCount > 0) {
              _lastOfferCount = 0;
              _lastOverlayRideId = null;
              unawaited(DriverFloatingOverlayService.instance.clearRideOffer());
            }
          });
    });
  }

  Future<void> _checkPendingOverlayTap() async {
    final pending = await DriverFloatingOverlayService.instance
        .consumePendingOpenRequests();
    if (pending && mounted) {
      if (PendingNotificationIntentService.instance.hasPending) return;
      widget.navigationShell.goBranch(2);
    }
  }

  @override
  void dispose() {
    DriverAlertController.instance.activeForegroundOffer.removeListener(
      _onActiveForegroundOfferChanged,
    );
    WidgetsBinding.instance.removeObserver(this);
    _overlayTapSub?.cancel();
    _presenceSub?.cancel();
    _ridesSub?.cancel();
    _assignedRideSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: _chatRepo.watchTotalUnreadCount(),
      builder: (context, snapshot) {
        final unreadCount = snapshot.data ?? 0;

        return AppScaffold(
          body: widget.navigationShell,
          extendBody: true,
          bottomNavigationBar: GlassBottomNav(
            currentIndex: widget.navigationShell.currentIndex,
            onTap: (index) => widget.navigationShell.goBranch(
              index,
              initialLocation: index == widget.navigationShell.currentIndex,
            ),
            items: [
              const GlassNavItem(
                icon: Icons.local_taxi_outlined,
                activeIcon: Icons.local_taxi,
                label: 'Drive',
              ),
              const GlassNavItem(
                icon: Icons.receipt_long_outlined,
                activeIcon: Icons.receipt_long,
                label: 'Rides',
              ),
              const GlassNavItem(
                icon: Icons.monetization_on_outlined,
                activeIcon: Icons.monetization_on,
                label: 'Requests',
              ),
              GlassNavItem(
                icon: Icons.chat_bubble_outline_rounded,
                activeIcon: Icons.chat_bubble_rounded,
                label: 'Chat',
                badge: unreadCount > 0 ? unreadCount : null,
              ),
              const GlassNavItem(
                icon: Icons.person_outline,
                activeIcon: Icons.person,
                label: 'Profile',
              ),
            ],
          ),
        );
      },
    );
  }
}
