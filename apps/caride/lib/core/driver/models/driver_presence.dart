import 'package:cloud_firestore/cloud_firestore.dart';

enum DriverAvailabilityState {
  offline,
  online,
  onTrip;

  static DriverAvailabilityState fromValue(String? value) {
    return switch (value) {
      'online' => DriverAvailabilityState.online,
      'on_trip' => DriverAvailabilityState.onTrip,
      _ => DriverAvailabilityState.offline,
    };
  }

  String get value => switch (this) {
    DriverAvailabilityState.offline => 'offline',
    DriverAvailabilityState.online => 'online',
    DriverAvailabilityState.onTrip => 'on_trip',
  };
}

class DriverPresence {
  const DriverPresence({
    required this.driverUid,
    required this.availabilityState,
    required this.isAvailableForRequests,
    this.lastLocation,
    this.heading,
    this.speedMps,
    this.accuracyM,
    this.currentRideId,
    this.vehicleType,
    this.approvalStatusSnapshot,
    this.lastHeartbeatAt,
    this.updatedAt,
  });

  final String driverUid;
  final DriverAvailabilityState availabilityState;
  final bool isAvailableForRequests;
  final GeoPoint? lastLocation;
  final double? heading;
  final double? speedMps;
  final double? accuracyM;
  final String? currentRideId;
  final String? vehicleType;
  final String? approvalStatusSnapshot;
  final DateTime? lastHeartbeatAt;
  final DateTime? updatedAt;

  bool get isOffline => availabilityState == DriverAvailabilityState.offline;
  bool get isOnline => availabilityState == DriverAvailabilityState.online;
  bool get isOnTrip => availabilityState == DriverAvailabilityState.onTrip;

  double? get latitude => lastLocation?.latitude;
  double? get longitude => lastLocation?.longitude;

  factory DriverPresence.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    return DriverPresence.fromMap(
      uid: doc.id,
      data: doc.data() ?? const <String, dynamic>{},
    );
  }

  factory DriverPresence.fromMap({
    required String uid,
    required Map<String, dynamic> data,
  }) {
    return DriverPresence(
      driverUid: uid,
      availabilityState: DriverAvailabilityState.fromValue(
        data['availabilityState'] as String?,
      ),
      isAvailableForRequests:
          (data['isAvailableForRequests'] as bool?) ?? false,
      lastLocation: data['lastLocation'] as GeoPoint?,
      heading: (data['heading'] as num?)?.toDouble(),
      speedMps: (data['speedMps'] as num?)?.toDouble(),
      accuracyM: (data['accuracyM'] as num?)?.toDouble(),
      currentRideId: data['currentRideId'] as String?,
      vehicleType: data['vehicleType'] as String?,
      approvalStatusSnapshot: data['approvalStatusSnapshot'] as String?,
      lastHeartbeatAt: (data['lastHeartbeatAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }
}
