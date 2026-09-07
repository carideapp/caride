import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

class AccountProfile {
  const AccountProfile({
    required this.fullName,
    required this.email,
    required this.phone,
    required this.photoUrl,
    required this.gender,
    required this.dateOfBirth,
    required this.walletBalance,
    required this.creditBalance,
    required this.referralCode,
    required this.referredByCode,
    required this.referralEarnings,
    this.paystackDedicatedAccountNumber,
    this.paystackDedicatedAccountBankName,
    this.paystackDedicatedAccountName,
  });

  final String fullName;
  final String email;
  final String phone;
  final String photoUrl;
  final String gender;
  final String dateOfBirth;
  final double walletBalance;
  final double creditBalance;
  final String referralCode;
  final String? referredByCode;
  final double referralEarnings;
  final String? paystackDedicatedAccountNumber;
  final String? paystackDedicatedAccountBankName;
  final String? paystackDedicatedAccountName;

  factory AccountProfile.fromMap(Map<String, dynamic> data) {
    return AccountProfile(
      fullName: (data['fullName'] as String?) ?? '',
      email: (data['email'] as String?) ?? '',
      phone: (data['phone'] as String?) ?? '',
      photoUrl: (data['photoUrl'] as String?) ?? '',
      gender: (data['gender'] as String?) ?? '',
      dateOfBirth: (data['dateOfBirth'] as String?) ?? '',
      walletBalance: (data['walletBalance'] as num?)?.toDouble() ?? 0.0,
      creditBalance: (data['creditBalance'] as num?)?.toDouble() ?? 0.0,
      referralCode: (data['referralCode'] as String?) ?? '',
      referredByCode: data['referredByCode'] as String?,
      referralEarnings: (data['referralEarnings'] as num?)?.toDouble() ?? 0.0,
      paystackDedicatedAccountNumber: (data['paystackDedicatedAccountNumber'] as String?) ??
          (data['paystackVirtualAccount'] as Map<dynamic, dynamic>?)?['accountNumber'] as String?,
      paystackDedicatedAccountBankName: (data['paystackDedicatedAccountBankName'] as String?) ??
          (data['paystackVirtualAccount'] as Map<dynamic, dynamic>?)?['bankName'] as String?,
      paystackDedicatedAccountName: (data['paystackDedicatedAccountName'] as String?) ??
          (data['paystackVirtualAccount'] as Map<dynamic, dynamic>?)?['accountName'] as String?,
    );
  }
}

