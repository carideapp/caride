import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'driver_route_delegates.dart';
import 'driver_route_paths.dart';

class DriverRouterBundle {
  const DriverRouterBundle({
    required this.router,
    required this.rootNavigatorKey,
  });

  final GoRouter router;
  final GlobalKey<NavigatorState> rootNavigatorKey;
}

DriverRouterBundle createDriverRouter({
  required DriverRouteDelegates d,
  String initialLocation = DriverRoutePaths.splash,
  List<NavigatorObserver>? observers,
  Listenable? refreshListenable,
  String? Function(BuildContext, GoRouterState)? redirect,
}) {
  final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'driver_root');

  final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: initialLocation,
    observers: observers ?? const [],
    refreshListenable: refreshListenable,
    redirect: redirect,
    routes: <RouteBase>[
      GoRoute(
        path: DriverRoutePaths.splash,
        builder: (context, state) => d.splash(context),
      ),
      GoRoute(
        path: DriverRoutePaths.getStarted,
        builder: (context, state) => d.getStarted(context),
      ),
      GoRoute(
        path: DriverRoutePaths.login,
        builder: (context, state) => d.login(context),
      ),
      GoRoute(
        path: DriverRoutePaths.signup,
        builder: (context, state) => d.signup(context),
      ),
      GoRoute(
        path: DriverRoutePaths.otp,
        builder: (context, state) => d.otp(context),
      ),
      GoRoute(
        path: DriverRoutePaths.registerSuccess,
        builder: (context, state) => d.registerSuccess(context),
      ),
      GoRoute(
        path: DriverRoutePaths.forgotPassword,
        builder: (context, state) => d.forgotPassword(context),
      ),
      GoRoute(
        path: DriverRoutePaths.onboarding,
        builder: (context, state) => d.onboarding(context),
      ),
      GoRoute(
        path: DriverRoutePaths.pendingApproval,
        builder: (context, state) => d.pendingApproval(context),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return d.mainShell(context, navigationShell);
        },
        branches: <StatefulShellBranch>[
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: DriverRoutePaths.home,
                builder: (context, state) => d.home(context),
              ),
              GoRoute(
                path: DriverRoutePaths.notifications,
                builder: (context, state) => d.notifications(context),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: DriverRoutePaths.rides,
                builder: (context, state) => d.rides(context),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: DriverRoutePaths.wallet,
                builder: (context, state) => d.wallet(context),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: DriverRoutePaths.chat,
                builder: (context, state) => d.chat(context),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: DriverRoutePaths.profile,
                builder: (context, state) => d.profile(context),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: DriverRoutePaths.conversation,
        builder: (context, state) => d.conversation(
          context,
          state.extra is Map<String, dynamic>
              ? state.extra as Map<String, dynamic>
              : null,
        ),
      ),
      GoRoute(
        path: DriverRoutePaths.rideDetail,
        builder: (context, state) => d.rideDetail(
          context,
          state.extra is String ? state.extra as String : null,
        ),
      ),
      GoRoute(
        path: DriverRoutePaths.wallet,
        builder: (context, state) => d.wallet(context),
      ),
      GoRoute(
        path: DriverRoutePaths.walletBankAccount,
        builder: (context, state) => d.walletBankAccount(context),
      ),
      GoRoute(
        path: DriverRoutePaths.profileHistory,
        builder: (context, state) => d.profileHistory(context),
      ),
      GoRoute(
        path: DriverRoutePaths.profileRatings,
        builder: (context, state) => d.profileRatings(context),
      ),
      GoRoute(
        path: DriverRoutePaths.profileDetail,
        builder: (context, state) => d.profileDetail(context),
      ),
      GoRoute(
        path: DriverRoutePaths.profileDocuments,
        builder: (context, state) => d.profileDocuments(context),
      ),
      GoRoute(
        path: DriverRoutePaths.profileVehicle,
        builder: (context, state) => d.profileVehicle(context),
      ),
      GoRoute(
        path: DriverRoutePaths.accountSecurity,
        builder: (context, state) => (d.accountSecurity ?? (_) => const SizedBox.shrink())(context),
      ),
      GoRoute(
        path: DriverRoutePaths.helpFaq,
        builder: (context, state) => d.helpFaq(context),
      ),
      GoRoute(
        path: DriverRoutePaths.privacyPolicy,
        builder: (context, state) => d.privacyPolicy(context),
      ),
      GoRoute(
        path: DriverRoutePaths.aboutApp,
        builder: (context, state) => d.aboutApp(context),
      ),
      GoRoute(
        path: DriverRoutePaths.requestDetail,
        builder: (context, state) => d.requestDetail(context),
      ),
      GoRoute(
        path: DriverRoutePaths.tripPickup,
        builder: (context, state) => d.tripPickup(context),
      ),
      GoRoute(
        path: DriverRoutePaths.tripActive,
        builder: (context, state) => d.tripActive(context),
      ),
      GoRoute(
        path: DriverRoutePaths.tripComplete,
        builder: (context, state) => d.tripComplete(context),
      ),
      GoRoute(
        path: DriverRoutePaths.rateCustomer,
        builder: (context, state) => d.rateCustomer(context),
      ),
      GoRoute(
        path: DriverRoutePaths.documentUpload,
        builder: (context, state) {
          final title = state.uri.queryParameters['title'] ?? 'Document';
          final documentType = state.uri.queryParameters['type'];
          return d.documentUpload(context, title, documentType);
        },
      ),
      GoRoute(
        path: DriverRoutePaths.profileBasicInfo,
        builder: (context, state) => d.profileBasicInfo(context),
      ),
      GoRoute(
        path: DriverRoutePaths.profilePicture,
        builder: (context, state) => d.profilePicture(context),
      ),
      GoRoute(
        path: DriverRoutePaths.helpSupport,
        builder: (context, state) => d.helpSupport(context),
      ),
      GoRoute(
        path: DriverRoutePaths.vehicleInfo,
        builder: (context, state) => d.vehicleInfo(context),
      ),
      GoRoute(
        path: DriverRoutePaths.profileTiers,
        builder: (context, state) => d.profileTiers(context),
      ),
      GoRoute(
        path: DriverRoutePaths.referral,
        builder: (context, state) => d.referral(context),
      ),
      if (d.linkedFleets != null)
        GoRoute(
          path: DriverRoutePaths.linkedFleets,
          builder: (context, state) => d.linkedFleets!(context),
        ),
      if (d.fleetProfileView != null)
        GoRoute(
          path: DriverRoutePaths.fleetProfileView,
          builder: (context, state) => d.fleetProfileView!(context, state.extra),
        ),
      if (d.rentalBookings != null)
        GoRoute(
          path: DriverRoutePaths.rentalBookings,
          builder: (context, state) => d.rentalBookings!(context),
        ),
      if (d.rentalTrip != null)
        GoRoute(
          path: DriverRoutePaths.rentalTrip,
          builder: (context, state) => d.rentalTrip!(context, state.extra),
        ),
    ],
  );

  return DriverRouterBundle(
    router: router,
    rootNavigatorKey: rootNavigatorKey,
  );
}
