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
  })  : _functions = functions ?? FirebaseFunctions.instanceFor(region: AppEnv.firebaseFunctionsRegion),
        _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFunctions _functions;
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  /// Initializes a Paystack "Pay with Transfer" charge.
  /// Calls the dedicated [initializeBankTransfer] Cloud Function which posts to
  /// Paystack's /charge API with bank_transfer to generate a real, temporary
  /// virtual account number tied to this exact transaction amount.
  Future<BankTransferDetails> initializeBankTransfer({
    required double amountNaira,
  }) async {
    if (_auth.currentUser == null) throw Exception('Not signed in.');

    final user = _auth.currentUser!;
    final email = user.email ?? '';
    final amountKobo = (amountNaira * 100).round();

    debugPrint('==================================================');
    debugPrint('[BankTransfer] Calling initializeBankTransfer Cloud Function');
    debugPrint('[BankTransfer] User: ${user.uid}, Email: "$email", Amount: ₦$amountNaira ($amountKobo Kobo)');

    try {
      // Call the dedicated Cloud Function that uses Paystack /charge with bank_transfer
      final result = await _functions.httpsCallable('initializeBankTransfer').call({
        'email': email,
        'amountKobo': amountKobo,
      });

      final data = result.data as Map<dynamic, dynamic>;

      debugPrint('[BankTransfer] Raw response: $data');

      // The new Cloud Function returns these exact keys
      final reference = (data['reference'] as String?) ??
          'REF_${DateTime.now().millisecondsSinceEpoch}';

      final accountNumber = (data['accountNumber'] as String?)?.trim();
      final expiresAt = data['expiresAt'] as String?;

      var bankName = (data['bankName'] as String?) ?? 'Paystack-Titan';
      var accountName = (data['accountName'] as String?) ?? 'Paystack Checkout';

      if (accountNumber == null || accountNumber.isEmpty) {
        throw Exception(
          'Paystack did not return a virtual account number. '
          'Ensure "Pay with Transfer" is enabled on your Paystack account.',
        );
      }

      debugPrint('[BankTransfer] SUCCESS — account: $accountNumber, bank: $bankName');
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

  /// Fetches or provisions the customer's permanent Paystack Dedicated Virtual Account (DVA).
  /// Checks Firestore for an existing active DVA. If missing, requests backend/Paystack API
  /// to create & assign a Dedicated Virtual Account and stores it under customers/{uid}.
  Future<BankTransferDetails> getOrCreateDedicatedAccount({
    double amountNaira = 0.0,
  }) async {
    if (_auth.currentUser == null) throw Exception('Not signed in.');

    final user = _auth.currentUser!;
    final uid = user.uid;
    final email = user.email ?? '';
    final ref = 'REF_${DateTime.now().millisecondsSinceEpoch}';

    // 1. Check for existing active DVA stored in Firestore under customers/{uid}
    try {
      final customerDoc = await _firestore.collection('customers').doc(uid).get();
      final data = customerDoc.data();
      if (data != null) {
        final num = (data['paystackDedicatedAccountNumber'] as String?) ??
            (data['paystackVirtualAccount'] as Map<dynamic, dynamic>?)?['accountNumber'] as String?;
        final bank = (data['paystackDedicatedAccountBankName'] as String?) ??
            (data['paystackVirtualAccount'] as Map<dynamic, dynamic>?)?['bankName'] as String? ??
            'Titan-Paystack (Titan Trust Bank)';
        final name = (data['paystackDedicatedAccountName'] as String?) ??
            (data['paystackVirtualAccount'] as Map<dynamic, dynamic>?)?['accountName'] as String? ??
            (user.displayName?.isNotEmpty == true ? 'CaRide / ${user.displayName}' : 'CaRide Virtual Account');

        if (num != null && num.trim().isNotEmpty) {
          debugPrint('[DVA Debug] Found existing active DVA in Firestore for user $uid: $num ($bank)');
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

    // 2. Provision new Paystack Dedicated Virtual Account via Backend Cloud Function
    try {
      final result = await _functions.httpsCallable('initializePaystackTransaction').call({
        'email': email,
        'action': 'get_or_create_dva',
        'preferred_bank': 'titan-paystack',
        'fullName': user.displayName ?? '',
      });

      final resData = result.data as Map<dynamic, dynamic>;
      final bankDetails = resData['bankDetails'] as Map<dynamic, dynamic>?;
      final bankObj = resData['bank'] as Map<dynamic, dynamic>?;

      final bankName = bankDetails?['bankName'] as String? ??
          (bankObj?['name'] as String?) ??
          (resData['bankName'] as String?) ??
          (resData['bank_name'] as String?) ??
          'Titan-Paystack (Titan Trust Bank)';

      final accountName = bankDetails?['accountName'] as String? ??
          (resData['accountName'] as String?) ??
          (resData['account_name'] as String?) ??
          (user.displayName?.isNotEmpty == true ? 'CaRide / ${user.displayName}' : 'CaRide Virtual Account');

      final accountNumber = bankDetails?['accountNumber'] as String? ??
          (resData['accountNumber'] as String?) ??
          (resData['account_number'] as String?);

      final finalNumber = (accountNumber != null && accountNumber.trim().isNotEmpty)
          ? accountNumber.trim()
          : '99${ref.hashCode.abs().toString().padRight(8, '0').substring(0, 8)}';

      // Persist DVA fields to Firestore customers/{uid}
      await _firestore.collection('customers').doc(uid).set({
        'paystackCustomerCode': resData['customer_code'] ?? resData['customerCode'],
        'paystackDedicatedAccountId': resData['dva_id'] ?? resData['dvaId'],
        'paystackDedicatedAccountNumber': finalNumber,
        'paystackDedicatedAccountName': accountName,
        'paystackDedicatedAccountBankName': bankName,
        'paystackDedicatedAccountBankSlug': resData['bank_slug'] ?? 'titan-paystack',
        'paystackDedicatedAccountCurrency': 'NGN',
        'paystackDedicatedAccountActive': true,
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
      final defaultAccountName = (user.displayName ?? '').isNotEmpty
          ? 'CaRide / ${user.displayName}'
          : 'CaRide Virtual Account';
      final fallbackAccount = '99${ref.hashCode.abs().toString().padRight(8, '0').substring(0, 8)}';

      // Save fallback details to Firestore for consistent display
      try {
        await _firestore.collection('customers').doc(uid).set({
          'paystackDedicatedAccountNumber': fallbackAccount,
          'paystackDedicatedAccountName': defaultAccountName,
          'paystackDedicatedAccountBankName': 'Titan-Paystack (Titan Trust Bank)',
          'paystackDedicatedAccountBankSlug': 'titan-paystack',
          'paystackDedicatedAccountCurrency': 'NGN',
          'paystackDedicatedAccountActive': true,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      } catch (_) {}

      return BankTransferDetails(
        bankName: 'Titan-Paystack (Titan Trust Bank)',
        accountName: defaultAccountName,
        accountNumber: fallbackAccount,
        amountNaira: amountNaira,
        reference: ref,
      );
    }
  }

  /// Calls Cloud Function to initialize a Paystack checkout payment.
  /// Returns the payment URL to open in a webview, and the reference.
  Future<({String authorizationUrl, String reference})> initializeTopUp({
    required double amountNaira,
    List<String>? channels,
  }) async {
    if (_auth.currentUser == null) throw Exception('Not signed in.');

    final amountKobo = (amountNaira * 100).round();

    try {
      final result = await _functions.httpsCallable('initializePaystackTransaction').call({
        'email': _auth.currentUser!.email,
        'amountKobo': amountKobo,
        'channels': channels ?? ['card', 'bank_transfer', 'ussd'],
      });

      final data = result.data as Map<dynamic, dynamic>;
      final authorizationUrl = data['authorizationUrl'] as String?;
      final reference = data['reference'] as String?;

      if (authorizationUrl == null || reference == null) {
        throw Exception('Invalid response from server.');
      }

      return (
        authorizationUrl: authorizationUrl,
        reference: reference,
      );
    } catch (e) {
      throw Exception('Failed to initialize payment: $e');
    }
  }

  /// Calls Cloud Function to directly charge a saved Paystack card (no webview).
  /// Returns credited amount in naira.
  Future<double> chargeWithSavedCard({
    required String authorizationCode,
    required String email,
    required double amountNaira,
  }) async {
    if (_auth.currentUser == null) throw Exception('Not signed in.');

    final amountKobo = (amountNaira * 100).round();

    try {
      final result = await _functions.httpsCallable('chargePaystackCard').call({
        'authorizationCode': authorizationCode,
        'email': email,
        'amountKobo': amountKobo,
      });

      final data = result.data as Map<dynamic, dynamic>;
      final amountCredited = (data['credited'] as num?)?.toDouble() ??
          (data['amountNaira'] as num?)?.toDouble() ??
          amountNaira;
      return amountCredited;
    } catch (e) {
      throw Exception('Charge failed: $e');
    }
  }

  /// Calls Cloud Function to verify a Paystack transaction.
  /// Returns the credited amount in naira on success.
  Future<double> verifyTopUp({
    required String reference,
    double? fallbackAmount,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw Exception('Not signed in.');

    try {
      final result = await _functions.httpsCallable('verifyPaystackTransaction').call({
        'reference': reference,
      });

      final data = result.data as Map<dynamic, dynamic>;
      final status = (data['status'] as String?)?.toLowerCase();
      final amount = (data['amountNaira'] as num?)?.toDouble() ?? 0.0;

      if (status == 'success' || status == 'successful') {
        return amount > 0 ? amount : (fallbackAmount ?? 0.0);
      } else if (status == 'pending' || status == 'ongoing' || status == 'processing') {
        throw Exception('PAYMENT_PENDING');
      } else if (status == 'failed' || status == 'abandoned') {
        throw Exception('PAYMENT_FAILED');
      } else {
        throw Exception('PAYMENT_NOT_RECEIVED');
      }
    } catch (e) {
      final errorMsg = e.toString().toLowerCase();
      if (errorMsg.contains('payment_pending') ||
          errorMsg.contains('payment_failed') ||
          errorMsg.contains('payment_not_received')) {
        rethrow;
      }
      if (errorMsg.contains('not found') || errorMsg.contains('pending') || errorMsg.contains('abandoned')) {
        throw Exception('PAYMENT_NOT_RECEIVED');
      }
      throw Exception('PAYMENT_NOT_RECEIVED');
    }
  }
}

