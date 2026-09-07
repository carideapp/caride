import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DriverRatingEntry {
  const DriverRatingEntry({
    required this.rideId,
    required this.rating,
    required this.customerName,
    required this.ratedAt,
    this.comment,
    this.dropoffLabel,
  });

  final String rideId;
  final int rating;
  final String customerName;
  final DateTime ratedAt;
  final String? comment;
  final String? dropoffLabel;
}

class DriverRatingsSummary {
  const DriverRatingsSummary({
    required this.averageRating,
    required this.totalRatings,
    required this.entries,
  });

  final double averageRating;
  final int totalRatings;
  final List<DriverRatingEntry> entries;
}

class DriverRatingsRepository {
  DriverRatingsRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  String? get _uid => _auth.currentUser?.uid;

  Stream<DriverRatingsSummary> streamRatingsSummary() {
    final uid = _uid;
    if (uid == null) {
      return Stream.value(
        const DriverRatingsSummary(
          averageRating: 0,
          totalRatings: 0,
          entries: [],
        ),
      );
    }

    return _firestore
        .collection('rides')
        .where('driverUid', isEqualTo: uid)
        .where('driverRating', isGreaterThan: 0)
        .orderBy('driverRating', descending: false)
        .snapshots()
        .map((snap) {
      final entries = snap.docs.map((doc) {
        final data = doc.data();
        final rating = (data['driverRating'] as num?)?.toInt() ?? 0;
        final customerName =
            (data['customerName'] as String?)?.isNotEmpty == true
                ? data['customerName'] as String
                : 'Passenger';
        return DriverRatingEntry(
          rideId: doc.id,
          rating: rating,
          customerName: customerName,
          ratedAt: (data['ratedAt'] as Timestamp?)?.toDate() ??
              (data['updatedAt'] as Timestamp?)?.toDate() ??
              DateTime.now(),
          comment: data['driverRatingComment'] as String?,
          dropoffLabel: data['dropoffLabel'] as String?,
        );
      }).toList();

      // Sort by ratedAt descending (can't combine orderBy on different fields
      // with inequality filter without composite index, so we sort client-side)
      entries.sort((a, b) => b.ratedAt.compareTo(a.ratedAt));

      final total = entries.length;
      final average = total > 0
          ? entries.map((e) => e.rating).reduce((a, b) => a + b) / total
          : 0.0;

      return DriverRatingsSummary(
        averageRating: double.parse(average.toStringAsFixed(1)),
        totalRatings: total,
        entries: entries,
      );
    });
  }
}
