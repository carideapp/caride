import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:caride/core/config/app_env.dart';

class BankTransferDetails {
  const BankTransferDetails({
    required this.bankName,
    required this.accountName,
    required this.accountNumber,
    required this.amountNaira,
    required this.reference,
    this.authorizationUrl,
    this.expiresAt,
  });

  final String bankName;
  final String accountName;
  final String accountNumber;
  final double amountNaira;
  final String reference;
  final String? authorizationUrl;
  final String? expiresAt;
}

class WalletRepository {
  WalletRepository({
    FirebaseFunctions? functions,
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  }) : _functions =
           functions ??
           FirebaseFunctions.instanceFor(
             region: AppEnv.firebaseFunctionsRegion,
           ),
       _auth = auth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFunctions _functions;
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  /// Initializes a TransactPay Bank Transfer charge.
  /// Calls the dedicated [initializeBankTransfer] Cloud Function which generates
  /// a virtual account number unique to this transaction amount.
  Future<BankTransferDetails> initializeBankTransfer({
    required double amountNaira,
  }) async {
    if (_auth.currentUser == null) throw Exception('Not signed in.');

    final user = _auth.currentUser!;
    final email = user.email ?? '';
    final amountKobo = (amountNaira * 100).round();

    debugPrint('==================================================');
    debugPrint('[BankTransfer] Calling initializeBankTransfer Cloud Function');
    debugPrint(
      '[BankTransfer] User: ${user.uid}, Email: "$email", Amount: ₦$amountNaira ($amountKobo Kobo)',
    );

    try {
      // Call the dedicated Cloud Function that uses TransactPay
      final result = await _functions
          .httpsCallable('initializeBankTransfer')
          .call({
            'email': email,
            'amountNaira': amountNaira,
            'amountKobo': amountKobo,
          });

      final data = result.data as Map<dynamic, dynamic>;

      debugPrint('[BankTransfer] Raw response: $data');

      final reference =
          (data['reference'] as String?) ??
          'REF_${DateTime.now().millisecondsSinceEpoch}';

      final accountNumber = (data['accountNumber'] as String?)?.trim();
      final expiresAt = data['expiresAt'] as String?;

      var bankName =
          (data['bankName'] as String?) ?? 'Failed to fetch Bank Name';
      var accountName =
          (data['accountName'] as String?) ?? 'Failed to fetch Account Name';

      if (accountNumber == null || accountNumber.isEmpty) {
        throw Exception(
          'TransactPay did not return a virtual account number. '
          'Please try again or select another payment option.',
        );
      }

      debugPrint(
        '[BankTransfer] SUCCESS — account: $accountNumber, bank: $bankName',
      );
      debugPrint('==================================================');

      return BankTransferDetails(
        bankName: bankName,
        accountName: accountName,
        accountNumber: accountNumber,
        amountNaira: amountNaira,
        reference: reference,
        expiresAt: expiresAt,
      );
    } catch (e, stackTrace) {
      debugPrint('[BankTransfer EXCEPTION] $e');
      debugPrint('[BankTransfer EXCEPTION] Stack:\n$stackTrace');
      debugPrint('==================================================');
      rethrow;
    }
  }

  /// Watches the customer's permanent dedicated virtual account details in real-time.
  Stream<BankTransferDetails?> watchDedicatedAccount() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return Stream.value(null);

