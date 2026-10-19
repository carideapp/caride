import 'package:caride/core/auth/customer_auth_controller.dart';
import 'package:caride/features/chat/data/chat_repository.dart';
import 'package:caride/features/fleet_manager/presentation/widgets/fleet_bottom_nav.dart';
import 'package:flutter/material.dart';
import 'package:navigation/navigation.dart';
import 'package:shared_widgets/shared_widgets.dart';

/// Main Navigation Shell with Glass Bottom Navigation and live unread chat badge.
class CustomerMainShell extends StatelessWidget {
  CustomerMainShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;
  final ChatRepository _chatRepo = ChatRepository();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: customerAuthController,
      builder: (context, _) {
        final isFleet = customerAuthController.activeRole == 'fleet';
        if (isFleet) {
          int fleetIndex = 0;
          if (navigationShell.currentIndex == 1) {
            fleetIndex = 1; // Bookings / Rental
          } else if (navigationShell.currentIndex == 2) {
            fleetIndex = 2; // Chat
          } else if (navigationShell.currentIndex == 3) {
            fleetIndex = 1; // Bookings / Activity
          } else if (navigationShell.currentIndex == 4) {
            fleetIndex = 4; // Profile
          }

          return AppScaffold(
            body: navigationShell,
            extendBody: true,
            bottomNavigationBar: FleetBottomNav(currentIndex: fleetIndex),
          );
        }

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
                    icon: Icons.home_outlined,
                    activeIcon: Icons.home_rounded,
                    label: 'Home',
                  ),
                  const GlassNavItem(
                    icon: Icons.car_rental_outlined,
                    activeIcon: Icons.car_rental_rounded,
                    label: 'Rental',
                  ),
                  GlassNavItem(
                    icon: Icons.chat_bubble_outline_rounded,
                    activeIcon: Icons.chat_bubble_rounded,
                    label: 'Chat',
                    badge: unreadCount > 0 ? unreadCount : null,
                  ),
                  const GlassNavItem(
                    icon: Icons.receipt_long_outlined,
                    activeIcon: Icons.receipt_long_rounded,
                    label: 'Activity',
                  ),
                  const GlassNavItem(
                    icon: Icons.person_outline_rounded,
                    activeIcon: Icons.person_rounded,
                    label: 'Account',
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

