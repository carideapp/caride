import 'package:flutter/animation.dart';
import 'package:flutter/physics.dart';

/// Animation duration and curve tokens for the Liquid Glass design system.
abstract final class AppDurations {
  static const Duration instant = Duration(milliseconds: 100);
  static const Duration fast = Duration(milliseconds: 200);
  static const Duration normal = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 450);
  static const Duration slower = Duration(milliseconds: 600);
  static const Duration dramatic = Duration(milliseconds: 800);
}

/// Curated animation curves.
abstract final class AppCurves {
  /// Apple-style ease-out for most transitions.
  static const Curve easeOut = Curves.easeOutCubic;

  /// Smooth ease-in-out for reversible animations.
  static const Curve easeInOut = Curves.easeInOutCubic;

  /// Dramatic deceleration for page transitions.
  static const Curve decelerate = Curves.easeOutExpo;

  /// Bouncy spring for micro-interactions (button presses, chips).
  static const Curve spring = _SpringCurve(200, 20, 1);

  /// Snappy spring for navigation transitions.
  static const Curve springSnappy = _SpringCurve(300, 28, 1);

  /// Gentle spring for bottom sheet snap.
  static const Curve springGentle = _SpringCurve(150, 16, 1);
}

/// A [Curve] backed by a critically/over-damped spring simulation.
class _SpringCurve extends Curve {
  const _SpringCurve(this.stiffness, this.damping, this.mass);

  final double stiffness;
  final double damping;
  final double mass;

  @override
  double transformInternal(double t) {
    final simulation = SpringSimulation(
      SpringDescription(mass: mass, stiffness: stiffness, damping: damping),
      0, // start
      1, // end
      0, // initial velocity
    );
    return simulation.x(t);
  }
}