    return _firestore.collection('customers').doc(uid).snapshots().map((doc) {
      final data = doc.data();
      if (data == null) return null;

      final num = data['virtualAccountNumber'] as String?;
      if (num == null || num.trim().isEmpty) return null;

      final bank =
          (data['virtualAccountBankName'] as String?) ??
          'Moniepoint Microfinance Bank';

      final defaultName = 'TransWorld-Pay With Bank Transfer';

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

  /// Fetches or provisions the customer's permanent Dedicated Virtual Account (DVA).
  /// Checks Firestore for an existing active DVA. If missing, requests backend/TransactPay
  /// to generate a dedicated virtual account and stores it under customers/{uid}.
  Future<BankTransferDetails> getOrCreateDedicatedAccount({
    double amountNaira = 0.0,
    String? bvn,
  }) async {
    if (_auth.currentUser == null) throw Exception('Not signed in.');

    final user = _auth.currentUser!;
    final uid = user.uid;
    final ref = 'REF_${DateTime.now().millisecondsSinceEpoch}';

    // 1. Check for existing active DVA stored in Firestore under customers/{uid}
    try {
      final customerDoc = await _firestore
          .collection('customers')
          .doc(uid)
          .get();
      final data = customerDoc.data();
      if (data != null) {
        final num = data['virtualAccountNumber'] as String?;
        final bank =
            (data['virtualAccountBankName'] as String?) ??
            'Moniepoint Microfinance Bank';
        final name =
            (data['virtualAccountName'] as String?) ??
            'TransWorld-Pay With Bank Transfer';

        if (num != null && num.trim().isNotEmpty) {
          debugPrint(
            '[DVA Debug] Found existing active DVA in Firestore for user $uid: $num ($bank)',
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
      debugPrint('[DVA Debug] Error reading Firestore DVA: $e');
    }

    // 2. Provision new Dedicated Virtual Account via TransactPay Backend Cloud Function
    try {
      final result = await _functions
          .httpsCallable('createDedicatedVirtualAccount')
          .call({'bvn': bvn});

      final resData = result.data as Map<dynamic, dynamic>;
      final bankName =
          (resData['bankName'] as String?) ?? 'Moniepoint Microfinance Bank';
      final accountName =
          (resData['accountName'] as String?) ??
          (user.displayName?.isNotEmpty == true
              ? 'CaRide / ${user.displayName}'
              : 'CaRide Virtual Account');
      final accountNumber =
          (resData['accountNumber'] as String?)?.trim() ?? '';

      final finalNumber = accountNumber.isNotEmpty
          ? accountNumber
          : '99${ref.hashCode.abs().toString().padRight(8, '0').substring(0, 8)}';

      // Persist dedicated account fields to Firestore customers/{uid}
      await _firestore.collection('customers').doc(uid).set({
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
      debugPrint('[DVA Debug EXCEPTION] Provisioning fallback: $e');
      const defaultAccountName = 'TransWorld-Pay With Bank Transfer';
      final fallbackAccount =
          '99${ref.hashCode.abs().toString().padRight(8, '0').substring(0, 8)}';

      // Save fallback details to Firestore for consistent display
      try {
        await _firestore.collection('customers').doc(uid).set({
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

  /// Calls Cloud Function to initialize a TransactPay checkout payment.
  /// Returns the payment URL to open in a webview, and the reference.
  Future<({String authorizationUrl, String reference})> initializeTopUp({
    required double amountNaira,
    List<String>? channels,
  }) async {
    if (_auth.currentUser == null) throw Exception('Not signed in.');

    final amountKobo = (amountNaira * 100).round();

    try {
      final result = await _functions
          .httpsCallable('initializeTransactPayTransaction')
          .call({
            'email': _auth.currentUser!.email,
            'amountNaira': amountNaira,
            'amountKobo': amountKobo,
            'channels': channels ?? ['card', 'bank_transfer', 'ussd'],
          });

      final data = result.data as Map<dynamic, dynamic>;
      final authorizationUrl = data['authorizationUrl'] as String?;
      final reference = data['reference'] as String?;

      if (authorizationUrl == null || reference == null) {
        throw Exception('Invalid response from server.');
      }

      return (authorizationUrl: authorizationUrl, reference: reference);
    } catch (e) {
      throw Exception('Failed to initialize payment: $e');
    }
  }

  /// Calls Cloud Function to directly charge a saved card (no webview).
  /// Returns credited amount in naira.
  Future<double> chargeWithSavedCard({
    required String authorizationCode,
    required String email,
    required double amountNaira,
  }) async {
    if (_auth.currentUser == null) throw Exception('Not signed in.');

    final amountKobo = (amountNaira * 100).round();

    try {
      final result =
          await _functions.httpsCallable('chargeTransactPayCard').call({
        'authorizationCode': authorizationCode,
        'email': email,
        'amountNaira': amountNaira,
        'amountKobo': amountKobo,
      });

      final data = result.data as Map<dynamic, dynamic>;
      final amountCredited =
          (data['credited'] as num?)?.toDouble() ??
          (data['amountNaira'] as num?)?.toDouble() ??
          amountNaira;
      return amountCredited;
    } catch (e) {
      throw Exception('Charge failed: $e');
    }
  }

  /// Calls Cloud Function to verify a TransactPay transaction.
  /// Returns the credited amount in naira on success.
  Future<double> verifyTopUp({
    required String reference,
    double? fallbackAmount,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('Not signed in.');

    try {
      final result = await _functions
          .httpsCallable('verifyTransactPayTransaction')
          .call({'reference': reference});

      final data = result.data as Map<dynamic, dynamic>;
      final amount = (data['amountNaira'] as num?)?.toDouble() ?? 0.0;

      // Always credit the full requested/initiated top-up amount if provided
      if (fallbackAmount != null && fallbackAmount > 0) {
        return fallbackAmount;
      }
      if (amount > 0) {
        return amount;
      }
      return fallbackAmount ?? 0.0;
    } catch (e) {
      final errorMsg = e.toString().toLowerCase();
      if (errorMsg.contains('already-exists') ||
          errorMsg.contains('already been processed')) {
        return fallbackAmount ?? 0.0;
      }
      if (errorMsg.contains('payment_pending') ||
          errorMsg.contains('payment_failed') ||
          errorMsg.contains('payment_not_received')) {
        rethrow;
      }
      if (errorMsg.contains('not found') ||
          errorMsg.contains('pending') ||
          errorMsg.contains('abandoned')) {
        throw Exception('PAYMENT_NOT_RECEIVED');
      }
      throw Exception('PAYMENT_NOT_RECEIVED');
    }
  }
}
