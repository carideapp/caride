import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ReferredDriver {
  const ReferredDriver({
    required this.driverUid,
    required this.email,
    required this.joinedAt,
    this.userType = 'Customer',
    this.status = 'completed',
    this.rewardAmount = 1000.0,
  });

  final String driverUid;
  final String email;
  final DateTime joinedAt;
  final String userType;
  final String status;
  final double rewardAmount;
}

class ReferralEarningEntry {
  const ReferralEarningEntry({
    required this.id,
    required this.amountNaira,
    required this.description,
    required this.createdAt,
    this.referredDriverUid,
  });

  final String id;
  final double amountNaira;
  final String description;
  final DateTime createdAt;
  final String? referredDriverUid;
}

class DriverReferralRecord {
  const DriverReferralRecord({
    required this.referralCode,
    required this.referralEarnings,
    required this.referredDrivers,
    required this.earningHistory,
    required this.referralPercent,
  });

  final String referralCode;
  final double referralEarnings;
  final List<ReferredDriver> referredDrivers;
  final List<ReferralEarningEntry> earningHistory;
  final double referralPercent;
}

class DriverReferralRepository {
  DriverReferralRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  String? get _uid => _auth.currentUser?.uid;

  DocumentReference<Map<String, dynamic>> get _driverDoc =>
      _firestore.collection('drivers').doc(_uid);

  String _generateReferralCode() {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rand = Random();
    return List.generate(6, (index) => chars[rand.nextInt(chars.length)]).join();
  }

  Future<String> ensureReferralCode() async {
    final doc = await _driverDoc.get();
    final existingCode = doc.data()?['referralCode'] as String?;

    if (existingCode != null && existingCode.isNotEmpty) {
      return existingCode;
    }

    String generated = _generateReferralCode();
    var unique = false;
    var attempts = 0;
    while (!unique && attempts < 5) {
      final codeLower = generated.toLowerCase();
      final existing = await _firestore
          .collection('drivers')
          .where('referralCodeLower', isEqualTo: codeLower)
          .limit(1)
          .get();
      if (existing.docs.isEmpty) {
        final custExisting = await _firestore
            .collection('customers')
            .where('referralCodeLower', isEqualTo: codeLower)
            .limit(1)
            .get();
        if (custExisting.docs.isEmpty) {
          unique = true;
          break;
        }
      }
      generated = _generateReferralCode();
      attempts++;
    }
    await _driverDoc.set({
      'referralCode': generated,
      'referralCodeLower': generated.toLowerCase(),
    }, SetOptions(merge: true));
    return generated;
  }

  Future<void> updateCustomReferralCode(String newCode) async {
    final cleanCode = newCode.trim();
    final codeLower = cleanCode.toLowerCase();
    if (cleanCode.length < 3 || cleanCode.length > 12) {
      throw Exception('Referral code must be between 3 and 12 characters long.');
    }
    if (!RegExp(r'^[a-zA-Z0-9]+$').hasMatch(cleanCode)) {
      throw Exception('Referral code can only contain letters and numbers.');
    }

    // Check drivers collection for duplicate (case-insensitive)
    final driverExistingLower = await _firestore
        .collection('drivers')
        .where('referralCodeLower', isEqualTo: codeLower)
        .limit(1)
        .get();
    if (driverExistingLower.docs.isNotEmpty && driverExistingLower.docs.first.id != _uid) {
      throw Exception('This referral code is already taken. Please try another.');
    }
    final driverExistingLegacy = await _firestore
        .collection('drivers')
        .where('referralCode', isEqualTo: cleanCode)
        .limit(1)
        .get();
    if (driverExistingLegacy.docs.isNotEmpty && driverExistingLegacy.docs.first.id != _uid) {
      throw Exception('This referral code is already taken. Please try another.');
    }

    // Check customers collection for duplicate (case-insensitive)
    final custExistingLower = await _firestore
        .collection('customers')
        .where('referralCodeLower', isEqualTo: codeLower)
        .limit(1)
        .get();
    if (custExistingLower.docs.isNotEmpty && custExistingLower.docs.first.id != _uid) {
      throw Exception('This referral code is already taken. Please try another.');
    }
    final custExistingLegacy = await _firestore
        .collection('customers')
        .where('referralCode', isEqualTo: cleanCode)
        .limit(1)
        .get();
    if (custExistingLegacy.docs.isNotEmpty && custExistingLegacy.docs.first.id != _uid) {
      throw Exception('This referral code is already taken. Please try another.');
    }

    await _driverDoc.set({
      'referralCode': cleanCode,
      'referralCodeLower': codeLower,
    }, SetOptions(merge: true));
  }

  Stream<DriverReferralRecord?> watchReferralData() {
    final uid = _uid;
    if (uid == null) return Stream.value(null);

    final profileStream = _driverDoc.snapshots();

    return profileStream.asyncMap((profileSnap) async {
      final profileData = profileSnap.data() ?? {};
      final referralCode = (profileData['referralCode'] as String?) ?? '';
      final referralEarnings =
          (profileData['referralEarnings'] as num?)?.toDouble() ?? 0.0;

      final referralsSnap = await _driverDoc
          .collection('referrals')
          .orderBy('joinedAt', descending: true)
          .get();

      final referredDrivers = referralsSnap.docs.map((doc) {
        final data = doc.data();
        return ReferredDriver(
          driverUid: doc.id,
          email: (data['email'] as String?) ?? '',
          joinedAt: (data['joinedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          userType: (data['userType'] as String?) ?? (data['role'] as String?) ?? 'Customer',
          status: (data['status'] as String?) ?? 'completed',
          rewardAmount: (data['rewardAmount'] as num?)?.toDouble() ?? 1000.0,
        );
      }).toList();

      final earningsSnap = await _firestore
          .collection('walletTransactions')
          .where('uid', isEqualTo: uid)
          .where('type', isEqualTo: 'referral_credit')
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();

      final earningHistory = earningsSnap.docs.map((doc) {
        final data = doc.data();
        return ReferralEarningEntry(
          id: doc.id,
          amountNaira: (data['amountNaira'] as num?)?.toDouble() ?? 0.0,
          description: (data['description'] as String?) ?? '',
          createdAt:
              (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          referredDriverUid: data['referredDriverUid'] as String?,
        );
      }).toList();

      double referralPercent = 2.0;
      try {
        final settingsSnap = await _firestore.collection('config').doc('referralSettings').get();
        if (settingsSnap.exists) {
          referralPercent = (settingsSnap.data()?['driverReferralPercent'] as num?)?.toDouble() ?? 2.0;
        }
      } catch (e) {
        // Fallback
      }

      return DriverReferralRecord(
        referralCode: referralCode,
        referralEarnings: referralEarnings,
        referredDrivers: referredDrivers,
        earningHistory: earningHistory,
        referralPercent: referralPercent,
      );
    });
  }
}
