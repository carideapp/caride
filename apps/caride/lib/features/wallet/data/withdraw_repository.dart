import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:caride/core/config/app_env.dart';

/// A bank option (code + display name).
class BankOption {
  const BankOption({required this.code, required this.name});
  final String code;
  final String name;
}

/// Result of resolving an account number against a bank.
class ResolvedAccount {
  const ResolvedAccount({
    required this.accountName,
    required this.accountNumber,
    required this.bankCode,
    required this.bankName,
  });
  final String accountName;
  final String accountNumber;
  final String bankCode;
  final String bankName;
}

class WithdrawRepository {
  WithdrawRepository({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _functions = functions ??
            FirebaseFunctions.instanceFor(
                region: AppEnv.firebaseFunctionsRegion),
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;
  final FirebaseAuth _auth;

  String? get _uid => _auth.currentUser?.uid;

  // ── Bank list ────────────────────────────────────────────────────────
  Future<List<BankOption>> fetchBanks() async {
    try {
      final result = await _functions
          .httpsCallable('listTransactPayBanks')
          .call<Map<String, dynamic>>();

      final data = result.data;
      final rows = data['banks'] as List<dynamic>? ?? const <dynamic>[];
      final banks = rows
          .map((row) => BankOption(
                code: (row as Map)['code'] as String? ?? '',
                name: row['name'] as String? ?? '',
              ))
          .where((b) => b.code.isNotEmpty && b.name.isNotEmpty)
          .toList(growable: false);
      banks.sort((a, b) => a.name.compareTo(b.name));
      return banks;
    } catch (e) {
      debugPrint('fetchBanks failed: $e — using fallback list');
    }
    // Comprehensive fallback list
    return const <BankOption>[
      BankOption(code: '044', name: 'Access Bank'),
      BankOption(code: '100', name: 'Opay'),
      BankOption(code: '999', name: 'Kuda Bank'),
      BankOption(code: '998', name: 'Palmpay'),
      BankOption(code: '063', name: 'Access Bank (Diamond)'),
      BankOption(code: '050', name: 'Ecobank'),
      BankOption(code: '070', name: 'Fidelity Bank'),
      BankOption(code: '011', name: 'First Bank'),
      BankOption(code: '214', name: 'First City Monument Bank'),
      BankOption(code: '058', name: 'GTBank'),
      BankOption(code: '030', name: 'Heritage Bank'),
      BankOption(code: '301', name: 'Jaiz Bank'),
      BankOption(code: '082', name: 'Keystone Bank'),
      BankOption(code: '526', name: 'Moniepoint'),
      BankOption(code: '101', name: 'Providus Bank'),
      BankOption(code: '076', name: 'Polaris Bank'),
      BankOption(code: '221', name: 'Stanbic IBTC Bank'),
      BankOption(code: '068', name: 'Standard Chartered'),
      BankOption(code: '232', name: 'Sterling Bank'),
      BankOption(code: '032', name: 'Union Bank'),
      BankOption(code: '033', name: 'United Bank for Africa'),
      BankOption(code: '215', name: 'Unity Bank'),
      BankOption(code: '128', name: 'VFD Microfinance Bank'),
      BankOption(code: '035', name: 'Wema Bank'),
      BankOption(code: '057', name: 'Zenith Bank'),
    ];
  }

  // ── Resolve account name ─────────────────────────────────────────────
  Future<ResolvedAccount> resolveAccount({
    required String bankCode,
    required String accountNumber,
    required String bankName,
  }) async {
    try {
      final result = await _functions
          .httpsCallable('resolveTransactPayBankAccount')
          .call<Map<String, dynamic>>({
        'bankCode': bankCode,
        'accountNumber': accountNumber,
      });

      final data = result.data;
      final accountName = data['accountName'] as String?;
      final resolvedAccountNumber = data['accountNumber'] as String?;

      if (accountName != null) {
        return ResolvedAccount(
          accountName: accountName,
          accountNumber: resolvedAccountNumber ?? accountNumber,
          bankCode: bankCode,
          bankName: bankName,
        );
      }
      throw Exception('Account name was resolved as null.');
    } catch (e) {
      debugPrint('Bank account resolution failed: $e');
      throw Exception('Could not verify account: $e');
    }
  }

  // ── Check if PIN is set ───────────────────────────────────────────────
  Future<bool> hasPinSet() async {
    final uid = _uid;
    if (uid == null) return false;
    final doc = await _firestore.collection('customers').doc(uid).get();
    return (doc.data()?['hasPinSet'] as bool?) ?? false;
  }

  // ── Process withdrawal ───────────────────────────────────────────────
  /// Verifies PIN, deducts wallet balance, and triggers TransactPay payout.
  /// Returns the transaction reference on success.
  Future<String> processWithdrawal({
    required String accountNumber,
    required String bankCode,
    required String bankName,
    required String accountName,
    required double amountNaira,
    required String pin,
  }) async {
    if (_uid == null) throw Exception('Not signed in.');

    final requestParams = <String, dynamic>{
      'accountNumber': accountNumber,
      'bankCode': bankCode,
      'bankName': bankName,
      'accountName': accountName,
      'amountNaira': amountNaira,
      'pin': pin,
    };

    logTransactPayDebug(
      action: 'DISPATCHING WITHDRAWAL TO TRANSACTPAY API',
      requestParams: requestParams,
    );

    try {
      final result = await _functions
          .httpsCallable('processCustomerWithdrawal')
          .call<Map<String, dynamic>>(requestParams);

      final data = result.data;
      logTransactPayDebug(
        action: 'SUCCESSFUL CALLABLE RESPONSE RECEIVED',
        requestParams: requestParams,
        responseData: data,
      );

      // Check if upstream returned a failure payload inside HTTP 200
      if (data['success'] == false ||
          data['status'] == false ||
          data['status'] == 'failed' ||
          data['status'] == 'error') {
        final errMsg = data['message'] ??
            data['error'] ??
            data['transactPayMessage'] ??
            'Withdrawal failed upstream in TransactPay.';

        logTransactPayDebug(
          action: 'TRANSACTPAY UPSTREAM FAILURE PAYLOAD DETECTED',
          requestParams: requestParams,
          responseData: data,
          error: errMsg,
        );

        throw WithdrawException(
          message: errMsg.toString(),
          details: data,
        );
      }

      final reference = (data['reference'] ??
          data['transactionReference'] ??
          data['txRef']) as String?;

      if (reference == null || reference.isEmpty) {
        logTransactPayDebug(
          action: 'TRANSACTPAY MISSING TRANSACTION REFERENCE',
          requestParams: requestParams,
          responseData: data,
          error: 'No reference in response',
        );

        throw WithdrawException(
          message: data['message']?.toString() ??
              'Invalid server response: No transaction reference returned.',
          details: data,
        );
      }

      return reference;
    } on FirebaseFunctionsException catch (e, stack) {
      logTransactPayDebug(
        action: 'TRANSACTPAY CALLABLE EXCEPTION (FirebaseFunctionsException)',
        requestParams: requestParams,
        error: e,
        stackTrace: stack,
      );

      throw WithdrawException(
        message: parseWithdrawError(e),
        code: e.code,
        details: e.details,
        rawError: e,
      );
    } catch (e, stack) {
      logTransactPayDebug(
        action: 'TRANSACTPAY UNEXPECTED EXCEPTION',
        requestParams: requestParams,
        error: e,
        stackTrace: stack,
      );

      if (e is WithdrawException) rethrow;
      throw WithdrawException(
        message: parseWithdrawError(e),
        rawError: e,
      );
    }
  }
}

/// Rich exception class capturing raw TransactPay API details and error codes.
class WithdrawException implements Exception {
  WithdrawException({
    required this.message,
    this.code,
    this.details,
    this.rawError,
  });

  final String message;
  final String? code;
  final dynamic details;
  final dynamic rawError;

  @override
  String toString() => message;
}

/// Formats and logs high-visibility TransactPay API diagnostic messages directly to terminal console.
void logTransactPayDebug({
  required String action,
  Map<String, dynamic>? requestParams,
  dynamic responseData,
  dynamic error,
  StackTrace? stackTrace,
}) {
  debugPrint('╔═══════════════════════════════════════════════════════════════════════════');
  debugPrint('║ 💳 [TRANSACTPAY DEBUG CONSOLE] $action');
  debugPrint('╠═══════════════════════════════════════════════════════════════════════════');
  debugPrint('║ 🕒 Time: ${DateTime.now().toIso8601String()}');

  if (requestParams != null && requestParams.isNotEmpty) {
    debugPrint('╟───────────────────────────────────────────────────────────────────────────');
    debugPrint('║ 📤 REQUEST SENT:');
    requestParams.forEach((k, v) {
      if (k.toLowerCase() == 'pin') {
        debugPrint('║   • $k: **** (${v.toString().length} digits)');
      } else {
        debugPrint('║   • $k: $v');
      }
    });
  }

  if (responseData != null) {
    debugPrint('╟───────────────────────────────────────────────────────────────────────────');
    debugPrint('║ 📥 RESPONSE RECEIVED:');
    final respLines = responseData.toString().split('\n');
    for (final line in respLines) {
      debugPrint('║   $line');
    }
  }

  if (error != null) {
    debugPrint('╟───────────────────────────────────────────────────────────────────────────');
    debugPrint('║ ❌ ERROR DETAILS:');
    if (error is FirebaseFunctionsException) {
      debugPrint('║   • FirebaseFunctionsException Code: ${error.code}');
      debugPrint('║   • FirebaseFunctionsException Message: ${error.message}');
      debugPrint('║   • TransactPay Details: ${error.details}');
    } else if (error is WithdrawException) {
      debugPrint('║   • WithdrawException Code: ${error.code}');
      debugPrint('║   • WithdrawException Message: ${error.message}');
      debugPrint('║   • TransactPay Details: ${error.details}');
      debugPrint('║   • Raw Error: ${error.rawError}');
    } else {
      debugPrint('║   • Raw Error: $error');
    }
    if (stackTrace != null) {
      debugPrint('║ 📍 StackTrace: $stackTrace');
    }
  }
  debugPrint('╚═══════════════════════════════════════════════════════════════════════════');
}

/// Parses raw backend/network errors into human-readable UI messages per AGENTS.md.
String parseWithdrawError(dynamic error) {
  if (error is WithdrawException) {
    if (error.details != null && error.details is Map) {
      final detailsMap = error.details as Map;
      final tpMsg = detailsMap['transactPayMessage'] ??
          detailsMap['message'] ??
          detailsMap['error'] ??
          detailsMap['upstreamError'];
      if (tpMsg != null && tpMsg.toString().isNotEmpty) {
        final lower = tpMsg.toString().toLowerCase();
        if (lower.contains('allowable ips') || lower.contains('ip')) {
          return 'Gateway IP restriction: TransactPay rejected this server IP. Please ensure the proxy IP is whitelisted in TransactPay.';
        }
        return tpMsg.toString();
      }
    }
    return error.message;
  }

  final msg = error.toString().toLowerCase();
  if (error is FirebaseFunctionsException) {
    if (error.code == 'permission-denied' || msg.contains('incorrect security pin')) {
      return 'Incorrect security PIN. Please double-check your 4-digit PIN and try again.';
    }
    if (error.code == 'failed-precondition' || msg.contains('insufficient wallet balance')) {
      return 'Insufficient wallet balance to complete this withdrawal.';
    }
    if (error.code == 'invalid-argument') {
      return 'Invalid account details or withdrawal amount. Please check your input.';
    }
    if (msg.contains('allowable ips not found') || msg.contains('ip') || msg.contains('whitelisted')) {
      return 'Withdrawal service is currently undergoing gateway configuration maintenance. Please try again shortly or contact support.';
    }
    if (error.message != null && error.message!.isNotEmpty) {
      return error.message!;
    }
  }
  if (msg.contains('allowable ips not found') || msg.contains('ip') || msg.contains('whitelisted')) {
    return 'Withdrawal service is currently undergoing gateway configuration maintenance. Please try again shortly or contact support.';
  }
  if (msg.contains('network') || msg.contains('connection') || msg.contains('socketexception') || msg.contains('timeout')) {
    return 'Connection failure. Please check your internet connection and try again.';
  }
  if (msg.contains('account name was resolved as null') || msg.contains('could not verify account')) {
    return 'Could not verify account details. Please check the account number and selected bank.';
  }
  return error.toString().replaceAll(RegExp(r'^(Exception|FirebaseFunctionsException):\s*'), '');
}

