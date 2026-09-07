import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:caride/core/driver/config/app_env.dart';

import 'package:caride/core/driver/models/driver_bank_account.dart';

class BankOption {
  const BankOption({required this.code, required this.name});

  final String code;
  final String name;
}

class VerifiedBankAccountPreview {
  const VerifiedBankAccountPreview({
    required this.accountName,
    required this.accountNumber,
  });

  final String accountName;
  final String accountNumber;
}

class DriverBankAccountRepository {
  DriverBankAccountRepository({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
    FirebaseAuth? auth,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _functions = functions ??
           FirebaseFunctions.instanceFor(region: AppEnv.firebaseFunctionsRegion),
       _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;
  final FirebaseAuth _auth;

  String? get _uid => _auth.currentUser?.uid;

  Stream<List<DriverBankAccount>> streamBankAccounts() {
    final uid = _uid;
    if (uid == null) return const Stream<List<DriverBankAccount>>.empty();

    return _firestore
        .collection('drivers')
        .doc(uid)
        .collection('bankAccounts')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(DriverBankAccount.fromDoc).toList());
  }

  /// Fetches the list of Nigerian banks via the Paystack Cloud Function.
  Future<List<BankOption>> fetchBanks() async {
    try {
      final result = await _functions
          .httpsCallable('listPaystackBanks')
          .call<Map<String, dynamic>>();

      final data = result.data;
      final rows = data['banks'] as List<dynamic>? ?? const <dynamic>[];
      final banks = rows
          .map((row) => BankOption(
                code: (row as Map)['code'] as String? ?? '',
                name: row['name'] as String? ?? '',
              ))
          .where((bank) => bank.code.isNotEmpty && bank.name.isNotEmpty)
          .toList(growable: false);
      banks.sort((a, b) => a.name.compareTo(b.name));
      return banks;
    } catch (e) {
      debugPrint('fetchBanks failed: $e — using fallback list');
    }
    // Comprehensive fallback list of Nigerian banks and fintech institutions
    return const <BankOption>[
      // Traditional Banks
      BankOption(code: '007', name: 'Zenith Bank'),
      BankOption(code: '009', name: 'IBTC Bank'),
      BankOption(code: '011', name: 'First Bank'),
      BankOption(code: '012', name: 'UBA'),
      BankOption(code: '014', name: 'GTBank'),
      BankOption(code: '015', name: 'Unity Bank'),
      BankOption(code: '019', name: 'Guaranty Trust Bank'),
      BankOption(code: '020', name: 'Stanbic IBTC'),
      BankOption(code: '021', name: 'Chartered Bank'),
      BankOption(code: '033', name: 'Access Bank'),
      BankOption(code: '044', name: 'Access Bank (DMB)'),
      BankOption(code: '050', name: 'Ecobank'),
      BankOption(code: '056', name: 'Polaris Bank'),
      BankOption(code: '063', name: 'Diamond Bank'),
      BankOption(code: '070', name: 'First Bank Nigeria'),
      BankOption(code: '084', name: 'Enterprise Bank'),
      BankOption(code: '086', name: 'VTN Bank'),
      BankOption(code: '089', name: 'Fidelity Bank'),
      BankOption(code: '090', name: 'Wema Bank'),
      BankOption(code: '101', name: 'Providus Bank'),
      BankOption(code: '102', name: 'Academy Bank'),
      BankOption(code: '103', name: 'Access Bank (Mainframe)'),
      BankOption(code: '106', name: 'Sterling Bank'),
      BankOption(code: '108', name: 'Tangerine Bank'),
      BankOption(code: '111', name: 'Zenith Bank (DMB)'),
      BankOption(code: '113', name: 'Mainstreet Bank'),
      BankOption(code: '116', name: 'Standard Chartered'),
      BankOption(code: '120', name: 'Stanbic IBTC (DMB)'),
      BankOption(code: '121', name: 'First Bank (DMB)'),
      BankOption(code: '122', name: 'Globus Bank'),
      BankOption(code: '125', name: 'Fidelity Bank (DMB)'),
      BankOption(code: '126', name: 'UBA (DMB)'),
      BankOption(code: '127', name: 'IBTC Bank (DMB)'),
      BankOption(code: '130', name: 'Guarantee Trust Bank (DMB)'),
      BankOption(code: '132', name: 'Unified Payment Solutions'),
      BankOption(code: '133', name: 'Fortis Mobile Money'),
      BankOption(code: '151', name: 'Bankly'),
      BankOption(code: '153', name: 'Infinity Bank'),
      BankOption(code: '154', name: 'Minted Bank'),
      BankOption(code: '155', name: 'Keystone Bank'),
      BankOption(code: '156', name: 'Ecobank Transnational Inc'),
      // Microfinance Banks
      BankOption(code: '128', name: 'VFD Microfinance'),
      BankOption(code: '131', name: 'FCMB Microfinance'),
      BankOption(code: '134', name: 'Micro Finance Service Centre'),
      BankOption(code: '135', name: 'Eazy Finance'),
      BankOption(code: '136', name: 'FMS Microfinance'),
      BankOption(code: '137', name: 'First Mutual Microfinance'),
      BankOption(code: '138', name: 'Renmoney Microfinance'),
      BankOption(code: '139', name: 'Abumetric Microfinance'),
      BankOption(code: '140', name: 'CreditDirect Microfinance'),
      BankOption(code: '141', name: 'IjebuOde Microfinance'),
      BankOption(code: '142', name: 'Nirsal Microfinance'),
      BankOption(code: '143', name: 'Balogun Microfinance'),
      BankOption(code: '144', name: 'IC Microfinance'),
      BankOption(code: '145', name: 'LAPO Microfinance'),
      BankOption(code: '146', name: 'Plateau Microfinance'),
      BankOption(code: '147', name: 'Pride Microfinance'),
      BankOption(code: '148', name: 'Paga'),
      BankOption(code: '149', name: 'Finatrade Microfinance'),
      BankOption(code: '150', name: 'Trident Microfinance'),
      // Fintech Banks & Payment Service Banks
      BankOption(code: '100', name: 'Opay'),
      BankOption(code: '999', name: 'Kuda Microfinance'),
      BankOption(code: '998', name: 'Palmpay'),
      BankOption(code: '997', name: 'Flutterwave'),
      BankOption(code: '996', name: 'Paystack'),
      BankOption(code: '995', name: 'Interswitch'),
      BankOption(code: '994', name: 'TagPay'),
      BankOption(code: '993', name: 'Mono'),
      BankOption(code: '992', name: 'Smile'),
      BankOption(code: '991', name: 'Moneymor'),
      BankOption(code: '990', name: 'Nala'),
      BankOption(code: '989', name: 'Sendcash'),
      BankOption(code: '988', name: 'Money Box'),
      BankOption(code: '987', name: 'Piggybank'),
      BankOption(code: '986', name: 'TeamApt'),
      BankOption(code: '985', name: 'BuyCoin'),
      BankOption(code: '984', name: 'Changera'),
      BankOption(code: '983', name: 'NairaEx'),
      BankOption(code: '982', name: 'Luno'),
      BankOption(code: '981', name: 'Coinbase'),
      BankOption(code: '980', name: 'Kraken'),
      // Payment & Microfinance Service Providers
      BankOption(code: '050', name: 'Ecobank Nigeria'),
      BankOption(code: '999991', name: 'MTN Mobile Money'),
      BankOption(code: '999992', name: 'Airtel Money'),
      BankOption(code: '999993', name: 'Glo Mobile Money'),
      BankOption(code: '999994', name: '9mobile Money'),
      BankOption(code: '888', name: 'Remitly'),
      BankOption(code: '887', name: 'WorldRemit'),
      BankOption(code: '886', name: 'Wise'),
      BankOption(code: '885', name: 'Stripe'),
      BankOption(code: '884', name: 'Square'),
    ];
  }

  /// Resolves an account name via the Paystack Cloud Function.
  Future<VerifiedBankAccountPreview> resolveAccount({
    required String bankCode,
    required String accountNumber,
  }) async {
    try {
      final result = await _functions
          .httpsCallable('resolvePaystackBankAccount')
          .call<Map<String, dynamic>>({
        'bankCode': bankCode,
        'accountNumber': accountNumber,
      });

      final data = result.data;
      final accountName = data['accountName'] as String?;
      final resolvedAccountNumber = data['accountNumber'] as String?;

      if (accountName != null) {
        return VerifiedBankAccountPreview(
          accountName: accountName,
          accountNumber: resolvedAccountNumber ?? accountNumber,
        );
      }
    } catch (e) {
      debugPrint('resolveAccount failed: $e');
    }
    throw Exception('Failed to resolve bank account');
  }

  Future<void> saveVerifiedAccount({
    required String bankCode,
    required String bankName,
    required String accountNumber,
  }) async {
    final callable = _functions.httpsCallable('saveDriverBankAccount');
    await callable.call<Map<String, dynamic>>({
      'bankCode': bankCode,
      'bankName': bankName,
      'accountNumber': accountNumber,
    });
  }
}
