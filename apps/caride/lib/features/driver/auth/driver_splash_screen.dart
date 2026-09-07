import 'package:flutter/material.dart';
import 'package:navigation/navigation.dart';
import 'package:design_system/design_system.dart';

/// A premium glass splash screen with subtle pulse and scale animations.
class DriverSplashScreen extends StatefulWidget {
  const DriverSplashScreen({super.key});

  @override
  State<DriverSplashScreen> createState() => _DriverSplashScreenState();
}

class _DriverSplashScreenState extends State<DriverSplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: AppDurations.slow,
    );
    _scaleAnimation = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: AppCurves.spring),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeIn),
    );

    _pulseController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 1200));
      if (!mounted) return;
      context.go(DriverRoutePaths.getStarted);
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Image.asset(
              'lib/assets/CaRide_splashscreen_logo.png',
              width: 240,
              fit: BoxFit.contain,
              color: isDark ? Colors.white : null,
            ),
          ),
        ),
      ),
    );
  }
}
