import 'package:caride/features/driver/chat/data/driver_chat_repository.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_widgets/shared_widgets.dart';

class DriverMainShell extends StatelessWidget {
  DriverMainShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;
  final DriverChatRepository _chatRepo = DriverChatRepository();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
      stream: _chatRepo.watchTotalUnreadCount(),
      builder: (context, snapshot) {
        final unreadCount = snapshot.data ?? 0;

        return AppScaffold(
          body: navigationShell,
          extendBody: true,
          bottomNavigationBar: GlassBottomNav(
            currentIndex: navigationShell.currentIndex,
            onTap: (index) => navigationShell.goBranch(
              index,
              initialLocation: index == navigationShell.currentIndex,
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
