import 'package:caride/features/ride_booking/booking_shell/models/ride_option.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RideOptionsRepository {
  RideOptionsRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static const List<RideOption> fallbackOptions = [
    RideOption(
      type: 'Regular',
      subtitle: 'Affordable rides, all to yourself',
      assetPath: 'lib/assets/ride_options/regular.png',
    ),
    RideOption(
      type: 'Comfort',
      subtitle: 'Faster pickup with better comfort',
      assetPath: 'lib/assets/ride_options/comfort.png',
    ),
    RideOption(
      type: 'Luxury',
      subtitle: 'Premium trip experience',
      assetPath: 'lib/assets/ride_options/luxury.png',
    ),
    RideOption(
      type: 'Courier',
      subtitle: 'Send and receive packages',
      assetPath: 'lib/assets/ride_options/courier.png',
    ),
  ];

  static String assetPathForType(String type) {
    return switch (type.trim().toLowerCase()) {
      'comfort' => 'lib/assets/ride_options/comfort.png',
      'luxury' => 'lib/assets/ride_options/luxury.png',
      'courier' => 'lib/assets/ride_options/courier.png',
      _ => 'lib/assets/ride_options/regular.png',
    };
  }

  static String normalizeTypeLabel(String type) {
    return switch (type.trim().toLowerCase()) {
      'regular' => 'Regular',
      'comfort' => 'Comfort',
      'luxury' => 'Luxury',
      'courier' => 'Courier',
      _ => type.trim(),
    };
  }

  /// One-shot fetch of ride options from Firestore config.
  ///
  /// Prefer this over [watchRideOptions] for session-stable config data.
  /// Only call once in [initState] and store the result.
  Future<List<RideOption>> fetchRideOptions() async {
    try {
      final doc =
          await _firestore.collection('config').doc('rideOptions').get();
      final data = doc.data();
      final raw = data?['options'];
      if (raw is! List) return fallbackOptions;

      final parsed = <({RideOption opt, int order})>[];
      for (final item in raw) {
        if (item is! Map) continue;
        final m = item.cast<String, dynamic>();
        final enabled = m['enabled'];
        if (enabled is bool && enabled == false) continue;
        final type = m['type'];
        final subtitle = m['subtitle'];
        if (type is! String || subtitle is! String) continue;
        final normType = normalizeTypeLabel(type);
        if (normType.isEmpty) continue;
        final sortOrder = m['sortOrder'];
        final order = switch (sortOrder) {
          int v => v,
          num v => v.round(),
          _ => _fallbackSortOrder(normType),
        };
        parsed.add((
          opt: RideOption(
            type: normType,
            subtitle: subtitle,
            assetPath: assetPathForType(normType),
          ),
          order: order,
        ));
      }
      if (parsed.isEmpty) return fallbackOptions;
      parsed.sort((a, b) {
        final byOrder = a.order.compareTo(b.order);
        if (byOrder != 0) return byOrder;
        return a.opt.type.compareTo(b.opt.type);
      });
      return parsed.map((e) => e.opt).toList(growable: false);
    } catch (_) {
      return fallbackOptions;
    }
  }

  /// Real-time stream of ride options.
  ///
  /// **DEPRECATED** — Use [fetchRideOptions] instead. Ride options are config
  /// data that rarely changes during a session. A persistent listener wastes
  /// Firestore reads every time any config field is touched.
  @Deprecated('Use fetchRideOptions() in initState instead')
  Stream<List<RideOption>> watchRideOptions() {
    return _firestore.collection('config').doc('rideOptions').snapshots().map(
      (doc) {
        final data = doc.data();
        final raw = data?['options'];
        if (raw is! List) return fallbackOptions;

        final parsed = <({RideOption opt, int order})>[];
        for (final item in raw) {
          if (item is! Map) continue;
          final m = item.cast<String, dynamic>();
          final enabled = m['enabled'];
          if (enabled is bool && enabled == false) continue;
          final type = m['type'];
          final subtitle = m['subtitle'];
          if (type is! String || subtitle is! String) continue;
          final normType = normalizeTypeLabel(type);
          if (normType.isEmpty) continue;
          final sortOrder = m['sortOrder'];
          final order = switch (sortOrder) {
            int v => v,
            num v => v.round(),
            _ => _fallbackSortOrder(normType),
          };

          parsed.add((
            opt: RideOption(
              type: normType,
              subtitle: subtitle,
              assetPath: assetPathForType(normType),
            ),
            order: order,
          ));
        }

        if (parsed.isEmpty) return fallbackOptions;
        parsed.sort((a, b) {
          final byOrder = a.order.compareTo(b.order);
          if (byOrder != 0) return byOrder;
          return a.opt.type.compareTo(b.opt.type);
        });
        return parsed.map((e) => e.opt).toList(growable: false);
      },
    );
  }
}

int _fallbackSortOrder(String type) {
  return switch (type.toLowerCase()) {
    'regular' => 1,
    'comfort' => 2,
    'luxury' => 3,
    'courier' => 4,
    _ => 999,
  };
}

