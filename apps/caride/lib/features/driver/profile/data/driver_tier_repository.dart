import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class TierSetting {
  const TierSetting({
    required this.id,
    required this.name,
    required this.commissionPercent,
    required this.minTrips,
    required this.maxTrips,
    required this.minRating,
    required this.order,
  });

  final String id;
  final String name;
  final int commissionPercent;
  final int minTrips;
  final int? maxTrips;
  final double minRating;
  final int order;

  String get tripsLabel {
    if (maxTrips == null) return '$minTrips+ trips';
    return '$minTrips – $maxTrips trips';
  }

  String get ratingLabel => minRating > 0 ? '$minRating+ rating' : 'No minimum';

  factory TierSetting.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return TierSetting(
      id: doc.id,
      name: (data['name'] as String?) ?? doc.id,
      commissionPercent: (data['commissionPercent'] as num?)?.toInt() ?? 20,
      minTrips: (data['minTrips'] as num?)?.toInt() ?? 0,
      maxTrips: (data['maxTrips'] as num?)?.toInt(),
      minRating: (data['minRating'] as num?)?.toDouble() ?? 0.0,
      order: (data['order'] as num?)?.toInt() ?? 1,
    );
  }
}

class DriverTierStats {
  const DriverTierStats({
    required this.tier,
    required this.completedRides,
    required this.averageRating,
    required this.totalRatings,
  });

  final String tier;
  final int completedRides;
  final double averageRating;
  final int totalRatings;
}

class DriverTierRepository {
  DriverTierRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  String? get _uid => _auth.currentUser?.uid;

  Stream<DriverTierStats?> streamDriverTierStats() {
    final uid = _uid;
    if (uid == null) return Stream.value(null);

    return _firestore.collection('drivers').doc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      final data = doc.data() ?? {};
      return DriverTierStats(
        tier: (data['tier'] as String?) ?? 'bronze',
        completedRides: (data['completedRides'] as num?)?.toInt() ?? 0,
        averageRating: (data['averageRating'] as num?)?.toDouble() ?? 0.0,
        totalRatings: (data['totalRatings'] as num?)?.toInt() ?? 0,
      );
    });
  }

  Stream<List<TierSetting>> streamTierSettings() {
    return _firestore
        .collection('tierSettings')
        .orderBy('order')
        .snapshots()
        .map((snap) {
      if (snap.docs.isEmpty) {
        // Return defaults if not yet seeded
        return _defaultTierSettings;
      }
      return snap.docs.map(TierSetting.fromDoc).toList();
    });
  }

  static final List<TierSetting> _defaultTierSettings = [
    TierSetting(id: 'bronze', name: 'Bronze', commissionPercent: 20, minTrips: 0, maxTrips: 49, minRating: 0, order: 1),
    TierSetting(id: 'silver', name: 'Silver', commissionPercent: 19, minTrips: 50, maxTrips: 149, minRating: 4.0, order: 2),
    TierSetting(id: 'gold', name: 'Gold', commissionPercent: 18, minTrips: 150, maxTrips: 299, minRating: 4.5, order: 3),
    TierSetting(id: 'platinum', name: 'Platinum', commissionPercent: 17, minTrips: 300, maxTrips: null, minRating: 4.7, order: 4),
  ];
}
