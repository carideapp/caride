import 'package:cloud_firestore/cloud_firestore.dart';

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

  static DriverRideLocation? fromMap(Map<String, dynamic> data) {
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
  }
}

class DriverLocationRepository {
  DriverLocationRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Stream<DriverRideLocation?> watchRideDriverLocation(String rideId) {
    if (rideId.isEmpty) return Stream.value(null);
    return _firestore.collection('driverLocations').doc(rideId).snapshots().map(
      (doc) {
        if (!doc.exists) return null;
        final data = doc.data();
        if (data == null) return null;
        return DriverRideLocation.fromMap(data);
      },
    );
  }
}

