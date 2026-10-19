import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:caride/core/config/app_env.dart';
import 'package:caride/core/models/ride_viewer.dart';

/// A live bid from a driver on a ride request.
class DriverBid {
  const DriverBid({
    required this.id,
    required this.driverUid,
    required this.driverName,
    required this.driverRating,
    required this.driverRides,
    required this.vehicleName,
    required this.offerNaira,
    required this.etaMinutes,
    required this.expiresAt,
    required this.status,
  });

  final String id;
  final String driverUid;
  final String driverName;
  final double driverRating;
  final int driverRides;
  final String vehicleName;
  final double offerNaira;
  final int etaMinutes;
  final DateTime expiresAt;
  final String status;

  bool get isExpired => DateTime.now().isAfter(expiresAt) || status == 'expired';

  factory DriverBid.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return DriverBid.fromMap(id: doc.id, data: data);
  }

  factory DriverBid.fromMap({
    required String id,
    required Map<String, dynamic> data,
  }) {
    return DriverBid(
      id: id,
      driverUid: (data['driverUid'] as String?) ?? '',
      driverName: (data['driverName'] as String?) ?? 'Driver',
      driverRating: (data['driverRating'] as num?)?.toDouble() ?? 0.0,
      driverRides: (data['driverRides'] as num?)?.toInt() ?? 0,
      vehicleName: (data['vehicleName'] as String?) ?? '',
      offerNaira: (data['offerNaira'] as num?)?.toDouble() ?? 0,
      etaMinutes: (data['etaMinutes'] as num?)?.toInt() ?? 5,
      expiresAt:
          (data['expiresAt'] as Timestamp?)?.toDate() ??
          DateTime.now().add(const Duration(seconds: 30)),
      status: (data['status'] as String?) ?? 'pending',
    );
  }
}

/// A ride document from Firestore.
class RideModel {
  const RideModel({
    required this.id,
    required this.customerUid,
    required this.status,
    required this.pickupLabel,
    this.pickupLat,
    this.pickupLng,
    required this.dropoffLabel,
    this.dropoffLat,
    this.dropoffLng,
    required this.rideType,
    required this.customerOffer,
    this.amountNaira,
    required this.paymentMethod,
    this.paymentStatus,
    this.driverUid,
    this.driverName,
    this.driverRating,
    this.driverRatingComment,
    this.finalFare,
    this.ratedAt,
    this.createdAt,
    this.acceptedAt,
    this.completedAt,
    this.startCode,
    this.receiverName,
    this.receiverPhone,
    this.deliveryPin,
  });

  final String id;
  final String customerUid;
  final String status;
  final String pickupLabel;
  final double? pickupLat;
  final double? pickupLng;
  final String dropoffLabel;
  final double? dropoffLat;
  final double? dropoffLng;
  final String rideType;
  final double customerOffer;
  final double? amountNaira;
  final String paymentMethod;
  final String? paymentStatus;
  final String? driverUid;
  final String? driverName;
  final int? driverRating;
  final String? driverRatingComment;
  final double? finalFare;
  final DateTime? ratedAt;
  final DateTime? createdAt;
  final DateTime? acceptedAt;
  final DateTime? completedAt;
  final String? startCode;
  final String? receiverName;
  final String? receiverPhone;
  /// 4-digit PIN for delivery confirmation at dropoff (Send Items only).
  final String? deliveryPin;

  RideModel copyWith({
    String? id,
    String? customerUid,
    String? status,
    String? pickupLabel,
    double? pickupLat,
    double? pickupLng,
    String? dropoffLabel,
    double? dropoffLat,
    double? dropoffLng,
    String? rideType,
    double? customerOffer,
    double? amountNaira,
    String? paymentMethod,
    String? paymentStatus,
    String? driverUid,
    String? driverName,
    int? driverRating,
    String? driverRatingComment,
    double? finalFare,
    DateTime? ratedAt,
    DateTime? createdAt,
    DateTime? acceptedAt,
    DateTime? completedAt,
    String? startCode,
    String? receiverName,
    String? receiverPhone,
    String? deliveryPin,
  }) {
    return RideModel(
      id: id ?? this.id,
      customerUid: customerUid ?? this.customerUid,
      status: status ?? this.status,
      pickupLabel: pickupLabel ?? this.pickupLabel,
      pickupLat: pickupLat ?? this.pickupLat,
      pickupLng: pickupLng ?? this.pickupLng,
      dropoffLabel: dropoffLabel ?? this.dropoffLabel,
      dropoffLat: dropoffLat ?? this.dropoffLat,
      dropoffLng: dropoffLng ?? this.dropoffLng,
      rideType: rideType ?? this.rideType,
      customerOffer: customerOffer ?? this.customerOffer,
      amountNaira: amountNaira ?? this.amountNaira,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      driverUid: driverUid ?? this.driverUid,
      driverName: driverName ?? this.driverName,
      driverRating: driverRating ?? this.driverRating,
      driverRatingComment: driverRatingComment ?? this.driverRatingComment,
      finalFare: finalFare ?? this.finalFare,
      ratedAt: ratedAt ?? this.ratedAt,
      createdAt: createdAt ?? this.createdAt,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      completedAt: completedAt ?? this.completedAt,
      startCode: startCode ?? this.startCode,
      receiverName: receiverName ?? this.receiverName,
      receiverPhone: receiverPhone ?? this.receiverPhone,
      deliveryPin: deliveryPin ?? this.deliveryPin,
    );
  }

