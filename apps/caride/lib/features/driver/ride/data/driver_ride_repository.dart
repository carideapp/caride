import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:caride/core/services/cashback_service.dart';
import 'package:caride/core/driver/config/app_env.dart';

import 'package:caride/core/driver/models/bid_model.dart';
import 'package:caride/core/driver/models/ride_model.dart';
import 'package:caride/core/driver/utils/distance_helper.dart';

class DriverRideRepository {
  DriverRideRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    FirebaseFunctions? functions,
  })
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance,
      _functions = functions ??
          FirebaseFunctions.instanceFor(region: AppEnv.firebaseFunctionsRegion);

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final FirebaseFunctions _functions;

  String? get _uid => _auth.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> get _ridesCol =>
      _firestore.collection('rides');

  CollectionReference<Map<String, dynamic>> _bidsCol(String rideId) =>
      _firestore.collection('bids').doc(rideId).collection('offers');

  /// Stream all rides available for bidding, filtered optionally by vehicleType and distance.
  Stream<List<RideModel>> streamAvailableRides({
    bool enabled = true,
    String? vehicleType,
    double? driverLat,
    double? driverLng,
    double maxDistanceKm = 10.0,
  }) {
    if (!enabled) return Stream.value(const <RideModel>[]);
    
    Query<Map<String, dynamic>> query = _ridesCol
        .where('status', whereIn: ['requested', 'bidding']);

    if (vehicleType != null && vehicleType.isNotEmpty) {
      final normalizedType = vehicleType[0].toUpperCase() + vehicleType.substring(1).toLowerCase();
      query = query.where('rideType', isEqualTo: normalizedType);
    }

    return query
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snap) {
            final rides = snap.docs.map((d) => RideModel.fromDoc(d)).toList();
            if (driverLat == null || driverLng == null) {
              return rides;
            }
            return rides.where((ride) {
              if (ride.pickupLat == null || ride.pickupLng == null) {
                return false;
              }
              final dist = calculateDistance(
                driverLat,
                driverLng,
                ride.pickupLat!,
                ride.pickupLng!,
              );
              return dist <= maxDistanceKm;
            }).toList();
          },
        );
  }

  /// Get this driver's active bid for a specific ride.
  Future<BidModel?> getActiveBidForRide(String rideId) async {
    final uid = _uid;
    if (uid == null) return null;
    final snap = await _bidsCol(rideId)
        .where('driverUid', isEqualTo: uid)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    return BidModel.fromDoc(snap.docs.first);
  }

  /// Place a bid on a ride.
  Future<String> placeBid({
    required String rideId,
    required String driverName,
    required double offerNaira,
    required int etaMinutes,
    String? vehicleName,
    double? driverRating,
    int? driverRides,
  }) async {
    final uid = _uid;
    if (uid == null) throw Exception('Not signed in.');
    final callable = _functions.httpsCallable('createDriverBid');
    final response = await callable.call<Map<String, dynamic>>({
      'rideId': rideId,
      'offerNaira': offerNaira,
      'etaMinutes': etaMinutes,
      'driverName': driverName,
      'vehicleName': vehicleName,
      'driverRating': driverRating,
      'driverRides': driverRides,
    });
    final bidId = response.data['bidId'] as String?;
    if (bidId == null || bidId.isEmpty) {
      throw Exception('Unable to create bid.');
    }
    return bidId;
  }

  /// Stream a single bid document.
  Stream<BidModel?> streamBid(String rideId, String bidId) {
    return _bidsCol(rideId).doc(bidId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return BidModel.fromDoc(doc);
    });
  }

  /// Stream all bids where this driver's bid was accepted.
  Stream<List<BidModel>> streamMyActiveBids() {
    final uid = _uid;
    if (uid == null) return Stream.value([]);

    return _firestore
        .collectionGroup('offers')
        .where('driverUid', isEqualTo: uid)
        .where('status', isEqualTo: 'accepted')
        .snapshots()
        .map((snap) => snap.docs.map(BidModel.fromDoc).toList());
  }

  /// Stream the assigned ride for this driver (en-route, arrived, or started).
  Stream<RideModel?> streamAssignedRide() {
    final uid = _uid;
    if (uid == null) return Stream.value(null);

    return _ridesCol
        .where('driverUid', isEqualTo: uid)
        .where('status', whereIn: ['driverEnRoute', 'driverArrived', 'rideStarted'])
        .limit(1)
        .snapshots()
        .map((snap) {
          if (snap.docs.isEmpty) return null;
          return RideModel.fromDoc(snap.docs.first);
        });
  }

  /// Stream a single ride document.
  Stream<RideModel?> streamRide(String rideId) {
    return _ridesCol.doc(rideId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return RideModel.fromDoc(doc);
    });
  }

  Future<void> updateRideStatus(String rideId, String status, {String? code}) async {
    final callable = _functions.httpsCallable('updateRideStatus');
    await callable.call<Map<String, dynamic>>({
      'rideId': rideId,
      'newStatus': status,
      if (code != null) 'code': code,
    });
  }

  /// Updates ride status to 'driverArrived' and notifies the rider via Cloud Function & Firestore.
  Future<void> markDriverArrived(String rideId) async {
    await _ridesCol.doc(rideId).set({
      'status': 'driverArrived',
      'driverArrivedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    try {
      await updateRideStatus(rideId, 'driverArrived');
    } catch (_) {}
  }

  Future<void> startRide(String rideId, String code) async {
    try {
      await updateRideStatus(rideId, 'rideStarted', code: code);
    } catch (_) {}

    await _ridesCol.doc(rideId).update({
      'status': 'rideStarted',
      'rideStartedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> completeRide(String rideId, {double? finalFare}) async {
    try {
      final callable = _functions.httpsCallable('completeRide');
      await callable.call<Map<String, dynamic>>({
        'rideId': rideId,
        if (finalFare != null) 'finalFare': finalFare,
      });
    } catch (e) {
      // Direct Firestore update fallback for ride completion
      await _ridesCol.doc(rideId).update({
        'status': 'completed',
        'completedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        if (finalFare != null) 'finalFare': finalFare,
      });
    }

    // Check and award first ride cashback and trip % cashback to customer
    try {
      final rideDoc = await _ridesCol.doc(rideId).get();
      final rideData = rideDoc.data() ?? {};
      final customerUid = (rideData['customerUid'] as String?) ?? '';
      if (customerUid.isNotEmpty) {
        await CashbackService.instance.awardFirstRideCashbackIfEligible(
          customerUid: customerUid,
          rideId: rideId,
        );

        final calculatedFare = finalFare ??
            (rideData['finalFare'] as num?)?.toDouble() ??
            (rideData['amountNaira'] as num?)?.toDouble() ??
            (rideData['customerOffer'] as num?)?.toDouble() ??
            0.0;

        if (calculatedFare > 0) {
          await CashbackService.instance.awardTripCashbackIfEligible(
            customerUid: customerUid,
            rideId: rideId,
            fareAmount: calculatedFare,
          );
        }
      }
    } catch (_) {}
  }

  Future<void> rateCustomer({
    required String rideId,
    required int rating,
    String? comment,
  }) async {
    await _ridesCol.doc(rideId).update({
      'customerRating': rating,
      if (comment != null) 'customerRatingComment': comment,
      'customerRatedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Stream ride history for this driver.
  Stream<List<RideModel>> streamRideHistory() {
    final uid = _uid;
    if (uid == null) return Stream.value([]);

    return _ridesCol
        .where('driverUid', isEqualTo: uid)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(RideModel.fromDoc).toList());
  }

  Future<List<RideModel>> getRideHistory({int limit = 50}) async {
    final uid = _uid;
    if (uid == null) return [];
    final snap = await _ridesCol
        .where('driverUid', isEqualTo: uid)
        .orderBy('updatedAt', descending: true)
        .limit(limit)
        .get();
    return snap.docs.map(RideModel.fromDoc).toList();
  }
}
