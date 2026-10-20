import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'customer_route_delegates.dart';
import 'customer_route_paths.dart';
import 'driver_route_paths.dart';
import 'fleet_route_paths.dart';

class CustomerRouterBundle {
  const CustomerRouterBundle({
    required this.router,
    required this.rootNavigatorKey,
  });

  final GoRouter router;
  final GlobalKey<NavigatorState> rootNavigatorKey;
}

/// Centralized customer [GoRouter]: auth stack routes + indexed main shell + full-screen ride flows.
CustomerRouterBundle createCustomerRouter({
  required CustomerRouteDelegates d,
  String initialLocation = CustomerRoutePaths.splash,
  List<NavigatorObserver>? observers,
  Listenable? refreshListenable,
  String? Function(BuildContext, GoRouterState)? redirect,
}) {
  final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'customer_root');

  final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: initialLocation,
    observers: observers ?? const [],
    refreshListenable: refreshListenable,
    redirect: redirect,
    routes: <RouteBase>[
      GoRoute(
        path: CustomerRoutePaths.splash,
        builder: (context, state) => d.splash(context),
      ),
      GoRoute(
        path: CustomerRoutePaths.onboarding,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => d.onboarding(context),
      ),
      GoRoute(
        path: CustomerRoutePaths.welcome,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => d.welcome(context),
      ),
      GoRoute(
        path: CustomerRoutePaths.login,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => d.login(context),
      ),
      GoRoute(
        path: CustomerRoutePaths.signup,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => d.signup(context),
      ),
      GoRoute(
        path: CustomerRoutePaths.otp,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => d.otp(context),
      ),
      GoRoute(
        path: CustomerRoutePaths.completeProfile,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => d.completeProfile(context),
      ),
      GoRoute(
        path: CustomerRoutePaths.forgotPassword,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => d.forgotPassword(context),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return d.mainShell(context, navigationShell);
        },
        branches: <StatefulShellBranch>[
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: CustomerRoutePaths.home,
                builder: (context, state) => d.home(context),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: CustomerRoutePaths.rentalBookings,
                builder: (context, state) => d.rentalBookings != null
                    ? d.rentalBookings!(context)
                    : (d.rentalBrowse != null
                        ? d.rentalBrowse!(context)
                        : const SizedBox.shrink()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: CustomerRoutePaths.chat,
                builder: (context, state) => d.chatOrWallet(context),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: CustomerRoutePaths.activity,
                builder: (context, state) => d.activity(context),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: <RouteBase>[
              GoRoute(
                path: CustomerRoutePaths.profile,
                builder: (context, state) => d.profile(context),
                routes: <RouteBase>[
                  GoRoute(
                    path: 'edit',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) => d.editProfile(context),
                  ),
                  GoRoute(
                    path: 'saved-addresses',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) => d.savedAddresses(context),
                    routes: [
                      GoRoute(
                        path: 'add',
                        parentNavigatorKey: rootNavigatorKey,
                        builder: (context, state) => d.addAddress(context),
                      ),
                      GoRoute(
                        path: 'edit',
                        parentNavigatorKey: rootNavigatorKey,
                        builder: (context, state) => d.editAddress(context),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'history',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) => d.rideHistory(context),
                  ),
                  GoRoute(
                    path: 'ratings',
                    builder: (context, state) => d.ratings(context),
                  ),
                  GoRoute(
                    path: 'top-up',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) => d.typeAmount(context),
                    routes: [
                      GoRoute(
                        path: 'payment',
                        parentNavigatorKey: rootNavigatorKey,
                        builder: (context, state) => d.paymentMethod(context, state.extra),
                      ),
                      GoRoute(
                        path: 'webview',
                        parentNavigatorKey: rootNavigatorKey,
                        builder: (context, state) => d.topUpWebview(context, state.extra),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'payment-methods',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) => d.viewPaymentMethods(context),
                    routes: [
                      GoRoute(
                        path: 'add',
                        parentNavigatorKey: rootNavigatorKey,
                        builder: (context, state) => d.addNewPayment(context),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'security',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) => d.accountSecurity(context),
                    routes: [
                      GoRoute(
                        path: 'device-management',
                        parentNavigatorKey: rootNavigatorKey,
                        builder: (context, state) => d.deviceManagement(context),
                      ),
                      GoRoute(
                        path: 'pin',
                        parentNavigatorKey: rootNavigatorKey,
                        builder: (context, state) => d.securityPin!(context),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'linked-accounts',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) => d.linkedAccounts(context),
                  ),
                  GoRoute(
                    path: 'data-analytics',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) => d.dataAnalytics(context),
                    routes: [
                      GoRoute(
                        path: 'data-usage',
                        parentNavigatorKey: rootNavigatorKey,
                        builder: (context, state) => d.dataUsage(context),
                      ),
                      GoRoute(
                        path: 'download-data',
                        parentNavigatorKey: rootNavigatorKey,
                        builder: (context, state) => d.downloadData(context),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'appearance',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) => d.appAppearance(context),
                    routes: [
                      GoRoute(
                        path: 'language',
                        parentNavigatorKey: rootNavigatorKey,
                        builder: (context, state) => d.appLanguage(context),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'referral',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) => d.referral(context),
                  ),
                  GoRoute(
                    path: 'help-support',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) => d.helpSupport(context),
                    routes: [
                      GoRoute(
                        path: 'chat',
                        parentNavigatorKey: rootNavigatorKey,
                        builder: (context, state) => d.supportChat(context),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'legal',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) => d.legal != null ? d.legal!(context) : const SizedBox.shrink(),
                    routes: [
                      GoRoute(
                        path: 'terms',
                        parentNavigatorKey: rootNavigatorKey,
                        builder: (context, state) => d.riderTerms != null ? d.riderTerms!(context) : const SizedBox.shrink(),
                      ),
                      GoRoute(
                        path: 'privacy',
                        parentNavigatorKey: rootNavigatorKey,
                        builder: (context, state) => d.riderPrivacy != null ? d.riderPrivacy!(context) : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'monitor-trip-entry',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) => d.monitorTripEntry(context),
                  ),
                  GoRoute(
                    path: 'monitor-trip',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) => d.monitorTrip(context, state.extra),
                  ),
                  GoRoute(
                    path: 'become-driver',
                    parentNavigatorKey: rootNavigatorKey,
                    builder: (context, state) => d.becomeDriver!(context),
                  ),
                  GoRoute(
                    path: 'wallet',
                    builder: (context, state) =>
                        d.wallet != null ? d.wallet!(context) : d.chatOrWallet(context),
                    routes: [
                      GoRoute(
                        path: 'withdraw',
                        parentNavigatorKey: rootNavigatorKey,
                        builder: (context, state) => d.withdraw!(context),
                        routes: [
                          GoRoute(
                            path: 'amount',
                            parentNavigatorKey: rootNavigatorKey,
                            builder: (context, state) => d.withdrawAmount!(context),
                          ),
                          GoRoute(
                            path: 'pin',
                            parentNavigatorKey: rootNavigatorKey,
                            builder: (context, state) => d.withdrawPin!(context),
                          ),
                          GoRoute(
                            path: 'success',
                            parentNavigatorKey: rootNavigatorKey,
                            builder: (context, state) => d.withdrawSuccess!(context),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: CustomerRoutePaths.walletFund,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => d.walletFund(context),
      ),
      GoRoute(
        path: CustomerRoutePaths.rideSetPrice,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => d.rideSetPrice(context, state.extra),
      ),
      if (d.sendItems != null)
        GoRoute(
          path: CustomerRoutePaths.sendItems,
          parentNavigatorKey: rootNavigatorKey,
          builder: (context, state) => d.sendItems!(context, state.extra),
        ),
      GoRoute(
        path: CustomerRoutePaths.rideOffers,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => d.rideOffers(context, state.extra),
      ),
      GoRoute(
        path: CustomerRoutePaths.rideTrack,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => d.rideTrack(context, state.extra),
      ),
      GoRoute(
        path: CustomerRoutePaths.selectDriver,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => d.selectDriver(context, state.extra),
      ),
      GoRoute(
        path: CustomerRoutePaths.driverTracking,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => d.driverTracking(context),
      ),
      GoRoute(
        path: CustomerRoutePaths.shareReceipt,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => d.shareReceipt(context),
      ),
      GoRoute(
        path: CustomerRoutePaths.roleSelector,
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => d.roleSelector(context),
      ),
      if (d.fleetLogin != null)
        GoRoute(
          path: FleetRoutePaths.login,
          parentNavigatorKey: rootNavigatorKey,
          builder: (context, state) => d.fleetLogin!(context),
        ),
      if (d.fleetSignup != null)
        GoRoute(
          path: FleetRoutePaths.signup,
          parentNavigatorKey: rootNavigatorKey,
          builder: (context, state) => d.fleetSignup!(context),
        ),
      if (d.fleetOtp != null)
        GoRoute(
          path: FleetRoutePaths.otp,
          parentNavigatorKey: rootNavigatorKey,
          builder: (context, state) => d.fleetOtp!(context),
        ),
      if (d.fleetRegisterSuccess != null)
        GoRoute(
          path: FleetRoutePaths.registerSuccess,
          parentNavigatorKey: rootNavigatorKey,
          builder: (context, state) => d.fleetRegisterSuccess!(context),
        ),
      if (d.fleetReviewStatus != null)
        GoRoute(
          path: FleetRoutePaths.reviewStatus,
          parentNavigatorKey: rootNavigatorKey,
          builder: (context, state) => d.fleetReviewStatus!(context),
        ),
      if (d.fleetForgotPassword != null)
        GoRoute(
          path: FleetRoutePaths.forgotPassword,
          parentNavigatorKey: rootNavigatorKey,
          builder: (context, state) => d.fleetForgotPassword!(context),
        ),
      if (d.fleetOnboarding != null)
        GoRoute(
          path: FleetRoutePaths.onboarding,
          parentNavigatorKey: rootNavigatorKey,
          builder: (context, state) => d.fleetOnboarding!(context),
        ),
      if (d.fleetDashboard != null)
        GoRoute(
          path: FleetRoutePaths.dashboard,
          parentNavigatorKey: rootNavigatorKey,
          builder: (context, state) => d.fleetDashboard!(context),
        ),
      if (d.fleetVehicles != null)
        GoRoute(
          path: FleetRoutePaths.vehicles,
          parentNavigatorKey: rootNavigatorKey,
          builder: (context, state) => d.fleetVehicles!(context),
        ),
      if (d.fleetAddVehicle != null)
        GoRoute(
          path: FleetRoutePaths.addVehicle,
          parentNavigatorKey: rootNavigatorKey,
          builder: (context, state) => d.fleetAddVehicle!(context),
        ),
      if (d.fleetEditVehicle != null)
        GoRoute(
          path: FleetRoutePaths.editVehicle,
          parentNavigatorKey: rootNavigatorKey,
          builder: (context, state) => d.fleetEditVehicle!(context, state.extra),
        ),
      if (d.fleetBookings != null)
        GoRoute(
          path: FleetRoutePaths.bookings,
          parentNavigatorKey: rootNavigatorKey,
          builder: (context, state) => d.fleetBookings!(context),
        ),
      if (d.fleetBookingDetail != null)
        GoRoute(
          path: FleetRoutePaths.bookingDetail,
          parentNavigatorKey: rootNavigatorKey,
          builder: (context, state) =>
              d.fleetBookingDetail!(context, state.extra),
        ),
      if (d.fleetDrivers != null)
        GoRoute(
          path: FleetRoutePaths.drivers,
          parentNavigatorKey: rootNavigatorKey,
          builder: (context, state) => d.fleetDrivers!(context),
        ),
      if (d.fleetProfile != null)
        GoRoute(
          path: FleetRoutePaths.profile,
          parentNavigatorKey: rootNavigatorKey,
          builder: (context, state) => d.fleetProfile!(context),
        ),
      if (d.fleetProfileDetails != null)
        GoRoute(
          path: FleetRoutePaths.profileDetails,
          parentNavigatorKey: rootNavigatorKey,
          builder: (context, state) => d.fleetProfileDetails!(context),
        ),
      if (d.fleetOperatingStates != null)
        GoRoute(
          path: FleetRoutePaths.operatingStates,
          parentNavigatorKey: rootNavigatorKey,
          builder: (context, state) => d.fleetOperatingStates!(context),
        ),
      if (d.fleetBusinessInfo != null)
        GoRoute(
          path: FleetRoutePaths.businessInfo,
          parentNavigatorKey: rootNavigatorKey,
          builder: (context, state) => d.fleetBusinessInfo!(context),
        ),
      if (d.fleetViewBusinessInfo != null)
        GoRoute(
          path: FleetRoutePaths.viewBusinessInfo,
          parentNavigatorKey: rootNavigatorKey,
          builder: (context, state) => d.fleetViewBusinessInfo!(context),
        ),
      if (d.fleetVerification != null)
        GoRoute(
          path: FleetRoutePaths.verification,
          parentNavigatorKey: rootNavigatorKey,
          builder: (context, state) => d.fleetVerification!(context),
        ),
      if (d.fleetWallet != null)
        GoRoute(
          path: FleetRoutePaths.wallet,
          parentNavigatorKey: rootNavigatorKey,
          builder: (context, state) => d.fleetWallet!(context),
        ),
      if (d.fleetTransactionHistory != null)
        GoRoute(
          path: FleetRoutePaths.transactionHistory,
          parentNavigatorKey: rootNavigatorKey,
          builder: (context, state) => d.fleetTransactionHistory!(context),
        ),
      if (d.fleetSettings != null)
        GoRoute(
          path: FleetRoutePaths.settings,
          parentNavigatorKey: rootNavigatorKey,
          builder: (context, state) => d.fleetSettings!(context),
        ),
      if (d.fleetAppearance != null)
        GoRoute(
          path: FleetRoutePaths.appearance,
          parentNavigatorKey: rootNavigatorKey,
          builder: (context, state) => d.fleetAppearance!(context),
        ),
      if (d.fleetNotifications != null)
        GoRoute(
          path: FleetRoutePaths.notifications,
          parentNavigatorKey: rootNavigatorKey,
          builder: (context, state) => d.fleetNotifications!(context),
        ),
      if (d.fleetLegal != null)
        GoRoute(
          path: FleetRoutePaths.legal,
          parentNavigatorKey: rootNavigatorKey,
          builder: (context, state) => d.fleetLegal!(context),
        ),
      if (d.fleetLegalTerms != null)
        GoRoute(
          path: FleetRoutePaths.legalTerms,
          parentNavigatorKey: rootNavigatorKey,
          builder: (context, state) => d.fleetLegalTerms!(context),
        ),
      if (d.fleetLegalRentalProtocol != null)
        GoRoute(
          path: FleetRoutePaths.legalRentalProtocol,
          parentNavigatorKey: rootNavigatorKey,
          builder: (context, state) => d.fleetLegalRentalProtocol!(context),
        ),
      if (d.fleetLegalInsurancePolicy != null)
        GoRoute(
          path: FleetRoutePaths.legalInsurancePolicy,
          parentNavigatorKey: rootNavigatorKey,
          builder: (context, state) => d.fleetLegalInsurancePolicy!(context),
        ),
      if (d.fleetLegalPrivacyPolicy != null)
        GoRoute(
          path: FleetRoutePaths.legalPrivacyPolicy,
          parentNavigatorKey: rootNavigatorKey,
          builder: (context, state) => d.fleetLegalPrivacyPolicy!(context),
        ),
      if (d.fleetHelpFaqs != null)
        GoRoute(
          path: FleetRoutePaths.helpFaqs,
          parentNavigatorKey: rootNavigatorKey,
          builder: (context, state) => d.fleetHelpFaqs!(context),
        ),
      if (d.fleetSupport != null)
        GoRoute(
          path: FleetRoutePaths.support,
          parentNavigatorKey: rootNavigatorKey,
          builder: (context, state) => d.fleetSupport!(context),
        ),
      if (d.fleetSupportConversation != null)
        GoRoute(
          path: FleetRoutePaths.supportConversation,
          parentNavigatorKey: rootNavigatorKey,
          builder: (context, state) => d.fleetSupportConversation!(context, state.extra),
        ),
      if (d.fleetChat != null)
        GoRoute(
          path: FleetRoutePaths.chat,
          parentNavigatorKey: rootNavigatorKey,
          builder: (context, state) => d.fleetChat!(context),
        ),
      if (d.fleetConversation != null)
        GoRoute(
          path: FleetRoutePaths.conversation,
          parentNavigatorKey: rootNavigatorKey,
          builder: (context, state) => d.fleetConversation!(context, state.extra),
        ),
      if (d.driverDelegates != null) ...[
        GoRoute(
          path: DriverRoutePaths.getStarted,
          builder: (context, state) => d.driverDelegates!.getStarted(context),
        ),
        GoRoute(
          path: DriverRoutePaths.login,
          builder: (context, state) => d.driverDelegates!.login(context),
        ),
        GoRoute(
          path: DriverRoutePaths.signup,
          builder: (context, state) => d.driverDelegates!.signup(context),
        ),
        GoRoute(
          path: DriverRoutePaths.otp,
          builder: (context, state) => d.driverDelegates!.otp(context),
        ),
        GoRoute(
          path: DriverRoutePaths.registerSuccess,
          builder: (context, state) => d.driverDelegates!.registerSuccess(context),
        ),
        GoRoute(
          path: DriverRoutePaths.forgotPassword,
          builder: (context, state) => d.driverDelegates!.forgotPassword(context),
        ),
        GoRoute(
          path: DriverRoutePaths.onboarding,
          builder: (context, state) => d.driverDelegates!.onboarding(context),
        ),
        GoRoute(
          path: DriverRoutePaths.pendingApproval,
          builder: (context, state) => d.driverDelegates!.pendingApproval(context),
        ),
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) {
            return d.driverDelegates!.mainShell(context, navigationShell);
          },
          branches: <StatefulShellBranch>[
            StatefulShellBranch(
              routes: <RouteBase>[
                GoRoute(
                  path: DriverRoutePaths.home,
                  builder: (context, state) => d.driverDelegates!.home(context),
                ),
                GoRoute(
                  path: DriverRoutePaths.notifications,
                  builder: (context, state) => d.driverDelegates!.notifications(context),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: <RouteBase>[
                GoRoute(
                  path: DriverRoutePaths.rides,
                  builder: (context, state) => d.driverDelegates!.rides(context),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: <RouteBase>[
                GoRoute(
                  path: DriverRoutePaths.requests,
                  builder: (context, state) => d.driverDelegates!.requests(context),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: <RouteBase>[
                GoRoute(
                  path: DriverRoutePaths.chat,
                  builder: (context, state) => d.driverDelegates!.chat(context),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: <RouteBase>[
                GoRoute(
                  path: DriverRoutePaths.profile,
                  builder: (context, state) => d.driverDelegates!.profile(context),
                ),
              ],
            ),
          ],
        ),
        GoRoute(
          path: DriverRoutePaths.conversation,
          builder: (context, state) => d.driverDelegates!.conversation(
            context,
            state.extra is Map<String, dynamic>
                ? state.extra as Map<String, dynamic>
                : null,
          ),
        ),
        GoRoute(
          path: DriverRoutePaths.rideDetail,
          builder: (context, state) => d.driverDelegates!.rideDetail(
            context,
            state.extra is String ? state.extra as String : null,
          ),
        ),
        GoRoute(
          path: DriverRoutePaths.wallet,
          builder: (context, state) => d.driverDelegates!.wallet(context),
        ),
        GoRoute(
          path: DriverRoutePaths.walletBankAccount,
          builder: (context, state) => d.driverDelegates!.walletBankAccount(context),
        ),
        GoRoute(
          path: DriverRoutePaths.profileHistory,
          builder: (context, state) => d.driverDelegates!.profileHistory(context),
        ),
        GoRoute(
          path: DriverRoutePaths.profileRatings,
          builder: (context, state) => d.driverDelegates!.profileRatings(context),
        ),
        GoRoute(
          path: DriverRoutePaths.profileDetail,
          builder: (context, state) => d.driverDelegates!.profileDetail(context),
        ),
        GoRoute(
          path: DriverRoutePaths.profileDocuments,
          builder: (context, state) => d.driverDelegates!.profileDocuments(context),
        ),
        GoRoute(
          path: DriverRoutePaths.profileVehicle,
          builder: (context, state) => d.driverDelegates!.profileVehicle(context),
        ),
        GoRoute(
          path: DriverRoutePaths.accountSecurity,
          builder: (context, state) => (d.driverDelegates!.accountSecurity ?? (_) => const SizedBox.shrink())(context),
        ),
        GoRoute(
          path: DriverRoutePaths.helpFaq,
          builder: (context, state) => d.driverDelegates!.helpFaq(context),
        ),
        GoRoute(
          path: DriverRoutePaths.privacyPolicy,
          builder: (context, state) => d.driverDelegates!.privacyPolicy(context),
        ),
        GoRoute(
          path: DriverRoutePaths.aboutApp,
          builder: (context, state) => d.driverDelegates!.aboutApp(context),
        ),
        GoRoute(
          path: DriverRoutePaths.requestDetail,
          builder: (context, state) => d.driverDelegates!.requestDetail(context),
        ),
        GoRoute(
          path: DriverRoutePaths.tripPickup,
          builder: (context, state) => d.driverDelegates!.tripPickup(context),
        ),
        GoRoute(
          path: DriverRoutePaths.tripActive,
          builder: (context, state) => d.driverDelegates!.tripActive(context),
        ),
        GoRoute(
          path: DriverRoutePaths.tripComplete,
          builder: (context, state) => d.driverDelegates!.tripComplete(context),
        ),
        GoRoute(
          path: DriverRoutePaths.rateCustomer,
          builder: (context, state) => d.driverDelegates!.rateCustomer(context),
        ),
        GoRoute(
          path: DriverRoutePaths.documentUpload,
          builder: (context, state) {
            final title = state.uri.queryParameters['title'] ?? 'Document';
            final documentType = state.uri.queryParameters['type'];
            return d.driverDelegates!.documentUpload(context, title, documentType);
          },
        ),
        GoRoute(
          path: DriverRoutePaths.profileBasicInfo,
          builder: (context, state) => d.driverDelegates!.profileBasicInfo(context),
        ),
        GoRoute(
          path: DriverRoutePaths.profilePicture,
          builder: (context, state) => d.driverDelegates!.profilePicture(context),
        ),
        GoRoute(
          path: DriverRoutePaths.helpSupport,
          builder: (context, state) => d.driverDelegates!.helpSupport(context),
        ),
        GoRoute(
          path: DriverRoutePaths.vehicleInfo,
          builder: (context, state) => d.driverDelegates!.vehicleInfo(context),
        ),
        GoRoute(
          path: DriverRoutePaths.profileTiers,
          builder: (context, state) => d.driverDelegates!.profileTiers(context),
        ),
        GoRoute(
          path: DriverRoutePaths.referral,
          builder: (context, state) => d.driverDelegates!.referral(context),
        ),
        GoRoute(
          path: DriverRoutePaths.becomeCustomer,
          builder: (context, state) => d.driverDelegates!.becomeCustomer(context),
        ),
        if (d.driverDelegates!.linkedFleets != null)
          GoRoute(
            path: DriverRoutePaths.linkedFleets,
            builder: (context, state) => d.driverDelegates!.linkedFleets!(context),
          ),
        if (d.driverDelegates!.fleetProfileView != null)
          GoRoute(
            path: DriverRoutePaths.fleetProfileView,
            parentNavigatorKey: rootNavigatorKey,
            builder: (context, state) => d.driverDelegates!.fleetProfileView!(context, state.extra),
          ),
        if (d.driverDelegates!.rentalBookings != null)
          GoRoute(
            path: DriverRoutePaths.rentalBookings,
            parentNavigatorKey: rootNavigatorKey,
            builder: (context, state) => d.driverDelegates!.rentalBookings!(context),
          ),
        if (d.driverDelegates!.rentalTrip != null)
          GoRoute(
            path: DriverRoutePaths.rentalTrip,
            parentNavigatorKey: rootNavigatorKey,
            builder: (context, state) => d.driverDelegates!.rentalTrip!(context, state.extra),
          ),
      ],
      if (d.rentalBrowse != null)
        GoRoute(
          path: CustomerRoutePaths.rentalBrowse,
          parentNavigatorKey: rootNavigatorKey,
          builder: (context, state) => d.rentalBrowse!(context),
        ),
      if (d.rentalVehicleDetail != null)
        GoRoute(
          path: CustomerRoutePaths.rentalVehicleDetail,
          parentNavigatorKey: rootNavigatorKey,
          builder: (context, state) =>
              d.rentalVehicleDetail!(context, state.extra),
        ),
      if (d.vehicleDetailsRating != null)
        GoRoute(
          path: CustomerRoutePaths.vehicleDetailsRating,
          parentNavigatorKey: rootNavigatorKey,
          builder: (context, state) =>
              d.vehicleDetailsRating!(context, state.extra),
        ),
      if (d.rentalBookingForm != null)
        GoRoute(
          path: CustomerRoutePaths.rentalBookingForm,
          parentNavigatorKey: rootNavigatorKey,
          builder: (context, state) =>
              d.rentalBookingForm!(context, state.extra),
        ),
      if (d.rentalBookingSummary != null)
        GoRoute(
          path: CustomerRoutePaths.rentalBookingSummary,
          parentNavigatorKey: rootNavigatorKey,
          builder: (context, state) =>
              d.rentalBookingSummary!(context, state.extra),
        ),
      if (d.rentalBookingDetails != null)
        GoRoute(
          path: CustomerRoutePaths.rentalBookingDetails,
          parentNavigatorKey: rootNavigatorKey,
          builder: (context, state) =>
              d.rentalBookingDetails!(context, state.extra),
        ),
      if (d.rentalPayment != null)
        GoRoute(
          path: CustomerRoutePaths.rentalPayment,
          parentNavigatorKey: rootNavigatorKey,
          builder: (context, state) =>
              d.rentalPayment!(context, state.extra),
        ),
      if (d.popularCars != null)
        GoRoute(
          path: CustomerRoutePaths.popularCars,
          parentNavigatorKey: rootNavigatorKey,
          builder: (context, state) => d.popularCars!(context),
        ),
      if (d.fleetReviews != null)
        GoRoute(
          path: FleetRoutePaths.reviews,
          parentNavigatorKey: rootNavigatorKey,
          builder: (context, state) => d.fleetReviews!(context),
        ),
      if (d.forYouPosts != null)
        GoRoute(
          path: CustomerRoutePaths.forYouPosts,
          parentNavigatorKey: rootNavigatorKey,
          builder: (context, state) => d.forYouPosts!(context),
        ),
      if (d.forYouDetail != null)
        GoRoute(
          path: CustomerRoutePaths.forYouDetail,
          parentNavigatorKey: rootNavigatorKey,
          builder: (context, state) =>
              d.forYouDetail!(context, state.extra),
        ),
    ],
  );

  return CustomerRouterBundle(
    router: router,
    rootNavigatorKey: rootNavigatorKey,
  );
}
