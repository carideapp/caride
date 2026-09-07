import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

  bool get isCredit => type == 'credit';

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
  DriverWalletRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

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
}
