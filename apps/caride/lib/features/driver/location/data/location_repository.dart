import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DriverRideLocation {
  const DriverRideLocation({
    required this.latitude,
    required this.longitude,
    this.heading,
    this.speedMps,
    this.accuracyM,
  });

  final double latitude;
  final double longitude;
  final double? heading;
  final double? speedMps;
  final double? accuracyM;
}

class LocationRepository {
  LocationRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  String? get _uid => _auth.currentUser?.uid;

  Future<void> publishLocation({
    required String rideId,
    required double lat,
    required double lng,
    double? heading,
    double? speedMps,
    double? accuracyM,
  }) async {
    final uid = _uid;
    if (uid == null) return;

    await _firestore.collection('driverLocations').doc(rideId).set({
      'driverUid': uid,
      'lat': lat,
      'lng': lng,
      'heading': heading,
      'speedMps': speedMps,
      'accuracyM': accuracyM,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> clearRideLocation(String rideId) async {
    await _firestore.collection('driverLocations').doc(rideId).delete();
  }

  Stream<DriverRideLocation?> streamDriverLocation(String rideId) {
    return _firestore
        .collection('driverLocations')
        .doc(rideId)
        .snapshots()
        .map((doc) {
          if (!doc.exists) return null;
          final data = doc.data();
          if (data == null) return null;
          final lat = (data['lat'] as num?)?.toDouble();
          final lng = (data['lng'] as num?)?.toDouble();
          if (lat == null || lng == null) return null;
          return DriverRideLocation(
            latitude: lat,
            longitude: lng,
            heading: (data['heading'] as num?)?.toDouble(),
            speedMps: (data['speedMps'] as num?)?.toDouble(),
            accuracyM: (data['accuracyM'] as num?)?.toDouble(),
          );
        });
  }
}
