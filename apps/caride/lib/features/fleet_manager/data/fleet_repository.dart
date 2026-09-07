import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_models/shared_models.dart';

/// Repository handling Firestore operations for Fleet Management,
/// Rental Vehicles, Fleet Drivers, and Rental Bookings.
class FleetRepository {
  FleetRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  String? get currentUid => _auth.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> get _fleetsCol =>
      _firestore.collection('fleets');

  CollectionReference<Map<String, dynamic>> get _vehiclesCol =>
      _firestore.collection('rental_vehicles');

  CollectionReference<Map<String, dynamic>> get _bookingsCol =>
      _firestore.collection('rental_bookings');

  CollectionReference<Map<String, dynamic>> get _driversCol =>
      _firestore.collection('fleet_drivers');

  // ── Fleet Profile Operations ──────────────────────────────────────────

  /// Stream current user's fleet profile by owner UID.
  Stream<FleetProfile?> streamFleetProfile([String? uid]) {
    final targetUid = uid ?? currentUid;
    if (targetUid == null) return Stream.value(null);

    return _fleetsCol
        .where('ownerUid', isEqualTo: targetUid)
        .limit(1)
        .snapshots()
        .map((snap) {
      if (snap.docs.isEmpty) return null;
      final doc = snap.docs.first;
      return FleetProfile.fromMap(doc.data(), doc.id);
    });
  }

