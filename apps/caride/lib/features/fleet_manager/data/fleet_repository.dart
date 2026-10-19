import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_models/shared_models.dart';

/// Repository handling Firestore operations for Fleet Management,
/// Rental Vehicles, Fleet Drivers, and Rental Bookings.
class FleetRepository {
  FleetRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    FirebaseStorage? storage,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _storage = storage ?? _safeStorageInstance();

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final FirebaseStorage _storage;

  static FirebaseStorage _safeStorageInstance() {
    try {
      return FirebaseStorage.instance;
    } catch (_) {
      try {
        return FirebaseStorage.instanceFor(
            bucket: 'gs://caride-app.firebasestorage.app');
      } catch (_) {
        return FirebaseStorage.instanceFor(
            bucket: 'caride-app.firebasestorage.app');
      }
    }
  }

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
    if (fleetId.isEmpty || _auth.currentUser == null) return Stream.value(const []);

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

  /// Upload a vehicle photo to Firebase Storage and return its public download URL.
  Future<String> uploadVehiclePhoto({
    required String fleetId,
    required String vehicleId,
    required File file,
    required String photoId,
  }) async {
    final ext = file.path.split('.').last.toLowerCase();
    final safeExt = ext == 'png' || ext == 'jpg' || ext == 'jpeg' || ext == 'webp' ? ext : 'jpg';
    final ref = _storage
        .ref()
        .child('fleets')
        .child(fleetId)
        .child('vehicles')
        .child(vehicleId)
        .child('$photoId.$safeExt');

    final uploadTask = await ref.putFile(
      file,
      SettableMetadata(contentType: 'image/$safeExt'),
    );
    return await uploadTask.ref.getDownloadURL();
  }

  // ── Rental Bookings / Orders Operations ───────────────────────────────

