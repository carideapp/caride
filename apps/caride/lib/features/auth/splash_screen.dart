import 'package:caride/core/auth/customer_auth_controller.dart';
import 'package:caride/core/auth/pending_otp_session.dart';
import 'package:caride/core/driver/auth/driver_auth_controller.dart';
import 'package:caride/features/fleet_manager/auth/controllers/fleet_auth_controller.dart';
import 'package:caride/features/fleet_manager/controllers/fleet_manager_controller.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:navigation/navigation.dart';

/// Splash screen that displays the brand Lottie animation and navigates to the role-specific home.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);

    // Fallback safety navigation in case animation fails or hangs
    Future.delayed(const Duration(seconds: 5), () {
      if (mounted && !_hasNavigated) {
        _navigateNext();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onLoaded(LottieComposition composition) {
    _controller.duration = composition.duration;
    _controller.forward().whenComplete(() {
      if (!mounted) return;
      _navigateNext();
    });
  }

  Future<void> _navigateNext() async {
    if (_hasNavigated || !mounted) return;
    _hasNavigated = true;

    if (customerAuthController.isAuthenticated) {
      final role = customerAuthController.activeRole;
      if (role == 'fleet') {
        final hasFleet = customerAuthController.fleetExists ||
            fleetManagerController.hasFleetProfile;
        context.go(hasFleet ? FleetRoutePaths.dashboard : FleetRoutePaths.signup);
      } else if (role == 'driver') {
        context.go(DriverRoutePaths.home);
      } else {
        // Default: customer mode
        if (!customerAuthController.isProfileComplete) {
          context.go(CustomerRoutePaths.completeProfile);
        } else {
          context.go(CustomerRoutePaths.home);
        }
      }
    } else {
      // Check if there is an active, unexpired pending OTP session that was interrupted
      // (e.g., when the user minimized the app to copy the code from Gmail and the OS recycled the process).
      final session = await PendingOtpSessionService.instance.loadSession();
      if (!mounted) return;

      if (session != null) {
        if (session.role == 'fleet') {
          await fleetAuthController.restorePendingSession();
          if (mounted) context.go(FleetRoutePaths.otp);
          return;
        } else if (session.role == 'driver') {
          await driverAuthController.restorePendingSession();
          if (mounted) context.go(DriverRoutePaths.otp);
          return;
        } else {
          await customerAuthController.restorePendingSession();
          if (mounted) context.go(CustomerRoutePaths.otp);
          return;
        }
      }

      context.go(CustomerRoutePaths.welcome);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: SizedBox.expand(
        child: FittedBox(
          fit: BoxFit.cover,
          alignment: Alignment.bottomCenter,
          child: SizedBox(
            // Native animation canvas size from splash_animation.json ("w":720,"h":1280)
            width: 720,
            height: 1280,
            child: Lottie.asset(
              'lib/assets/splash_screen/splash_animation.json',
              controller: _controller,
              onLoaded: _onLoaded,
              fit: BoxFit.fill,
            ),
          ),
        ),
      ),
    );
  }
}