  /// Get fleet profile for the current user synchronously / one-time.
  Future<FleetProfile?> getFleetProfile([String? uid]) async {
    final targetUid = uid ?? currentUid;
    if (targetUid == null) return null;

    final snap = await _fleetsCol
        .where('ownerUid', isEqualTo: targetUid)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) return null;
    final doc = snap.docs.first;
    return FleetProfile.fromMap(doc.data(), doc.id);
  }

  /// Create or update a Fleet Profile document.
  Future<FleetProfile> createOrUpdateFleetProfile(FleetProfile profile) async {
    final docRef = profile.fleetId.isNotEmpty
        ? _fleetsCol.doc(profile.fleetId)
        : _fleetsCol.doc();

    final fleetId = docRef.id;
    final updatedProfile = profile.copyWith(
      fleetId: fleetId,
      ownerUid: profile.ownerUid.isNotEmpty ? profile.ownerUid : currentUid,
      createdAt: profile.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await docRef.set(updatedProfile.toMap(), SetOptions(merge: true));

    // Also update users metadata to tag fleet owner
    if (currentUid != null) {
      await _firestore.collection('users').doc(currentUid).set({
        'fleetId': fleetId,
        'hasFleet': true,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    return updatedProfile;
  }

  // ── Vehicle Inventory Operations ──────────────────────────────────────

  /// Stream all vehicles belonging to a specific fleet.
  Stream<List<RentalVehicle>> streamVehicles(String fleetId) {
    if (fleetId.isEmpty) return Stream.value(const []);

    return _vehiclesCol
        .where('fleetId', isEqualTo: fleetId)
        .snapshots()
        .map((snap) {
      final list = snap.docs
          .map((doc) => RentalVehicle.fromMap(doc.data(), doc.id))
          .toList();
      list.sort((a, b) => (b.createdAt ?? DateTime(0))
          .compareTo(a.createdAt ?? DateTime(0)));
      return list;
    });
  }

  /// Add or update a rental vehicle in inventory.
  Future<void> saveVehicle(RentalVehicle vehicle) async {
    final docRef = vehicle.id.isNotEmpty
        ? _vehiclesCol.doc(vehicle.id)
        : _vehiclesCol.doc();

    final toSave = vehicle.copyWith(
      id: docRef.id,
      fleetId: vehicle.fleetId,
      ownerUid: vehicle.ownerUid.isNotEmpty ? vehicle.ownerUid : currentUid,
      createdAt: vehicle.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final isNew = vehicle.id.isEmpty;
    await docRef.set(toSave.toMap(), SetOptions(merge: true));

    // Update fleet vehicle count
    if (isNew && vehicle.fleetId.isNotEmpty) {
      await _fleetsCol.doc(vehicle.fleetId).update({
        'totalVehicles': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  /// Toggle vehicle availability status.
  Future<void> updateVehicleStatus(
    String vehicleId,
    RentalVehicleStatus status,
  ) async {
    await _vehiclesCol.doc(vehicleId).update({
      'status': status.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Delete a vehicle from the fleet inventory.
  Future<void> deleteVehicle(String vehicleId, String fleetId) async {
    await _vehiclesCol.doc(vehicleId).delete();
    if (fleetId.isNotEmpty) {
      await _fleetsCol.doc(fleetId).update({
        'totalVehicles': FieldValue.increment(-1),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }

  // ── Rental Bookings / Orders Operations ───────────────────────────────

  /// Stream bookings for a specific fleet.
  Stream<List<RentalBooking>> streamFleetBookings(
    String fleetId, {
    RentalBookingStatus? statusFilter,
  }) {
    if (fleetId.isEmpty) return Stream.value(const []);

    Query<Map<String, dynamic>> query =
        _bookingsCol.where('fleetId', isEqualTo: fleetId);

    if (statusFilter != null) {
      query = query.where('status', isEqualTo: statusFilter.name);
    }

    return query.snapshots().map((snap) {
      final list = snap.docs
          .map((doc) => RentalBooking.fromMap(doc.data(), doc.id))
          .toList();
      list.sort((a, b) => (b.createdAt ?? DateTime(0))
          .compareTo(a.createdAt ?? DateTime(0)));
      return list;
    });
  }

  /// Update booking status (e.g. approve, reject, start, complete) and assign driver.
  Future<void> updateBookingStatus(
    String bookingId,
    RentalBookingStatus status, {
    String? assignedDriverId,
    String? assignedDriverName,
    String? assignedDriverPhone,
    String? rejectionReason,
  }) async {
    final Map<String, dynamic> updateData = {
      'status': status.name,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (assignedDriverId != null) {
      updateData['assignedDriverId'] = assignedDriverId;
    }
    if (assignedDriverName != null) {
      updateData['assignedDriverName'] = assignedDriverName;
    }
    if (assignedDriverPhone != null) {
      updateData['assignedDriverPhone'] = assignedDriverPhone;
    }
    if (rejectionReason != null) {
      updateData['rejectionReason'] = rejectionReason;
    }

    await _bookingsCol.doc(bookingId).update(updateData);
  }

  // ── Fleet Drivers Management ──────────────────────────────────────────

  /// Stream drivers linked to this fleet.
  Stream<List<FleetDriver>> streamDrivers(String fleetId) {
    if (fleetId.isEmpty) return Stream.value(const []);

    return _driversCol
        .where('fleetId', isEqualTo: fleetId)
        .snapshots()
        .map((snap) {
      return snap.docs
          .map((doc) => FleetDriver.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  /// Invite / Link a driver to the fleet.
  Future<void> inviteDriver(
    String fleetId, {
    required String fullName,
    required String phone,
    String email = '',
    String? licenseNumber,
    String? assignedVehicleId,
    String? assignedVehicleTitle,
  }) async {
    final docRef = _driversCol.doc();
    final driver = FleetDriver(
      id: docRef.id,
      driverUid: '', // Can be linked once driver registers or accepts
      fleetId: fleetId,
      fullName: fullName,
      phone: phone,
      email: email,
      licenseNumber: licenseNumber,
      status: FleetDriverStatus.active,
      assignedVehicleId: assignedVehicleId,
      assignedVehicleTitle: assignedVehicleTitle,
      joinedAt: DateTime.now(),
    );

    await docRef.set(driver.toMap());

    // Update fleet driverIds list
    await _fleetsCol.doc(fleetId).update({
      'driverIds': FieldValue.arrayUnion([docRef.id]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Update driver active / suspended status.
  Future<void> updateDriverStatus(
    String driverDocId,
    FleetDriverStatus status,
  ) async {
    await _driversCol.doc(driverDocId).update({
      'status': status.name,
    });
  }

  /// Remove driver from fleet.
  Future<void> removeDriver(String fleetId, String driverDocId) async {
    await _driversCol.doc(driverDocId).delete();
    if (fleetId.isNotEmpty) {
      await _fleetsCol.doc(fleetId).update({
        'driverIds': FieldValue.arrayRemove([driverDocId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
  }
}

final fleetRepository = FleetRepository();
