import 'dart:async';

import 'package:caride/core/driver/models/driver_presence.dart';
import 'package:caride/core/driver/models/ride_model.dart';
import 'package:caride/core/driver/services/driver_floating_overlay_service.dart';
import 'package:caride/features/driver/chat/data/driver_chat_repository.dart';
import 'package:caride/features/driver/location/data/driver_presence_repository.dart';
import 'package:caride/features/driver/ride/data/driver_ride_repository.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_widgets/shared_widgets.dart';

class DriverMainShell extends StatefulWidget {
  const DriverMainShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  State<DriverMainShell> createState() => _DriverMainShellState();
}

class _DriverMainShellState extends State<DriverMainShell> {
  final DriverChatRepository _chatRepo = DriverChatRepository();
  final DriverPresenceRepository _presenceRepo = DriverPresenceRepository();
  final DriverRideRepository _rideRepo = DriverRideRepository();
  StreamSubscription<void>? _overlayTapSub;
  StreamSubscription<DriverPresence?>? _presenceSub;
  StreamSubscription<List<RideModel>>? _ridesSub;
  int _lastOfferCount = 0;

  @override
  void initState() {
    super.initState();
    _overlayTapSub = DriverFloatingOverlayService.instance.onOverlayTapped
        .listen((_) {
          if (mounted) {
            widget.navigationShell.goBranch(2);
          }
        });
    _checkPendingOverlayTap();
    _listenForRideOffers();
  }

  void _listenForRideOffers() {
    _presenceSub = _presenceRepo.streamPresence().listen((presence) {
      _ridesSub?.cancel();
      if (presence == null || !presence.isAvailableForRequests) {
        if (_lastOfferCount > 0) {
          _lastOfferCount = 0;
          DriverFloatingOverlayService.instance.clearRideOffer();
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
            final count = rides.length;
            if (count > 0 && count != _lastOfferCount) {
              _lastOfferCount = count;
              DriverFloatingOverlayService.instance.notifyRideOffer(
                title: count == 1 ? 'New Ride Offer' : '$count Ride Offers',
                count: count,
              );
            } else if (count == 0 && _lastOfferCount > 0) {
              _lastOfferCount = 0;
              DriverFloatingOverlayService.instance.clearRideOffer();
            }
          });
    });
  }

  Future<void> _checkPendingOverlayTap() async {
    final pending =
        await DriverFloatingOverlayService.instance.consumePendingOpenRequests();
    if (pending && mounted) {
      widget.navigationShell.goBranch(2);
    }
  }

  @override
  void dispose() {
    _overlayTapSub?.cancel();
    _presenceSub?.cancel();
    _ridesSub?.cancel();
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
