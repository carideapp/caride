import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/services/deep_link_service.dart';

class ReferralRecord {
  const ReferralRecord({
    required this.referralCode,
    required this.referralLink,
    required this.referralEarnings,
    required this.successfulReferralsCount,
    required this.pendingReferralsCount,
    required this.referredUsers,
    required this.referralPercent,
  });

  final String referralCode;
  final String referralLink;
  final double referralEarnings;
  final int successfulReferralsCount;
  final int pendingReferralsCount;
  final List<ReferredUser> referredUsers;
  final double referralPercent;
}

class ReferredUser {
  const ReferredUser({
    required this.email,
    required this.status,
    required this.rewardAmount,
    required this.joinedAt,
  });

  final String email;
  final String status;
  final double rewardAmount;
  final DateTime joinedAt;
}

class ReferralRepository {
  ReferralRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  String? get _uid => _auth.currentUser?.uid;

  DocumentReference<Map<String, dynamic>> get _userDoc =>
      _firestore.collection('customers').doc(_uid);

  String _generateReferralCode() {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rand = Random();
    return List.generate(6, (index) => chars[rand.nextInt(chars.length)]).join();
  }

  Future<String> ensureReferralCode() async {
    final doc = await _userDoc.get();
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
          .collection('customers')
          .where('referralCodeLower', isEqualTo: codeLower)
          .limit(1)
          .get();
      if (existing.docs.isEmpty) {
        final driverExisting = await _firestore
            .collection('drivers')
            .where('referralCodeLower', isEqualTo: codeLower)
            .limit(1)
            .get();
        if (driverExisting.docs.isEmpty) {
          unique = true;
          break;
        }
      }
      generated = _generateReferralCode();
      attempts++;
    }
    await _userDoc.set({
      'referralCode': generated,
      'referralCodeLower': generated.toLowerCase(),
    }, SetOptions(merge: true));
    return generated;
  }

  /// Watches the referral code, earnings, and list of referred users.
  Stream<ReferralRecord?> watchReferralData() {
    if (_uid == null) return Stream.value(null);

    return _userDoc.snapshots().asyncMap((profileSnap) async {
      final profileData = profileSnap.data() ?? {};
      final referralCode = (profileData['referralCode'] as String?) ?? await ensureReferralCode();
      final referralEarnings =
          (profileData['referralEarnings'] as num?)?.toDouble() ?? 0.0;
      final storedSuccessfulCount =
          (profileData['successfulReferralsCount'] as num?)?.toInt();
      final storedPendingCount =
          (profileData['pendingReferralsCount'] as num?)?.toInt() ?? 0;

      final referralsSnap = await _userDoc
          .collection('referrals')
          .orderBy('joinedAt', descending: true)
          .get();

      int completedCount = 0;
      int pendingCount = storedPendingCount;

      final referredUsers = referralsSnap.docs.map((doc) {
        final data = doc.data();
        final status = (data['status'] as String?) ?? 'completed';
        if (status == 'completed') {
          completedCount++;
        } else if (status == 'pending') {
          pendingCount++;
        }
        return ReferredUser(
          email: (data['email'] as String?) ?? '',
          status: status,
          rewardAmount: (data['rewardAmount'] as num?)?.toDouble() ?? 0.0,
          joinedAt: (data['joinedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        );
      }).toList();

      final successfulCount = storedSuccessfulCount ?? completedCount;
      final referralLink = DeepLinkService.instance.generateReferralLink(referralCode);

      double referralPercent = 2.0;
      try {
        final settingsSnap = await _firestore.collection('config').doc('referralSettings').get();
        if (settingsSnap.exists) {
          referralPercent = (settingsSnap.data()?['customerReferralPercent'] as num?)?.toDouble() ?? 2.0;
        }
      } catch (e) {
        // Fallback
      }

      return ReferralRecord(
        referralCode: referralCode,
        referralLink: referralLink,
        referralEarnings: referralEarnings,
        successfulReferralsCount: successfulCount,
        pendingReferralsCount: pendingCount,
        referredUsers: referredUsers,
        referralPercent: referralPercent,
      );
    });
  }

  /// Updates the user's referral code after validating case-insensitive uniqueness and format.
  Future<void> updateCustomReferralCode(String newCode) async {
    final cleanCode = newCode.trim();
    final codeLower = cleanCode.toLowerCase();
    if (cleanCode.length < 3 || cleanCode.length > 12) {
      throw Exception('Referral code must be between 3 and 12 characters long.');
    }
    if (!RegExp(r'^[a-zA-Z0-9]+$').hasMatch(cleanCode)) {
      throw Exception('Referral code can only contain letters and numbers.');
    }

    // Check customer collection for duplicate (case-insensitive)
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

    // Check driver collection for duplicate (case-insensitive)
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

    await _userDoc.set({
      'referralCode': cleanCode,
      'referralCodeLower': codeLower,
    }, SetOptions(merge: true));
  }
}

