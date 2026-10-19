import 'dart:async';
import 'dart:ui';

import 'package:caride/app/theme_mode_controller.dart';
import 'package:caride/core/auth/customer_auth_controller.dart';
import 'package:caride/core/firebase/firebase_bootstrap.dart';
import 'package:caride/core/notifications/customer_notifications_controller.dart';
import 'package:caride/core/permissions/startup_permissions.dart';
import 'package:caride/core/navigation/auth_redirect.dart';
import 'package:caride/router/customer_route_factory.dart';
import 'package:design_system/design_system.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:navigation/navigation.dart';

import 'package:google_maps_flutter_android/google_maps_flutter_android.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';

import 'package:caride/core/services/deep_link_service.dart';

Future<void> main() async {
  // ── Crashlytics zone setup ─────────────────────────────────────────────────
  // IMPORTANT: ensureInitialized() and runApp() must both be called from the
  // SAME zone to avoid the "Zone mismatch" fatal crash reported by Crashlytics.
  // We therefore set up a top-level error handler first, then wrap EVERYTHING
  // (including ensureInitialized) inside a single runZonedGuarded call.
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      // Initialize the latest map renderer to prevent graphics buffer leaks/crashes on Android
      final GoogleMapsFlutterPlatform mapsImplementation =
          GoogleMapsFlutterPlatform.instance;
      if (mapsImplementation is GoogleMapsFlutterAndroid) {
        try {
          await mapsImplementation.initializeWithRenderer(AndroidMapRenderer.latest);
        } catch (e) {
          debugPrint('Error initializing Google Maps latest renderer: $e');
        }
      }

      FirebaseMessaging.onBackgroundMessage(
        customerFirebaseMessagingBackgroundHandler,
      );

      SystemChrome.setSystemUIOverlayStyle(
        const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
      );

      // Lock orientation globally to portrait-only
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.portraitUp,
        DeviceOrientation.portraitDown,
      ]);

      await requestStartupPermissions();

      try {
        await FirebaseBootstrap.initialize();
        await DeepLinkService.instance.init();

        // ── Crashlytics: capture all Flutter & async errors ─────────────────
        final crashlytics = FirebaseCrashlytics.instance;
        bool isRecoverableError(String errorStr) {
          return errorStr.contains('HTTP request failed') ||
              errorStr.contains('NetworkImage') ||
              errorStr.contains('HttpException') ||
              errorStr.contains('SocketException') ||
              errorStr.contains('HandshakeException') ||
              errorStr.contains('fonts.gstatic.com') ||
              errorStr.contains('Failed host lookup') ||
              errorStr.contains('permission-denied') ||
              errorStr.contains('ListTile background color') ||
              errorStr.contains('A RenderFlex overflowed') ||
              errorStr.contains('SignInHubActivity') ||
              errorStr.contains('already_active') ||
              errorStr.contains('Image picker is already active');
        }

        FlutterError.onError = (FlutterErrorDetails details) {
          final String errorStr = details.exceptionAsString();
          if (isRecoverableError(errorStr)) {
            crashlytics.recordFlutterError(details, fatal: false);
          } else {
            crashlytics.recordFlutterFatalError(details);
          }
        };

        PlatformDispatcher.instance.onError = (error, stack) {
          final String errorStr = error.toString();
          final bool nonFatal = isRecoverableError(errorStr);
          crashlytics.recordError(error, stack, fatal: !nonFatal);
          return true;
        };

        runApp(const CustomerApp());
      } catch (error) {
        runApp(BootstrapFailureApp(error: error.toString()));
      }
    },
    (error, stack) {
      final String errorStr = error.toString();
      final bool nonFatal = errorStr.contains('HTTP request failed') ||
          errorStr.contains('NetworkImage') ||
          errorStr.contains('HttpException') ||
          errorStr.contains('SocketException') ||
          errorStr.contains('HandshakeException') ||
          errorStr.contains('fonts.gstatic.com') ||
          errorStr.contains('Failed host lookup') ||
          errorStr.contains('permission-denied') ||
          errorStr.contains('ListTile background color') ||
          errorStr.contains('SignInHubActivity') ||
          errorStr.contains('already_active') ||
          errorStr.contains('Image picker is already active');

      try {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: !nonFatal);
      } catch (_) {
        debugPrint('Unhandled error (Crashlytics unavailable): $error\n$stack');
      }
    },
  );
}

class CustomerApp extends StatefulWidget {
  const CustomerApp({super.key});

  @override
  State<CustomerApp> createState() => _CustomerAppState();
}

class _CustomerAppState extends State<CustomerApp> {
  late final CustomerRouterBundle _router;
  late final CustomerNotificationsController _notifications;

  @override
  void initState() {
    super.initState();
    _router = createCustomerRouter(
      d: buildCustomerRouteDelegates(),
      refreshListenable: customerAuthController,
      redirect: (_, state) => customerAuthRedirect(state),
    );
    _notifications = CustomerNotificationsController();
    unawaited(_notifications.initialize(router: _router.router));
    customerThemeMode.addListener(_onThemeMode);
  }

  void _onThemeMode() => setState(() {});

  @override
  void dispose() {
    customerThemeMode.removeListener(_onThemeMode);
    unawaited(_notifications.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'CaRide',
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: customerThemeMode.value,
      routerConfig: _router.router,
    );
  }
}

class BootstrapFailureApp extends StatelessWidget {
  const BootstrapFailureApp({super.key, required this.error});

  final String error;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Text(
              'Firebase initialization failed.\n$error',
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