  factory RideModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return RideModel.fromMap(id: doc.id, data: data);
  }

  factory RideModel.fromMap({
    required String id,
    required Map<String, dynamic> data,
  }) {
    final rawDriverRating = data['driverRating'];
    final int? driverRating = switch (rawDriverRating) {
      int v => v,
      num v => v.round(),
      _ => null,
    };
    return RideModel(
      id: id,
      customerUid: (data['customerUid'] as String?) ?? '',
      status: (data['status'] as String?) ?? 'requested',
      pickupLabel:
          (data['pickupLabel'] as String?) ??
          (data['pickupName'] as String?) ??
          '',
      pickupLat: (data['pickupLat'] as num?)?.toDouble(),
      pickupLng: (data['pickupLng'] as num?)?.toDouble(),
      dropoffLabel:
          (data['dropoffLabel'] as String?) ??
          (data['dropoffName'] as String?) ??
          '',
      dropoffLat: (data['dropoffLat'] as num?)?.toDouble(),
      dropoffLng: (data['dropoffLng'] as num?)?.toDouble(),
      rideType: (data['rideType'] as String?) ?? 'Regular',
      customerOffer: (data['customerOffer'] as num?)?.toDouble() ?? 0,
      amountNaira: (data['amountNaira'] as num?)?.toDouble(),
      paymentMethod: (data['paymentMethod'] as String?) ?? 'cash',
      paymentStatus: (((data['paymentMethod'] as String?) ?? 'cash').trim().toLowerCase() == 'cash' &&
              ((data['status'] as String?) ?? 'requested') == 'completed')
          ? 'paid'
          : (data['paymentStatus'] as String?),
      driverUid: data['driverUid'] as String?,
      driverName: data['driverName'] as String?,
      driverRating: driverRating,
      driverRatingComment: data['driverRatingComment'] as String?,
      finalFare: (data['finalFare'] as num?)?.toDouble(),
      ratedAt: (data['ratedAt'] as Timestamp?)?.toDate(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      acceptedAt: (data['acceptedAt'] as Timestamp?)?.toDate(),
      completedAt: (data['completedAt'] as Timestamp?)?.toDate(),
      startCode: data['startCode'] as String?,
      receiverName: data['receiverName'] as String?,
      receiverPhone: data['receiverPhone'] as String?,
      deliveryPin: data['deliveryPin'] as String?,
    );
  }
}

