import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:caride/core/driver/models/driver_profile.dart';
import 'package:caride/core/driver/models/vehicle_info.dart';
import 'package:caride/core/driver/models/vehicle_review.dart';

class DriverProfileRepository {
  DriverProfileRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _driversCol =>
      _firestore.collection('drivers');

  Future<void> createDriverProfile({
    required String uid,
    required String email,
  }) async {
    final now = FieldValue.serverTimestamp();
    final ref = _driversCol.doc(uid);
    final snapshot = await ref.get();
    if (!snapshot.exists) {
      await ref.set({
        'uid': uid,
        'email': email,
        'role': 'driver',
        'fullName': '',
        'phone': '',
        'profilePhotoUrl': '',
        'isEmailVerified': true,
        'profileCompleted': false,
        'approvalStatus': 'draft',
        'rejectionReason': null,
        'walletBalance': 0,
        // Tier system — defaults to bronze on registration
        'tier': 'bronze',
        'completedRides': 0,
        'averageRating': 0.0,
        'totalRatings': 0,
        // Referral system
        'referralCode': '',
        'referralEarnings': 0,
        'referredByCode': null,
        'createdAt': now,
        'updatedAt': now,
      });
    }
  }

  Future<DriverProfile?> getDriverProfile(String uid) async {
    final doc = await _driversCol.doc(uid).get();
    if (!doc.exists) return null;
    return DriverProfile.fromDoc(doc);
  }

  Stream<DriverProfile?> streamDriverProfile(String uid) {
    return _driversCol.doc(uid).snapshots().map((doc) {
      if (!doc.exists) return null;
      return DriverProfile.fromDoc(doc);
    });
  }

  Future<String?> getApprovalStatus(String uid) async {
    final doc = await _driversCol.doc(uid).get();
    return doc.data()?['approvalStatus'] as String?;
  }

  Future<void> updateBasicInfo({
    required String uid,
    String? fullName,
    String? phone,
    String? username,
    String? country,
    String? state,
    String? profilePhotoUrl,
    String? coverPhotoUrl,
  }) async {
    final data = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (fullName != null) data['fullName'] = fullName;
    if (phone != null) data['phone'] = phone;
    if (username != null) data['username'] = username;
    if (country != null) data['country'] = country;
    if (state != null) data['state'] = state;
    if (profilePhotoUrl != null) data['profilePhotoUrl'] = profilePhotoUrl;
    if (coverPhotoUrl != null) data['coverPhotoUrl'] = coverPhotoUrl;
    await _driversCol.doc(uid).update(data);
  }

  Future<void> updateVehicleInfo({
    required String uid,
    required VehicleInfo vehicleInfo,
  }) async {
    final vehicleCol = _driversCol.doc(uid).collection('vehicle');
    final approvedRef = vehicleCol.doc('info');
    final reviewRef = vehicleCol.doc('review');
    final approvedSnap = await approvedRef.get();

    await reviewRef.set({
      'status': 'pending',
      'newValues': vehicleInfo.toMap(),
      'oldValues': approvedSnap.exists ? approvedSnap.data() : null,
      'submittedAt': FieldValue.serverTimestamp(),
      'reviewedAt': null,
      'reviewedByAdminUid': null,
      'rejectionReason': null,
    });
    await _driversCol.doc(uid).update({
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<VehicleInfo?> getApprovedVehicleInfo(String uid) async {
    final doc = await _driversCol.doc(uid).collection('vehicle').doc('info').get();
    if (!doc.exists) return null;
    return VehicleInfo.fromDoc(doc);
  }

  Future<VehicleInfo?> getVehicleInfo(String uid) async {
    final review = await getVehicleReview(uid);
    if (review != null) return review.newValues;
    return getApprovedVehicleInfo(uid);
  }

  Stream<VehicleInfo?> streamVehicleInfo(String uid) {
    return _driversCol
        .doc(uid)
        .collection('vehicle')
        .doc('review')
        .snapshots()
        .asyncMap((reviewDoc) async {
          if (reviewDoc.exists) {
            return VehicleReview.fromDoc(reviewDoc).newValues;
          }
          return getApprovedVehicleInfo(uid);
        });
  }

  Future<VehicleReview?> getVehicleReview(String uid) async {
    final doc = await _driversCol.doc(uid).collection('vehicle').doc('review').get();
    if (!doc.exists) return null;
    return VehicleReview.fromDoc(doc);
  }

  Stream<VehicleReview?> streamVehicleReview(String uid) {
    return _driversCol
        .doc(uid)
        .collection('vehicle')
        .doc('review')
        .snapshots()
        .map((doc) {
          if (!doc.exists) return null;
          return VehicleReview.fromDoc(doc);
        });
  }

  Future<void> markProfileCompleted(String uid) async {
    await _driversCol.doc(uid).update({
      'profileCompleted': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> submitApplication(String uid) async {
    await _driversCol.doc(uid).update({
      'profileCompleted': true,
      'approvalStatus': 'pending',
      'applicationSubmittedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
