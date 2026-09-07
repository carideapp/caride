import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// A saved Paystack card token stored for a user.
class SavedCard {
  const SavedCard({
    required this.id,
    required this.last4,
    required this.brand,
    required this.authorizationCode,
    required this.email,
  });

  final String id;
  final String last4;
  final String brand;
  final String authorizationCode;
  final String email;

  factory SavedCard.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return SavedCard(
      id: doc.id,
      last4: (data['last4'] as String?) ?? '****',
      brand: (data['brand'] as String?) ?? 'Card',
      authorizationCode: (data['authorizationCode'] as String?) ?? '',
      email: (data['email'] as String?) ?? '',
    );
  }
}

class CardRepository {
  CardRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  String? get _uid => _auth.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> get _cardsCol =>
      _firestore.collection('customers').doc(_uid).collection('savedCards');

  /// Watches saved cards in real time.
  Stream<List<SavedCard>> watchSavedCards() {
    if (_uid == null) return Stream.value(const []);
    return _cardsCol
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snap) => snap.docs.map(SavedCard.fromDoc).toList());
  }

  /// Persists a Paystack-returned card authorization to Firestore.
  Future<void> saveCard({
    required String authorizationCode,
    required String last4,
    required String brand,
    required String email,
  }) async {
    if (_uid == null) throw Exception('Not signed in.');
    await _cardsCol.add({
      'authorizationCode': authorizationCode,
      'last4': last4,
      'brand': brand,
      'email': email,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Removes a saved card.
  Future<void> deleteCard(String cardId) async {
    if (_uid == null) throw Exception('Not signed in.');
    await _cardsCol.doc(cardId).delete();
  }
}
