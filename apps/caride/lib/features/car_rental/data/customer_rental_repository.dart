import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_models/shared_models.dart';
import 'package:caride/core/config/app_env.dart';

/// Customer-facing repository for browsing available rental vehicles
/// and submitting rental booking requests.
class CustomerRentalRepository {
  CustomerRentalRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    FirebaseFunctions? functions,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _functions = functions ??
            FirebaseFunctions.instanceFor(
                region: AppEnv.firebaseFunctionsRegion);

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final FirebaseFunctions _functions;

  String? get currentUid => _auth.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> get _vehiclesCol =>
      _firestore.collection('rental_vehicles');

  CollectionReference<Map<String, dynamic>> get _bookingsCol =>
      _firestore.collection('rental_bookings');

  // ── Vehicle Browsing ─────────────────────────────────────────────────

  /// Stream all available vehicles globally (from all fleets).
  /// Optionally filter by [category] and/or [city].
  Stream<List<RentalVehicle>> streamAvailableVehicles({
    RentalVehicleCategory? category,
    String? city,
  }) {
    Query<Map<String, dynamic>> query = _vehiclesCol;

    if (category != null) {
      query = query.where('category', isEqualTo: category.name);
    }

    if (city != null && city.isNotEmpty && city != 'All Cities') {
      query = query.where('city', isEqualTo: city);
    }

    return query.snapshots().map((snap) {
      final list = snap.docs
          .map((doc) => RentalVehicle.fromMap(doc.data(), doc.id))
          .where((v) => v.status == RentalVehicleStatus.available)
          .toList();
      list.sort((a, b) {
        // Sort: cheapest first (by min available rate)
        final aRate = _minRate(a);
        final bRate = _minRate(b);
        return aRate.compareTo(bRate);
      });
      return list;
    });
  }

  double _minRate(RentalVehicle v) {
    final rates = <double>[];
    if (v.dailySelfDriveRate > 0) rates.add(v.dailySelfDriveRate);
    if (v.dailyWithDriverRate > 0) rates.add(v.dailyWithDriverRate);
    if (rates.isEmpty) return double.maxFinite;
    return rates.reduce((a, b) => a < b ? a : b);
  }

  /// One-shot fetch of a single vehicle by ID.
  Future<RentalVehicle?> getVehicle(String vehicleId) async {
    if (vehicleId.isEmpty) return null;
    final doc = await _vehiclesCol.doc(vehicleId).get();
    if (!doc.exists || doc.data() == null) return null;
    return RentalVehicle.fromMap(doc.data()!, doc.id);
  }

  // ── Booking Operations ───────────────────────────────────────────────