class AccountRepository {
  AccountRepository({
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
        return FirebaseStorage.instanceFor(bucket: 'gs://caride-app.firebasestorage.app');
      } catch (_) {
        return FirebaseStorage.instanceFor(bucket: 'caride-app.firebasestorage.app');
      }
    }
  }

  String? get _uid => _auth.currentUser?.uid;

  DocumentReference<Map<String, dynamic>> get _userDoc =>
      _firestore.collection('customers').doc(_uid);

  /// Watches the full profile in real time.
  Stream<AccountProfile?> watchProfile() {
    if (_uid == null) return Stream.value(null);
    return _userDoc.snapshots().map((doc) {
      if (!doc.exists) return null;
      return AccountProfile.fromMap(doc.data() ?? {});
    });
  }

  /// Watches only the wallet balance for the header card.
  ///
  /// **DEPRECATED** — Use [watchProfile] instead and read
  /// [AccountProfile.walletBalance]. Opening this stream creates a second
  /// Firestore listener on the same document as [watchProfile], doubling
  /// the read cost for no benefit.
  @Deprecated('Use watchProfile().map((p) => p?.walletBalance ?? 0.0) instead')
  Stream<double> watchWalletBalance() {
    if (_uid == null) return Stream.value(0.0);
    return _userDoc.snapshots().map((doc) {
      final data = doc.data() ?? {};
      return (data['walletBalance'] as num?)?.toDouble() ?? 0.0;
    });
  }

  /// Uploads a profile photo and returns its download URL.
  Future<String> uploadProfilePhoto(File imageFile) async {
    if (_uid == null) throw Exception('Not signed in.');
    final ref = _storage.ref('customer_profile_photos/$_uid/profile_photo.jpg');
    await ref.putFile(
      imageFile,
      SettableMetadata(contentType: 'image/jpeg'),
    );
    return ref.getDownloadURL();
  }

  /// Creates the initial profile document after signup.
  Future<void> createProfile({
    required String fullName,
    required String phone,
    required String photoUrl,
  }) async {
    if (_uid == null) throw Exception('Not signed in.');
    final email = _auth.currentUser?.email ?? '';
    await _userDoc.set({
      'fullName': fullName.trim(),
      'phone': phone.trim(),
      'email': email,
      'photoUrl': photoUrl,
      'gender': '',
      'dateOfBirth': '',
      'walletBalance': 0.0,
      'referralCode': '',
      'referralEarnings': 0.0,
      'profileCompleted': true,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Persists updated profile fields to Firestore.
  Future<void> updateProfile({
    required String fullName,
    required String phone,
    String? photoUrl,
  }) async {
    if (_uid == null) throw Exception('Not signed in.');
    final updates = <String, dynamic>{
      'fullName': fullName.trim(),
      'phone': phone.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (photoUrl != null) updates['photoUrl'] = photoUrl;
    await _userDoc.update(updates);
  }

  /// Applies a referral code by checking both customers and drivers collections.
  Future<String> applyReferralCode(String referralCode) async {
    final uid = _uid;
    if (uid == null) throw Exception('Not signed in.');

    final cleanCode = referralCode.trim();
    final codeLower = cleanCode.toLowerCase();
    final codeUpper = cleanCode.toUpperCase();

    // 1. Check current profile to see if user already applied a code
    final userSnap = await _userDoc.get();
    final userData = userSnap.data() ?? {};
    final existingReferredBy = userData['referredByCode'] as String?;
    if (existingReferredBy != null && existingReferredBy.isNotEmpty) {
      throw Exception('You have already applied a referral code.');
    }

    final myReferralCode = (userData['referralCode'] as String?) ?? '';
    if (myReferralCode.isNotEmpty && myReferralCode.toLowerCase() == codeLower) {
      throw Exception('You cannot use your own referral code.');
    }

    // 2. Try primary Cloud Function (us-east1 region)
    try {
      final functions = FirebaseFunctions.instanceFor(region: 'us-east1');
      final callable = functions.httpsCallable('applyReferralCode');
      final result = await callable.call<Map<String, dynamic>>({
        'referralCode': cleanCode,
      });
      return (result.data['message'] as String?) ?? 'Referral code applied successfully!';
    } catch (e) {
      if (e is FirebaseFunctionsException) {
        rethrow;
      }
    }

    // 3. Fallback client-side search across customers, drivers, and staff
    final custSnapLower = await _firestore
        .collection('customers')
        .where('referralCodeLower', isEqualTo: codeLower)
        .limit(1)
        .get();

    final custSnapLegacy = custSnapLower.docs.isNotEmpty
        ? custSnapLower
        : await _firestore
            .collection('customers')
            .where('referralCode', isEqualTo: codeUpper)
            .limit(1)
            .get();

    DocumentSnapshot<Map<String, dynamic>>? referrerDoc;
    String referrerType = 'customer';

    if (custSnapLegacy.docs.isNotEmpty) {
      referrerDoc = custSnapLegacy.docs.first;
    } else {
      final driverSnapLower = await _firestore
          .collection('drivers')
          .where('referralCodeLower', isEqualTo: codeLower)
          .limit(1)
          .get();

      final driverSnapLegacy = driverSnapLower.docs.isNotEmpty
          ? driverSnapLower
          : await _firestore
              .collection('drivers')
              .where('referralCode', isEqualTo: codeUpper)
              .limit(1)
              .get();

      if (driverSnapLegacy.docs.isNotEmpty) {
        referrerDoc = driverSnapLegacy.docs.first;
        referrerType = 'driver';
      } else {
        final staffSnapLower = await _firestore
            .collection('staff')
            .where('referralCodeLower', isEqualTo: codeLower)
            .limit(1)
            .get();

        final staffSnapLegacy = staffSnapLower.docs.isNotEmpty
            ? staffSnapLower
            : await _firestore
                .collection('staff')
                .where('referralCode', isEqualTo: codeUpper)
                .limit(1)
                .get();

        if (staffSnapLegacy.docs.isNotEmpty) {
          referrerDoc = staffSnapLegacy.docs.first;
          referrerType = 'staff';
        }
      }
    }

    if (referrerDoc == null) {
      throw Exception('The referral code entered does not exist. Please check and try again.');
    }

    if (referrerDoc.id == uid) {
      throw Exception('You cannot use your own referral code.');
    }

    final config = await fetchReferralCreditConfig();
    final creditAmt = (config['creditAmount'] as num?)?.toDouble() ?? 1000.0;

    await _userDoc.set({
      'referredByCode': codeUpper,
      'creditBalance': FieldValue.increment(creditAmt),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (referrerType == 'staff') {
      await _firestore.collection('staff').doc(referrerDoc.id).collection('referrals').doc(uid).set({
        'referredUid': uid,
        'userType': 'customer',
        'email': _auth.currentUser?.email ?? '',
        'referralCode': codeUpper,
        'joinedAt': FieldValue.serverTimestamp(),
      });

      await _firestore.collection('staff').doc(referrerDoc.id).set({
        'stats.totalReferrals': FieldValue.increment(1),
        'stats.customersReferred': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } else {
      final targetColl = referrerType == 'driver' ? 'drivers' : 'customers';
      await _firestore.collection(targetColl).doc(referrerDoc.id).collection('referrals').doc(uid).set({
        'referredUid': uid,
        'email': _auth.currentUser?.email ?? '',
        'status': 'completed',
        'rewardAmount': creditAmt,
        'joinedAt': FieldValue.serverTimestamp(),
      });

      await _firestore.collection(targetColl).doc(referrerDoc.id).set({
        'referralEarnings': FieldValue.increment(creditAmt),
        'successfulReferralsCount': FieldValue.increment(1),
      }, SetOptions(merge: true));
    }

    return 'Referral code applied successfully! ₦${creditAmt.toStringAsFixed(0)} credit added to your wallet.';
  }

  /// Fetches current referral credit configuration (creditAmount & creditAmountChargePercent).
  Future<Map<String, dynamic>> fetchReferralCreditConfig() async {
    try {
      final snap = await _firestore.collection('config').doc('referralSettings').get();
      if (snap.exists && snap.data() != null) {
        return {
          'creditAmount': (snap.data()!['creditAmount'] as num?)?.toDouble() ?? 1000.0,
          'creditAmountChargePercent': (snap.data()!['creditAmountChargePercent'] as num?)?.toDouble() ?? 10.0,
          'isPromotionActive': snap.data()!['isPromotionActive'] != false,
        };
      }
    } catch (_) {}
    return {
      'creditAmount': 1000.0,
      'creditAmountChargePercent': 10.0,
      'isPromotionActive': true,
    };
  }
}