class RideRepository {
  RideRepository({
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

  Future<String> createRideRequest({
    required String pickupLabel,
    required double pickupLat,
    required double pickupLng,
    required String dropoffLabel,
    required double dropoffLat,
    required double dropoffLng,
    required String rideType,
    required double customerOffer,
    required String paymentMethod,
    bool useCreditWallet = false,
    String? receiverName,
    String? receiverPhone,
    String? promoCode,
    String? deliveryPin,
  }) async {
    if (_uid == null) throw Exception('Not signed in.');
    final doc = _ridesCol.doc();
    final startCode = (1000 + Random().nextInt(9000)).toString();
    await doc.set({
      'customerUid': _uid,
      'status': 'requested',
      'updatedAt': FieldValue.serverTimestamp(),
      'pickupLabel': pickupLabel,
      'pickupName': pickupLabel,
      'pickupLat': pickupLat,
      'pickupLng': pickupLng,
      'dropoffLabel': dropoffLabel,
      'dropoffName': dropoffLabel,
      'dropoffLat': dropoffLat,
      'dropoffLng': dropoffLng,
      'rideType': rideType,
      'customerOffer': customerOffer,
      'amountNaira': customerOffer,
      'paymentMethod': paymentMethod,
      'useCreditWallet': useCreditWallet,
      'paymentStatus': 'pending',
      'startCode': startCode,
      'createdAt': FieldValue.serverTimestamp(),
      'receiverName': receiverName,
      'receiverPhone': receiverPhone,
      if (promoCode != null) 'promoCode': promoCode,
      if (deliveryPin != null) 'deliveryPin': deliveryPin,
    });
    return doc.id;
  }

  /// Updates the passenger's broadcast offer on an active requested/bidding ride.
  Future<void> updateCustomerOffer({
    required String rideId,
    required double newOfferNaira,
  }) async {
    await _ridesCol.doc(rideId).update({
      'customerOffer': newOfferNaira,
      'amountNaira': newOfferNaira,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Watches a single ride document in real time.
  Stream<RideModel?> watchRide(String rideId) {
    return _ridesCol.doc(rideId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return RideModel.fromDoc(doc);
    });
  }

  /// Watches all live driver bids for a ride, ordered by price ascending.
  Stream<List<DriverBid>> watchBids(String rideId) {
    return _bidsCol(rideId)
        .orderBy('offerNaira')
        .snapshots()
        .map((snap) => snap.docs.map(DriverBid.fromDoc).toList());
  }

  /// Accepts a driver bid: sets ride status to driverEnRoute, stores driver
  /// info, initialises the rideMessages thread, and declines all other bids.
  Future<void> acceptBid({
    required String rideId,
    required DriverBid bid,
  }) async {
    if (_uid == null) throw Exception('Not signed in.');
    final callable = _functions.httpsCallable('respondToBid');
    await callable.call<Map<dynamic, dynamic>>({
      'rideId': rideId,
      'bidId': bid.id,
      'action': 'accept',
    });
  }

  /// Sends a counter-offer back to a specific driver bid.
  Future<void> counterBid({
    required String rideId,
    required String bidId,
    required double counterAmountNaira,
  }) async {
    await _bidsCol(rideId).doc(bidId).update({
      'counterOffer': counterAmountNaira,
      'updatedAt': FieldValue.serverTimestamp(),
      'counterAt': FieldValue.serverTimestamp(),
    });
  }

  /// Declines a single driver bid (marks it so driver knows).
  Future<void> declineBid({
    required String rideId,
    required String bidId,
  }) async {
    await _bidsCol(rideId).doc(bidId).update({
      'status': 'declined',
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Cancels the entire ride request.
  Future<void> cancelRide(String rideId, {String? reason}) async {
    final callable = _functions.httpsCallable('cancelRideByCustomer');
    await callable.call<Map<dynamic, dynamic>>({
      'rideId': rideId,
      if (reason != null) 'reason': reason,
    });
  }

  Stream<RideModel?> streamActiveRide() {
    final uid = _uid;
    if (uid == null) return Stream.value(null);
    return _ridesCol
        .where('customerUid', isEqualTo: uid)
        .where(
          'status',
          whereIn: ['requested', 'bidding', 'driverEnRoute', 'driverArrived', 'rideStarted'],
        )
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots()
        .map((snap) => snap.docs.isEmpty ? null : RideModel.fromDoc(snap.docs.first));
  }

  Future<void> rateDriver({
    required String rideId,
    required int rating,
    String? comment,
  }) async {
    await _ridesCol.doc(rideId).update({
      'driverRating': rating,
      if (comment != null && comment.isNotEmpty) 'driverRatingComment': comment,
      'updatedAt': FieldValue.serverTimestamp(),
      'ratedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Returns the last N completed rides (used for home suggestions).
  Future<List<String>> recentDropoffLabels({int limit = 5}) async {
    if (_uid == null) return [];
    final snap = await _ridesCol
        .where('customerUid', isEqualTo: _uid)
        .where('status', isEqualTo: 'completed')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    return snap.docs
        .map((d) => (d.data()['dropoffLabel'] as String?) ?? '')
        .where((s) => s.isNotEmpty)
        .toList();
  }

  /// Streams real-time viewers for a ride request.
  /// Filters out viewers whose presence has not been updated within 30 seconds.
  Stream<List<RideViewer>> watchRideViewers(String rideId) {
    return _ridesCol
        .doc(rideId)
        .collection('viewers')
        .snapshots()
        .map((snap) {
      final now = DateTime.now();
      final viewers = snap.docs.map(RideViewer.fromDoc).where((v) {
        if (v.updatedAt == null) return true;
        return now.difference(v.updatedAt!).inSeconds < 35;
      }).toList();
      return viewers;
    });
  }

  /// Updates driver presence for viewing a ride request.
  Future<void> updateDriverRideViewerPresence({
    required String rideId,
    required String driverUid,
    required String driverName,
    String? profilePhotoUrl,
  }) async {
    final viewerRef = _ridesCol.doc(rideId).collection('viewers').doc(driverUid);
    final data = <String, dynamic>{
      'driverName': driverName,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (profilePhotoUrl != null && profilePhotoUrl.isNotEmpty) {
      data['profilePhotoUrl'] = profilePhotoUrl;
    }
    await viewerRef.set(data, SetOptions(merge: true));
  }

  /// Removes driver presence when they leave or stop viewing a ride request.
  Future<void> removeDriverRideViewerPresence({
    required String rideId,
    required String driverUid,
  }) async {
    try {
      await _ridesCol.doc(rideId).collection('viewers').doc(driverUid).delete();
    } catch (_) {}
  }
}
