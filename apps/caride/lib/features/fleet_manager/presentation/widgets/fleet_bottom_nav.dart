import 'package:caride/features/chat/data/chat_repository.dart';
import 'package:flutter/material.dart';
import 'package:navigation/navigation.dart';
import 'package:shared_widgets/shared_widgets.dart';

/// Reusable Glass Bottom Navigation Bar for Fleet Manager Portal.
class FleetBottomNav extends StatelessWidget {
  FleetBottomNav({
    super.key,
    required this.currentIndex,
  });

  final int currentIndex;
  final ChatRepository _chatRepo = ChatRepository();

  void _onTap(BuildContext context, int index) {
    if (index == currentIndex) return;

    switch (index) {
      case 0:
        context.go(FleetRoutePaths.dashboard);
        break;
      case 1:
        context.go(FleetRoutePaths.bookings);
        break;
      case 2:
        context.go(FleetRoutePaths.chat);
        break;
      case 3:
        context.go(FleetRoutePaths.vehicles);
        break;
      case 4:
        context.go(FleetRoutePaths.profile);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: _chatRepo.watchTotalUnreadCount(),
      builder: (context, snapshot) {
        final unreadCount = snapshot.data ?? 0;

        return GlassBottomNav(
          currentIndex: currentIndex,
          onTap: (index) => _onTap(context, index),
          items: [
            const GlassNavItem(
              icon: Icons.home_outlined,
              activeIcon: Icons.home_rounded,
              label: 'Home',
            ),
            const GlassNavItem(
              icon: Icons.calendar_today_outlined,
              activeIcon: Icons.calendar_today_rounded,
              label: 'Bookings',
            ),
            GlassNavItem(
              icon: Icons.chat_bubble_outline_rounded,
              activeIcon: Icons.chat_bubble_rounded,
              label: 'Chat',
              badge: unreadCount > 0 ? unreadCount : null,
            ),
            const GlassNavItem(
              icon: Icons.directions_car_outlined,
              activeIcon: Icons.directions_car_rounded,
              label: 'Vehicle',
            ),
            const GlassNavItem(
              icon: Icons.person_outline_rounded,
              activeIcon: Icons.person_rounded,
              label: 'Profile',
            ),
          ],
        );
      },
    );
  }
}
