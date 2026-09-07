import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PaymentMethod {
  const PaymentMethod({
    required this.id,
    required this.type,
    required this.name,
    required this.isDefault,
  });

  final String id;

  /// One of: 'wallet', 'cash', 'card'
  final String type;
  final String name;
  final bool isDefault;

  factory PaymentMethod.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return PaymentMethod(
      id: doc.id,
      type: (data['type'] as String?) ?? 'cash',
      name: (data['name'] as String?) ?? 'Cash',
      isDefault: (data['isDefault'] as bool?) ?? false,
    );
  }

  /// Built-in default methods always available (wallet only).
  static List<PaymentMethod> get builtInMethods => const [
        PaymentMethod(
          id: 'wallet',
          type: 'wallet',
          name: 'CaRide Wallet',
          isDefault: true,
        ),
      ];
}

class PaymentRepository {
  PaymentRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  String? get _uid => _auth.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> get _paymentCol =>
      _firestore.collection('customers').doc(_uid).collection('paymentMethods');

  /// Watches user's saved card methods (merged with built-ins).
  Stream<List<PaymentMethod>> watchPaymentMethods() {
    if (_uid == null) return Stream.value(PaymentMethod.builtInMethods);
    return _paymentCol
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snap) {
      final savedCards = snap.docs.map(PaymentMethod.fromDoc).toList();
      return [...PaymentMethod.builtInMethods, ...savedCards];
    });
  }

  /// Adds a new card payment method.
  Future<void> addCard({required String name}) async {
    if (_uid == null) throw Exception('Not signed in.');
    await _paymentCol.add({
      'type': 'card',
      'name': name.trim(),
      'isDefault': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Removes a saved card (cannot remove built-ins).
  Future<void> deletePaymentMethod(String id) async {
    if (_uid == null) throw Exception('Not signed in.');
    await _paymentCol.doc(id).delete();
  }
}
