import 'package:cloud_firestore/cloud_firestore.dart';

enum WalletTxType { credit, debit }

class WalletTransaction {
  const WalletTransaction({
    required this.id,
    required this.type,
    required this.rawType,
    required this.reference,
    required this.amountNaira,
    required this.method,
    required this.description,
    required this.createdAt,
  });

  final String id;
  final WalletTxType type;
  final String rawType;
  final String reference;
  final double amountNaira;
  final String method;
  final String description;
  final DateTime createdAt;

  factory WalletTransaction.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    final typeStr = (data['type'] as String?)?.trim().toLowerCase() ?? '';
    final descStr = (data['description'] as String?)?.trim().toLowerCase() ?? '';
    final isCredit = typeStr == 'credit' || 
                     typeStr == 'referral' || 
                     descStr.contains('referral');
                     
    return WalletTransaction(
      id: doc.id,
      type: isCredit ? WalletTxType.credit : WalletTxType.debit,
      rawType: typeStr,
      reference: (data['reference'] as String?) ?? (data['rideId'] as String?) ?? '',
      amountNaira: (data['amountNaira'] as num?)?.toDouble() ?? 0,
      method: (data['method'] as String?) ?? '',
      description: (data['description'] as String?) ?? '',
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

class WalletTransactionRepository {
  WalletTransactionRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;



  /// Streams the latest 50 wallet transactions for this user.
  Stream<List<WalletTransaction>> watchTransactions(String uid) {
    if (uid.isEmpty) return Stream.value(const []);
    return _firestore
        .collection('walletTransactions')
        .where('uid', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snap) => snap.docs.map(WalletTransaction.fromDoc).toList());
  }
}