  /// Submit a new rental booking request.
  /// Returns the generated booking ID on success.
  Future<String> createBooking(RentalBooking booking) async {
    final docRef = _bookingsCol.doc();
    final toSave = booking.copyWith(
      id: docRef.id,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    await docRef.set(toSave.toMap());
    return docRef.id;
  }

  /// Cancel an ongoing rental booking before payment or while awaiting approval.
  Future<void> cancelBooking(String bookingId, {String? reason}) async {
    if (bookingId.isEmpty) return;
    await _bookingsCol.doc(bookingId).update({
      'status': RentalBookingStatus.cancelled.name,
      'cancellationReason': reason ?? 'Cancelled by customer',
      'cancelledBy': 'customer',
      'cancelledAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Stream the authenticated customer's booking history, newest first.
  Stream<List<RentalBooking>> streamCustomerBookings() {
    final uid = currentUid;
    if (uid == null) return Stream.value(const []);

    return _bookingsCol
        .where('customerId', isEqualTo: uid)
        .snapshots()
        .map((snap) {
      final list = snap.docs
          .map((doc) => RentalBooking.fromMap(doc.data(), doc.id))
          .toList();
      list.sort((a, b) =>
          (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
      return list;
    });
  }

  /// Stream active or pending bookings for a specific vehicle.
  /// Bookings with pendingApproval, confirmed, or inProgress hold dates on the calendar.
  Stream<List<RentalBooking>> streamVehicleBookings(String vehicleId) {
    if (vehicleId.isEmpty) return Stream.value(const []);

    return _bookingsCol
        .where('vehicleId', isEqualTo: vehicleId)
        .snapshots()
        .map((snap) {
      return snap.docs
          .map((doc) => RentalBooking.fromMap(doc.data(), doc.id))
          .where((b) {
            // If the booking is awaiting payment but the payment window expired,
            // immediately release the vehicle dates so it does not stay blocked/idle.
            if (b.status == RentalBookingStatus.awaitingPayment && b.isPaymentExpired) {
              return false;
            }
            return b.status == RentalBookingStatus.pendingApproval ||
                b.status == RentalBookingStatus.awaitingPayment ||
                b.status == RentalBookingStatus.confirmed ||
                b.status == RentalBookingStatus.inProgress;
          })
          .toList();
    });
  }

  /// Pay for an approved rental booking via Cloud Function.
  /// Supports paymentMethod: 'wallet', 'card', 'bank_transfer'.
  /// For chauffeur bookings: returns `{ 'success': true, 'startPin': string }`.
  /// For self-drive bookings: returns `{ 'success': true, 'pickupPin': string }`.
  Future<Map<String, dynamic>> payBooking({
    required String bookingId,
    required String paymentMethod,
    String? paymentReference,
  }) async {
    final callable = _functions.httpsCallable('payRentalBooking');
    final res = await callable.call({
      'bookingId': bookingId,
      'paymentMethod': paymentMethod,
      if (paymentReference != null) 'paymentReference': paymentReference,
    });
    return Map<String, dynamic>.from(res.data as Map);
  }

  /// Customer confirms pickup of a self-drive vehicle by entering the pickup PIN
  /// (which the fleet manager shares verbally or on-screen).
  /// On success: booking moves to `inProgress` and a return PIN is generated.
  Future<void> confirmSelfDrivePickup({
    required String bookingId,
    required String enteredPin,
  }) async {
    try {
      final callable = _functions.httpsCallable('confirmSelfDrivePickup');
      await callable.call({
        'bookingId': bookingId,
        'enteredPin': enteredPin,
      });
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'not-found' || (e.message ?? '').toLowerCase().contains('not found')) {
        await _confirmSelfDrivePickupDirect(
          bookingId: bookingId,
          enteredPin: enteredPin,
        );
      } else {
        rethrow;
      }
    } catch (e) {
      final errStr = e.toString().toLowerCase();
      if (errStr.contains('not-found') || errStr.contains('not found')) {
        await _confirmSelfDrivePickupDirect(
          bookingId: bookingId,
          enteredPin: enteredPin,
        );
      } else {
        rethrow;
      }
    }
  }

  Future<void> _confirmSelfDrivePickupDirect({
    required String bookingId,
    required String enteredPin,
  }) async {
    final docRef = _bookingsCol.doc(bookingId);
    final snap = await docRef.get();
    if (!snap.exists || snap.data() == null) {
      throw FirebaseFunctionsException(
        code: 'not-found',
        message: 'Booking record was not found in database.',
      );
    }
    final data = snap.data()!;
    final booking = RentalBooking.fromMap(data, snap.id);

    if (booking.status != RentalBookingStatus.confirmed) {
      throw FirebaseFunctionsException(
        code: 'failed-precondition',
        message: 'Vehicle pickup cannot be confirmed right now. Booking status is not ready for vehicle handover.',
      );
    }
    if (booking.pickupPinUsed || booking.startPinUsed) {
      throw FirebaseFunctionsException(
        code: 'already-exists',
        message: 'This Pickup PIN has already been verified and the rental trip is in progress.',
      );
    }

    final expectedPin = (booking.pickupPin ?? booking.startPin ?? '').trim();
    if (expectedPin.isEmpty || expectedPin != enteredPin.trim()) {
      throw FirebaseFunctionsException(
        code: 'invalid-argument',
        message: 'Incorrect Pickup PIN. Please check the 4-digit code provided by the fleet manager and try again.',
      );
    }

    final genReturnPin = (booking.returnPin != null && booking.returnPin!.trim().isNotEmpty)
        ? booking.returnPin!.trim()
        : (1000 + (DateTime.now().millisecondsSinceEpoch % 9000)).toString();

    await docRef.update({
      'status': RentalBookingStatus.inProgress.name,
      'rentalTripStatus': 'inProgress',
      'pickupPinUsed': true,
      'startPinUsed': true,
      'returnPin': genReturnPin,
      'returnPinUsed': false,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Customer confirms return of a self-drive vehicle by entering the return PIN
  /// (which the fleet manager provides when accepting the returned vehicle).
  /// On success: booking moves to `completed` and fleet wallet is credited.
  Future<void> confirmSelfDriveReturn({
    required String bookingId,
    required String enteredPin,
  }) async {
    try {
      final callable = _functions.httpsCallable('confirmSelfDriveReturn');
      await callable.call({
        'bookingId': bookingId,
        'enteredPin': enteredPin,
      });
    } on FirebaseFunctionsException catch (e) {
      if (e.code == 'not-found' || (e.message ?? '').toLowerCase().contains('not found')) {
        await _confirmSelfDriveReturnDirect(
          bookingId: bookingId,
          enteredPin: enteredPin,
        );
      } else {
        rethrow;
      }
    } catch (e) {
      final errStr = e.toString().toLowerCase();
      if (errStr.contains('not-found') || errStr.contains('not found')) {
        await _confirmSelfDriveReturnDirect(
          bookingId: bookingId,
          enteredPin: enteredPin,
        );
      } else {
        rethrow;
      }
    }
  }

  Future<void> _confirmSelfDriveReturnDirect({
    required String bookingId,
    required String enteredPin,
  }) async {
    final docRef = _bookingsCol.doc(bookingId);
    final snap = await docRef.get();
    if (!snap.exists || snap.data() == null) {
      throw FirebaseFunctionsException(
        code: 'not-found',
        message: 'Booking record was not found in database.',
      );
    }
    final data = snap.data()!;
    final booking = RentalBooking.fromMap(data, snap.id);

    if (booking.status != RentalBookingStatus.inProgress) {
      throw FirebaseFunctionsException(
        code: 'failed-precondition',
        message: 'Vehicle return cannot be confirmed right now. Rental trip is not currently active or in progress.',
      );
    }
    if (booking.returnPinUsed) {
      throw FirebaseFunctionsException(
        code: 'already-exists',
        message: 'This Return PIN has already been used and the rental is completed.',
      );
    }

    final expectedPin = (booking.returnPin ?? '').trim();
    if (expectedPin.isEmpty || expectedPin != enteredPin.trim()) {
      throw FirebaseFunctionsException(
        code: 'invalid-argument',
        message: 'Incorrect Return PIN. Please confirm the 4-digit return code with the fleet manager and try again.',
      );
    }

    await docRef.update({
      'status': RentalBookingStatus.completed.name,
      'rentalTripStatus': 'completed',
      'returnPinUsed': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ── Fleet Profile Operations ─────────────────────────────────────────

  final Map<String, FleetProfile> _fleetCache = {};

  /// Fetch the FleetProfile for a given fleetId or ownerUid.
  Future<FleetProfile?> getFleetProfile({
    String? fleetId,
    String? ownerUid,
  }) async {
    final cacheKey = (fleetId != null && fleetId.isNotEmpty)
        ? fleetId
        : (ownerUid != null && ownerUid.isNotEmpty ? ownerUid : null);

    if (cacheKey != null && _fleetCache.containsKey(cacheKey)) {
      return _fleetCache[cacheKey];
    }

    // 1. Try fetching by fleetId doc ID directly first
    if (fleetId != null && fleetId.isNotEmpty) {
      try {
        final doc = await _firestore.collection('fleets').doc(fleetId).get();
        if (doc.exists && doc.data() != null) {
          final profile = FleetProfile.fromMap(doc.data()!, doc.id);
          _fleetCache[fleetId] = profile;
          if (profile.ownerUid.isNotEmpty) {
            _fleetCache[profile.ownerUid] = profile;
          }
          return profile;
        }
      } catch (_) {}
    }

    // 2. Otherwise fallback to searching by ownerUid
    if (ownerUid != null && ownerUid.isNotEmpty) {
      try {
        final snap = await _firestore
            .collection('fleets')
            .where('ownerUid', isEqualTo: ownerUid)
            .limit(1)
            .get();
        if (snap.docs.isNotEmpty) {
          final doc = snap.docs.first;
          final profile = FleetProfile.fromMap(doc.data(), doc.id);
          _fleetCache[ownerUid] = profile;
          if (profile.fleetId.isNotEmpty) {
            _fleetCache[profile.fleetId] = profile;
          }
          return profile;
        }
      } catch (_) {}
    }

    return null;
  }
}

/// Global singleton instance.
final customerRentalRepository = CustomerRentalRepository();