  /// Stream bookings for a specific fleet.
  Stream<List<RentalBooking>> streamFleetBookings(
    String fleetId, {
    RentalBookingStatus? statusFilter,
  }) {
    if (fleetId.isEmpty || _auth.currentUser == null) return Stream.value(const []);

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

    if (status == RentalBookingStatus.awaitingPayment) {
      updateData['approvedAt'] = FieldValue.serverTimestamp();
      updateData['paymentExpiresAt'] =
          DateTime.now().add(const Duration(hours: 3)).toIso8601String();
    }

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
    if (fleetId.isEmpty || _auth.currentUser == null) return Stream.value(const []);

    return _driversCol
        .where('fleetId', isEqualTo: fleetId)
        .snapshots()
        .map((snap) {
      return snap.docs
          .map((doc) => FleetDriver.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  /// Search platform drivers by username, email, phone, or full name.
  /// Queries both 'drivers' and 'users' collections and matches substrings.
  /// If query is empty, returns an empty list (does not dump platform drivers).
  Future<List<Map<String, dynamic>>> searchDriversFromPlatform([String query = '']) async {
    final rawQuery = query.trim();
    if (rawQuery.isEmpty) {
      return [];
    }

    final clean = rawQuery.toLowerCase();
    final cleanNoAt = clean.replaceAll('@', '').trim();

    final Set<String> seenUids = {};
    final List<Map<String, dynamic>> results = [];

    void addDocData(String docId, Map<String, dynamic> d) {
      if (!seenUids.contains(docId)) {
        seenUids.add(docId);
        final entry = Map<String, dynamic>.from(d);
        entry['uid'] = docId;
        entry['id'] = docId;

        // Safely normalize name
        final rawName = entry['fullName'] ?? entry['name'] ?? entry['displayName'];
        if (rawName != null && rawName.toString().trim().isNotEmpty && rawName.toString() != 'null') {
          entry['fullName'] = rawName.toString().trim();
        } else {
          entry['fullName'] = 'Driver';
        }

        // Safely normalize phone
        final rawPhone = entry['phoneNumber'] ?? entry['phone'];
        if (rawPhone != null && rawPhone.toString().trim().isNotEmpty && rawPhone.toString() != 'null') {
          entry['phoneNumber'] = rawPhone.toString().trim();
        } else {
          entry['phoneNumber'] = '';
        }

        // Safely normalize email
        final rawEmail = entry['email'];
        if (rawEmail != null && rawEmail.toString().trim().isNotEmpty && rawEmail.toString() != 'null') {
          entry['email'] = rawEmail.toString().trim();
        } else {
          entry['email'] = '';
        }

        // Safely normalize username
        final rawUsername = entry['username'];
        if (rawUsername != null &&
            rawUsername.toString().trim().isNotEmpty &&
            rawUsername.toString() != 'null') {
          entry['username'] = rawUsername.toString().trim().replaceAll('@', '');
        } else {
          entry['username'] = null;
        }

        // Safely normalize photo URL
        final rawPhoto = entry['profilePictureUrl'] ??
            entry['profilePhotoUrl'] ??
            entry['photoUrl'] ??
            entry['avatarUrl'];
        if (rawPhoto != null &&
            rawPhoto.toString().trim().isNotEmpty &&
            rawPhoto.toString() != 'null' &&
            (rawPhoto.toString().startsWith('http://') || rawPhoto.toString().startsWith('https://'))) {
          entry['profilePictureUrl'] = rawPhoto.toString().trim();
        } else {
          entry['profilePictureUrl'] = null;
        }

        results.add(entry);
      }
    }

    bool matchesQuery(String docId, Map<String, dynamic> d) {
      final username = (d['username'] as String? ?? '').toLowerCase().replaceAll('@', '');
      final email = (d['email'] as String? ?? '').toLowerCase();
      final fullName = (d['fullName'] as String? ?? d['name'] as String? ?? d['displayName'] as String? ?? '').toLowerCase();
      final phone = (d['phone'] as String? ?? d['phoneNumber'] as String? ?? '').toLowerCase();
      final uid = docId.toLowerCase();

      return (cleanNoAt.isNotEmpty && username.contains(cleanNoAt)) ||
          email.contains(clean) ||
          (cleanNoAt.isNotEmpty && email.contains(cleanNoAt)) ||
          (cleanNoAt.isNotEmpty && fullName.contains(cleanNoAt)) ||
          (cleanNoAt.isNotEmpty && phone.contains(cleanNoAt)) ||
          (cleanNoAt.isNotEmpty && uid.contains(cleanNoAt));
    }

    // ignore: avoid_print
    print('[CaRide Driver Search] Starting search for: "$query" (clean: "$clean", cleanNoAt: "$cleanNoAt")...');

    // 1. Direct targeted queries on 'drivers' collection (fast & precise)
    if (cleanNoAt.isNotEmpty) {
      try {
        final uq = await _firestore.collection('drivers').where('username', isEqualTo: cleanNoAt).get();
        for (final doc in uq.docs) {
          addDocData(doc.id, doc.data());
        }
      } catch (e) {
        // ignore: avoid_print
        print('[CaRide Driver Search] drivers.where(username==cleanNoAt) error: $e');
      }

      try {
        final uqAt = await _firestore.collection('drivers').where('username', isEqualTo: '@$cleanNoAt').get();
        for (final doc in uqAt.docs) {
          addDocData(doc.id, doc.data());
        }
      } catch (e) {
        // ignore: avoid_print
        print('[CaRide Driver Search] drivers.where(username==@cleanNoAt) error: $e');
      }
    }

    try {
      final eq = await _firestore.collection('drivers').where('email', isEqualTo: clean).get();
      for (final doc in eq.docs) {
        addDocData(doc.id, doc.data());
      }
    } catch (e) {
      // ignore: avoid_print
      print('[CaRide Driver Search] drivers.where(email==clean) error: $e');
    }

    // 2. Direct document ID query (if query is a UID)
    try {
      final singleDoc = await _firestore.collection('drivers').doc(query.trim()).get();
      if (singleDoc.exists && singleDoc.data() != null) {
        addDocData(singleDoc.id, singleDoc.data()!);
      }
    } catch (_) {}

    // Direct targeted queries on 'users' collection
    try {
      final userEq = await _firestore.collection('users').where('email', isEqualTo: clean).get();
      for (final doc in userEq.docs) {
        addDocData(doc.id, doc.data());
      }
    } catch (_) {}

    if (cleanNoAt.isNotEmpty) {
      try {
        final userUq = await _firestore.collection('users').where('username', isEqualTo: cleanNoAt).get();
        for (final doc in userUq.docs) {
          addDocData(doc.id, doc.data());
        }
      } catch (_) {}
    }

    // 3. Scan 'drivers' collection (up to 100) and match
    try {
      final snap = await _firestore.collection('drivers').limit(100).get();
      for (final doc in snap.docs) {
        final d = doc.data();
        if (matchesQuery(doc.id, d)) {
          addDocData(doc.id, d);
        }
      }
    } catch (e, stack) {
      // ignore: avoid_print
      print('[CaRide Driver Search] Error scanning "drivers" collection: $e\n$stack');
    }

    // 4. Also check 'users' collection where role is driver
    try {
      final userSnap = await _firestore
          .collection('users')
          .where('activeRole', isEqualTo: 'driver')
          .limit(50)
          .get();

      for (final doc in userSnap.docs) {
        final d = doc.data();
        if (matchesQuery(doc.id, d)) {
          addDocData(doc.id, d);
        }
      }

      final userRoleSnap = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'driver')
          .limit(50)
          .get();

      for (final doc in userRoleSnap.docs) {
        final d = doc.data();
        if (matchesQuery(doc.id, d)) {
          addDocData(doc.id, d);
        }
      }
    } catch (e) {
      // ignore: avoid_print
      print('[CaRide Driver Search] Supplementary users query info: $e');
    }

    // 5. If still no results, search 'customers' collection as fallback (in case user registered there)
    if (results.isEmpty) {
      try {
        final custSnap = await _firestore.collection('customers').limit(100).get();
        for (final doc in custSnap.docs) {
          final d = doc.data();
          if (matchesQuery(doc.id, d)) {
            addDocData(doc.id, d);
          }
        }
      } catch (e) {
        // ignore: avoid_print
        print('[CaRide Driver Search] Customers fallback error: $e');
      }
    }

    // ignore: avoid_print
    print('[CaRide Driver Search] Total matching drivers returned: ${results.length}');
    return results;
  }

  /// Link an existing platform driver to the fleet and dispatch notification
  Future<void> linkDriverToFleet({
    required String fleetId,
    required String fleetName,
    required String driverUid,
    required String fullName,
    required String phone,
    required String email,
    String? username,
    String? photoUrl,
    String? assignedVehicleId,
    String? assignedVehicleTitle,
  }) async {
    // Check if already linked
    final existingSnap = await _driversCol
        .where('fleetId', isEqualTo: fleetId)
        .where('driverUid', isEqualTo: driverUid)
        .limit(1)
        .get();

    final docRef = existingSnap.docs.isNotEmpty ? existingSnap.docs.first.reference : _driversCol.doc();

    final driver = FleetDriver(
      id: docRef.id,
      driverUid: driverUid,
      fleetId: fleetId,
      fullName: fullName,
      phone: phone,
      username: username,
      email: email,
      photoUrl: photoUrl,
      status: FleetDriverStatus.active,
      assignedVehicleId: assignedVehicleId,
      assignedVehicleTitle: assignedVehicleTitle,
      joinedAt: DateTime.now(),
    );

    await docRef.set(driver.toMap());

    // 1. Update fleet driverIds array
    await _fleetsCol.doc(fleetId).update({
      'driverIds': FieldValue.arrayUnion([docRef.id]),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // 2. Update driver's linkedFleetIds array
    if (driverUid.isNotEmpty) {
      await _firestore.collection('drivers').doc(driverUid).update({
        'linkedFleetIds': FieldValue.arrayUnion([fleetId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 3. Dispatch Push / In-App Notification to Driver
      final now = FieldValue.serverTimestamp();
      final notifData = {
        'title': 'Linked to Fleet: $fleetName',
        'body': 'You have been successfully added to $fleetName\'s fleet team as an authorized driver.',
        'type': 'fleet_linked',
        'fleetId': fleetId,
        'fleetName': fleetName,
        'isRead': false,
        'createdAt': now,
      };

      try {
        await _firestore
            .collection('drivers')
            .doc(driverUid)
            .collection('notifications')
            .add(notifData);
      } catch (e) {
        debugPrint('[FleetRepository] Error sending driver in-app notification: $e');
      }

      try {
        await _firestore
            .collection('users')
            .doc(driverUid)
            .collection('notifications')
            .add(notifData);
      } catch (_) {}
    }
  }

  /// Invite / Link a driver to the fleet.
  Future<void> inviteDriver(
    String fleetId, {
    required String fullName,
    required String phone,
    String email = '',
    String? username,
    String? licenseNumber,
    String? assignedVehicleId,
    String? assignedVehicleTitle,
  }) async {
    final docRef = _driversCol.doc();
    final driver = FleetDriver(
      id: docRef.id,
      driverUid: '',
      fleetId: fleetId,
      fullName: fullName,
      phone: phone,
      username: username,
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
    final snap = await _driversCol.doc(driverDocId).get();
    final driverUid = snap.data()?['driverUid'] as String?;

    await _driversCol.doc(driverDocId).delete();
    if (fleetId.isNotEmpty) {
      await _fleetsCol.doc(fleetId).update({
        'driverIds': FieldValue.arrayRemove([driverDocId]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    if (driverUid != null && driverUid.isNotEmpty) {
      try {
        await _firestore.collection('drivers').doc(driverUid).update({
          'linkedFleetIds': FieldValue.arrayRemove([fleetId]),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } catch (_) {}
    }
  }
}

final fleetRepository = FleetRepository();
