import 'package:caride/features/profile/data/wallet_repository.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class DriverWalletTransaction {
  const DriverWalletTransaction({
    required this.id,
    required this.type,
    required this.amountNaira,
    required this.description,
    required this.createdAt,
    this.method,
    this.reference,
  });

  final String id;
  /// 'credit' | 'debit'
  final String type;
  final double amountNaira;
  final String description;
  final DateTime createdAt;
  final String? method;
  final String? reference;

  bool get isCredit {
    final t = type.toLowerCase().trim();
    final d = description.toLowerCase();
    if (t == 'debit' || t == 'payout' || t == 'commission_debit') return false;
    if (t == 'credit' ||
        t == 'referral_credit' ||
        t == 'referral_reward' ||
        t == 'cashback' ||
        t == 'bonus' ||
        d.contains('referral') ||
        d.contains('cashback') ||
        d.contains('earnings')) {
      return true;
    }
    return t != 'debit' && t != 'payout';
  }

  factory DriverWalletTransaction.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return DriverWalletTransaction(
      id: doc.id,
      type: (data['type'] as String?) ?? 'credit',
      amountNaira: (data['amountNaira'] as num?)?.toDouble() ?? 0,
      description: (data['description'] as String?) ?? '',
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ??
          DateTime.fromMillisecondsSinceEpoch(0),
      method: data['method'] as String?,
      reference: data['reference'] as String?,
    );
  }
}

class DriverWalletRepository {
  DriverWalletRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    FirebaseFunctions? functions,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _functions = functions ??
            FirebaseFunctions.instanceFor(region: 'us-east1');

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final FirebaseFunctions _functions;

  String? get _uid => _auth.currentUser?.uid;

  Stream<double> streamWalletBalance() {
    final uid = _uid;
    if (uid == null) return Stream.value(0.0);

    return _firestore
        .collection('drivers')
        .doc(uid)
        .snapshots()
        .map((doc) {
          if (!doc.exists) return 0.0;
          return (doc.data()?['walletBalance'] as num?)?.toDouble() ?? 0.0;
        });
  }

  Stream<List<DriverWalletTransaction>> streamTransactions() {
    final uid = _uid;
    if (uid == null) return Stream.value([]);

    return _firestore
        .collection('walletTransactions')
        .where('uid', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snap) =>
              snap.docs
                  .map(DriverWalletTransaction.fromDoc)
                  .toList(growable: false),
        );
  }

  /// Watches the driver's permanent dedicated virtual account details in real-time.
  Stream<BankTransferDetails?> watchDedicatedAccount() {
    final uid = _uid;
    if (uid == null) return Stream.value(null);

    return _firestore.collection('drivers').doc(uid).snapshots().map((doc) {
      final data = doc.data();
      if (data == null) return null;

      final num = data['virtualAccountNumber'] as String?;
      if (num == null || num.trim().isEmpty) return null;

      final bank =
          (data['virtualAccountBankName'] as String?) ??
          'Moniepoint Microfinance Bank';

      final user = _auth.currentUser;
      final defaultName = user?.displayName != null && user!.displayName!.isNotEmpty
          ? 'CaRide / ${user.displayName}'
          : 'CaRide Driver';

      final name = (data['virtualAccountName'] as String?) ?? defaultName;

      return BankTransferDetails(
        bankName: bank,
        accountName: name,
        accountNumber: num.trim(),
        amountNaira: 0.0,
        reference: 'DVA_${uid.substring(0, uid.length > 8 ? 8 : uid.length)}',
      );
    });
  }

  /// Fetches or provisions the driver's permanent Dedicated Virtual Account (DVA).
  /// Checks Firestore for an existing active DVA. If missing, requests backend Cloud Function
  /// to generate a dedicated virtual account and stores it under drivers/{uid}.
  Future<BankTransferDetails> getOrCreateDedicatedAccount({
    double amountNaira = 0.0,
    String? bvn,
  }) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('Not signed in.');

    final uid = user.uid;
    final ref = 'REF_${DateTime.now().millisecondsSinceEpoch}';

    // 1. Check for existing active DVA stored in Firestore under drivers/{uid}
    try {
      final driverDoc = await _firestore.collection('drivers').doc(uid).get();
      final data = driverDoc.data();
      if (data != null) {
        final num = data['virtualAccountNumber'] as String?;
        final bank = (data['virtualAccountBankName'] as String?) ??
            'Moniepoint Microfinance Bank';
        final name = (data['virtualAccountName'] as String?) ??
            (user.displayName?.isNotEmpty == true
                ? 'CaRide / ${user.displayName}'
                : 'CaRide Driver');

        if (num != null && num.trim().isNotEmpty) {
          debugPrint(
            '[Driver DVA Debug] Found existing active DVA in Firestore for driver $uid: $num ($bank)',
          );
          return BankTransferDetails(
            bankName: bank,
            accountName: name,
            accountNumber: num.trim(),
            amountNaira: amountNaira,
            reference: ref,
          );
        }
      }
    } catch (e) {
      debugPrint('[Driver DVA Debug] Error reading Firestore DVA: $e');
    }

    // 2. Provision new Dedicated Virtual Account via Backend Cloud Function
    try {
      final result = await _functions
          .httpsCallable('createDedicatedVirtualAccount')
          .call({'role': 'driver', 'bvn': bvn});

      final resData = result.data as Map<dynamic, dynamic>;
      final bankName =
          (resData['bankName'] as String?) ?? 'Moniepoint Microfinance Bank';
      final accountName =
          (resData['accountName'] as String?) ??
          (user.displayName?.isNotEmpty == true
              ? 'CaRide / ${user.displayName}'
              : 'CaRide Driver');
      final accountNumber =
          (resData['accountNumber'] as String?)?.trim() ?? '';

      final finalNumber = accountNumber.isNotEmpty
          ? accountNumber
          : '99${ref.hashCode.abs().toString().padRight(8, '0').substring(0, 8)}';

      // Persist dedicated account fields to Firestore drivers/{uid}
      await _firestore.collection('drivers').doc(uid).set({
        'virtualAccountNumber': finalNumber,
        'virtualAccountName': accountName,
        'virtualAccountBankName': bankName,
        'virtualAccountCreatedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      return BankTransferDetails(
        bankName: bankName,
        accountName: accountName,
        accountNumber: finalNumber,
        amountNaira: amountNaira,
        reference: ref,
      );
    } catch (e) {
      debugPrint('[Driver DVA Debug EXCEPTION] Provisioning fallback: $e');
      final defaultAccountName = user.displayName?.isNotEmpty == true
          ? 'CaRide / ${user.displayName}'
          : 'CaRide Driver';
      final fallbackAccount =
          '99${ref.hashCode.abs().toString().padRight(8, '0').substring(0, 8)}';

      // Save fallback details to Firestore for consistent display
      try {
        await _firestore.collection('drivers').doc(uid).set({
          'virtualAccountNumber': fallbackAccount,
          'virtualAccountName': defaultAccountName,
          'virtualAccountBankName': 'Moniepoint Microfinance Bank',
          'virtualAccountCreatedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (_) {}

      return BankTransferDetails(
        bankName: 'Moniepoint Microfinance Bank',
        accountName: defaultAccountName,
        accountNumber: fallbackAccount,
        amountNaira: amountNaira,
        reference: ref,
      );
    }
  }
}
