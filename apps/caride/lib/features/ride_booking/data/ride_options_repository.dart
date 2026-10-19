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
      type: 'Tricycle',
      subtitle: 'Affordable commercial keke ride',
      assetPath: 'lib/assets/caride_branded/tricyle.png',
    ),
    RideOption(
      type: 'Motorcycle',
      subtitle: 'Fast and economical bike trip',
      assetPath: 'lib/assets/motorcycle.png',
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
      'tricycle' || 'keke' => 'lib/assets/caride_branded/tricyle.png',
      'motorcycle' || 'bike' => 'lib/assets/motorcycle.png',
      _ => 'lib/assets/ride_options/regular.png',
    };
  }

  static String normalizeTypeLabel(String type) {
    return switch (type.trim().toLowerCase()) {
      'regular' => 'Regular',
      'comfort' => 'Comfort',
      'luxury' => 'Luxury',
      'courier' => 'Courier',
      'tricycle' || 'keke' => 'Tricycle',
      'motorcycle' || 'bike' => 'Motorcycle',
      _ => type.trim(),
    };
  }

  /// One-shot fetch of ride options from Firestore config, respecting state availability.
  ///
  /// If [operatingState] is provided, options disabled in that Nigerian state are filtered out.
  Future<List<RideOption>> fetchRideOptions({String? operatingState}) async {
    try {
      // 1. Fetch service availability config from config/serviceAvailability
      Map<String, dynamic>? availabilityMap;
      try {
        final availDoc = await _firestore
            .collection('config')
            .doc('serviceAvailability')
            .get();
        if (availDoc.exists) {
          availabilityMap = availDoc.data();
        }
      } catch (_) {}

      bool isTypeAllowed(String type) {
        if (availabilityMap == null) return true;
        final key = switch (type.trim().toLowerCase()) {
          'tricycle' || 'keke' => 'tricycle',
          'motorcycle' || 'bike' => 'motorcycle',
          'comfort' => 'comfort',
          'luxury' => 'luxury',
          'courier' => 'courier',
          _ => 'regular',
        };

        final entry = availabilityMap[key];
        if (entry is! Map) return true;
        final enabled = entry['enabled'];
        if (enabled is bool && !enabled) return false;

        final allStates = entry['allStates'];
        if (allStates is bool && allStates) return true;

        if (operatingState != null && operatingState.trim().isNotEmpty) {
          final rawStates = entry['availableStates'];
          if (rawStates is List) {
            final permittedStates = rawStates
                .map((e) => e.toString().trim().toLowerCase())
                .toSet();
            final normUser = operatingState.trim().toLowerCase();
            return permittedStates.any((p) =>
                p == normUser ||
                normUser.contains(p) ||
                p.contains(normUser));
          }
        }
        return true;
      }

      // 2. Fetch custom ride options if present
      final doc =
          await _firestore.collection('config').doc('rideOptions').get();
      final data = doc.data();
      final raw = data?['options'];
      if (raw is! List) {
        return fallbackOptions
            .where((o) => isTypeAllowed(o.type))
            .toList(growable: false);
      }

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
        if (!isTypeAllowed(normType)) continue;

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

      if (parsed.isEmpty) {
        return fallbackOptions
            .where((o) => isTypeAllowed(o.type))
            .toList(growable: false);
      }

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
  @Deprecated('Use fetchRideOptions() in initState instead')
  Stream<List<RideOption>> watchRideOptions() {
    return _firestore.collection('config').doc('rideOptions').snapshots().map(
      (doc) {
        return fallbackOptions;
      },
    );
  }
}

int _fallbackSortOrder(String type) {
  return switch (type.toLowerCase()) {
    'regular' => 1,
    'comfort' => 2,
    'luxury' => 3,
    'tricycle' || 'keke' => 4,
    'motorcycle' || 'bike' => 5,
    'courier' => 6,
    _ => 999,
  };
}

