import 'package:cloud_firestore/cloud_firestore.dart';

class DriverPublicProfile {
  const DriverPublicProfile({
    required this.uid,
    required this.fullName,
    required this.phone,
    required this.profilePhotoUrl,
    required this.averageRating,
    this.completedRides = 0,
  });

  final String uid;
  final String fullName;
  final String phone;
  final String profilePhotoUrl;
  final double averageRating;
  final int completedRides;

  static DriverPublicProfile fromMap({
    required String uid,
    required Map<String, dynamic> data,
  }) {
    final ridesCount = (data['completedRides'] as num?)?.toInt() ??
        (data['totalRides'] as num?)?.toInt() ??
        (data['completedTrips'] as num?)?.toInt() ??
        (data['totalTrips'] as num?)?.toInt() ??
        (data['rideCount'] as num?)?.toInt() ??
        0;

    return DriverPublicProfile(
      uid: uid,
      fullName: (data['fullName'] as String?) ?? '',
      phone: (data['phone'] as String?) ?? '',
      profilePhotoUrl: (data['profilePhotoUrl'] as String?) ?? '',
      averageRating: (data['averageRating'] as num?)?.toDouble() ?? 0.0,
      completedRides: ridesCount,
    );
  }
}

class DriverPublicProfileRepository {
  DriverPublicProfileRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Stream<DriverPublicProfile?> watchDriver(String driverUid) {
    if (driverUid.isEmpty) return Stream.value(null);
    return _firestore.collection('drivers').doc(driverUid).snapshots().map((doc) {
      if (!doc.exists) return null;
      final data = doc.data();
      if (data == null) return null;
      return DriverPublicProfile.fromMap(uid: doc.id, data: data);
    });
  }
}

