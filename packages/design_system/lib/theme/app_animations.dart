import 'package:flutter/material.dart';

import 'app_durations.dart';

/// Reusable animation helpers for the Liquid Glass design system.
abstract final class AppAnimations {
  /// Standard page transition builder (iOS-style right-to-left slide + fade).
  static Widget slideTransitionBuilder(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final slideTween = Tween<Offset>(
      begin: const Offset(1.0, 0.0),
      end: Offset.zero,
    ).chain(CurveTween(curve: AppCurves.decelerate));

    final fadeTween = Tween<double>(begin: 0.0, end: 1.0)
        .chain(CurveTween(curve: Curves.easeIn));

    return SlideTransition(
      position: slideTween.animate(animation),
      child: FadeTransition(
        opacity: fadeTween.animate(animation),
        child: child,
      ),
    );
  }

  /// Fade-through transition for tab switches.
  static Widget fadeThroughTransitionBuilder(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return FadeTransition(
      opacity: CurvedAnimation(parent: animation, curve: Curves.easeInOut),
      child: child,
    );
  }

  /// Scale-fade for modal-like presentations (bottom sheets, dialogs).
  static Widget scaleFadeTransitionBuilder(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final scaleTween = Tween<double>(begin: 0.92, end: 1.0)
        .chain(CurveTween(curve: AppCurves.spring));

    final fadeTween = Tween<double>(begin: 0.0, end: 1.0)
        .chain(CurveTween(curve: Curves.easeOut));

    return ScaleTransition(
      scale: scaleTween.animate(animation),
      child: FadeTransition(
        opacity: fadeTween.animate(animation),
        child: child,
      ),
    );
  }

  /// Stagger-delay calculator for list item animations.
  ///
  /// Returns the delay for item at [index] in a staggered list.
  /// Caps out at [maxDelay] to prevent excessive waits.
  static Duration staggerDelay(int index, {int maxDelayMs = 600}) {
    final delay = (index * 50).clamp(0, maxDelayMs);
    return Duration(milliseconds: delay);
  }

  /// Returns a default page transition duration.
  static Duration get pageTransitionDuration => AppDurations.normal;

  /// A helper to create an implicit animation controller config
  /// (for AnimatedContainer, AnimatedOpacity, etc.).
  static Duration get implicitDuration => AppDurations.fast;
  static Curve get implicitCurve => AppCurves.easeOut;
}
