import 'package:caride/core/auth/customer_auth_controller.dart';
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

  void _navigateNext() {
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
