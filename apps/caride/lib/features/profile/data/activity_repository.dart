import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum RideActivityTab { ongoing, completed, canceled }

class RideActivityRecord {
  const RideActivityRecord({
    required this.id,
    required this.tab,
    required this.rideType,
    required this.pickup,
    required this.dropoff,
    required this.pickupTime,
    required this.dropoffTime,
    required this.date,
    required this.distanceKm,
    required this.amountNaira,
    required this.paid,
    required this.paymentMethod,
  });

  final String id;
  final RideActivityTab tab;
  final String rideType;
  final String pickup;
  final String dropoff;
  final String pickupTime;
  final String dropoffTime;
  final String date;
  final double distanceKm;
  final double amountNaira;
  final bool paid;
  final String paymentMethod;

  factory RideActivityRecord.fromMap({
    required String id,
    required Map<String, dynamic> data,
  }) {
    final status = (data['status'] as String?) ?? 'requested';
    final tab = switch (status) {
      'completed' => RideActivityTab.completed,
      'cancelled' => RideActivityTab.canceled,
      _ => RideActivityTab.ongoing,
    };

    final createdAt = (data['createdAt'] as Timestamp?)?.toDate();
    final acceptedAt = (data['acceptedAt'] as Timestamp?)?.toDate();
    final completedAt = (data['completedAt'] as Timestamp?)?.toDate();

    return RideActivityRecord(
      id: id,
      tab: tab,
      rideType: (data['rideType'] as String?) ?? 'Regular',
      pickup:
          (data['pickupLabel'] as String?) ??
          (data['pickupName'] as String?) ??
          'Pickup',
      dropoff:
          (data['dropoffLabel'] as String?) ??
          (data['dropoffName'] as String?) ??
          'Dropoff',
      pickupTime: _timeLabel(acceptedAt),
      dropoffTime: _timeLabel(completedAt),
      date: _dateLabel(createdAt ?? completedAt),
      distanceKm: (data['distanceKm'] as num?)?.toDouble() ?? 0,
      amountNaira:
          (data['amountNaira'] as num?)?.toDouble() ??
          (data['customerOffer'] as num?)?.toDouble() ??
          (data['finalFare'] as num?)?.toDouble() ??
          0,
      paid: (data['paid'] as bool?) ??
          ((data['paymentStatus'] as String?)?.trim().toLowerCase() == 'paid') ||
          (status == 'completed' &&
              ((data['paymentMethod'] as String?)?.trim().toLowerCase() == 'cash')),
      paymentMethod: _paymentMethodLabel(data['paymentMethod'] as String?),
    );
  }
}

String _paymentMethodLabel(String? raw) {
  final cleaned = raw?.trim().toLowerCase();
  return switch (cleaned) {
    'wallet' => 'Wallet',
    'cash' => 'Cash',
    _ => raw?.trim().isEmpty ?? true ? 'Payment' : raw!.trim(),
  };
}

String _dateLabel(DateTime? dt) {
  if (dt == null) return '--';
  const months = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  final m = (dt.month >= 1 && dt.month <= 12) ? months[dt.month - 1] : '';
  return '$m ${dt.day}, ${dt.year}';
}

String _timeLabel(DateTime? dt) {
  if (dt == null) return '--:--';
  final h = dt.hour;
  final hour12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
  final mm = dt.minute.toString().padLeft(2, '0');
  final ampm = h >= 12 ? 'PM' : 'AM';
  return '$hour12:$mm $ampm';
}

class ActivityRepository {
  ActivityRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  Stream<List<RideActivityRecord>> watchActivity({int limit = 50}) {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      return Stream.value(const []);
    }
    return _firestore
        .collection('rides')
        .where('customerUid', isEqualTo: uid)
        .orderBy('updatedAt', descending: true)
        // Limit prevents full collection scans for customers with large ride
        // histories. Each Firestore update re-delivers ALL matched docs without
        // a limit, causing excessive bandwidth at scale.
        .limit(limit)
        .snapshots()
        .map((snap) {
          return snap.docs
              .map((doc) => RideActivityRecord.fromMap(id: doc.id, data: doc.data()))
              .toList(growable: false);
        });
  }
}
