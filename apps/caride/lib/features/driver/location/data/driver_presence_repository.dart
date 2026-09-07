import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:caride/core/driver/models/driver_presence.dart';

class DriverPresenceRepository {
  DriverPresenceRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  String? get _uid => _auth.currentUser?.uid;

  DocumentReference<Map<String, dynamic>> _presenceRef(String uid) =>
      _firestore.collection('driverPresence').doc(uid);

  Stream<DriverPresence?> streamPresence() {
    final uid = _uid;
    if (uid == null) return Stream.value(null);
    return _presenceRef(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return DriverPresence.fromDoc(doc);
    });
  }

  Future<DriverPresence?> getPresence() async {
    final uid = _uid;
    if (uid == null) return null;
    final doc = await _presenceRef(uid).get();
    if (!doc.exists) return null;
    return DriverPresence.fromDoc(doc);
  }

  Future<void> updatePresence({
    required DriverAvailabilityState availabilityState,
    required bool isAvailableForRequests,
    GeoPoint? lastLocation,
    double? heading,
    double? speedMps,
    double? accuracyM,
    String? currentRideId,
    String? vehicleType,
    String? approvalStatusSnapshot,
  }) async {
    final uid = _uid;
    if (uid == null) return;
    final now = FieldValue.serverTimestamp();

    await _presenceRef(uid).set({
      'driverUid': uid,
      'availabilityState': availabilityState.value,
      'isAvailableForRequests': isAvailableForRequests,
      'lastLocation': lastLocation,
      'heading': heading,
      'speedMps': speedMps,
      'accuracyM': accuracyM,
      'currentRideId': currentRideId,
      'vehicleType': vehicleType,
      'approvalStatusSnapshot': approvalStatusSnapshot,
      'lastHeartbeatAt': now,
      'updatedAt': now,
    }, SetOptions(merge: true));
  }

  Future<void> setOffline({
    GeoPoint? lastLocation,
    double? heading,
    double? speedMps,
    double? accuracyM,
    String? vehicleType,
    String? approvalStatusSnapshot,
  }) async {
    await updatePresence(
      availabilityState: DriverAvailabilityState.offline,
      isAvailableForRequests: false,
      lastLocation: lastLocation,
      heading: heading,
      speedMps: speedMps,
      accuracyM: accuracyM,
      currentRideId: null,
      vehicleType: vehicleType,
      approvalStatusSnapshot: approvalStatusSnapshot,
    );
  }

  Future<void> heartbeat({
    GeoPoint? lastLocation,
    double? heading,
    double? speedMps,
    double? accuracyM,
    String? currentRideId,
    String? vehicleType,
    String? approvalStatusSnapshot,
    DriverAvailabilityState? availabilityState,
    bool? isAvailableForRequests,
  }) async {
    final uid = _uid;
    if (uid == null) return;
    await _presenceRef(uid).set({
      'driverUid': uid,
      if (availabilityState != null)
        'availabilityState': availabilityState.value,
      if (isAvailableForRequests != null)
        'isAvailableForRequests': isAvailableForRequests,
      if (lastLocation != null) 'lastLocation': lastLocation,
      if (heading != null) 'heading': heading,
      if (speedMps != null) 'speedMps': speedMps,
      if (accuracyM != null) 'accuracyM': accuracyM,
      'currentRideId': currentRideId,
      'vehicleType': vehicleType,
      'approvalStatusSnapshot': approvalStatusSnapshot,
      'lastHeartbeatAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
