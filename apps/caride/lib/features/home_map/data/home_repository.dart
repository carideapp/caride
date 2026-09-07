import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HomeRepository {
  HomeRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  Stream<List<String>> watchSavedLocations() {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      return Stream.value(const []);
    }
    return _firestore
        .collection('customers')
        .doc(uid)
        .collection('savedAddresses')
        .orderBy('updatedAt', descending: true)
        .limit(10)
        .snapshots()
        .map((snap) {
          return snap.docs
              .map((doc) => (doc.data()['label'] as String?) ?? '')
              .where((label) => label.isNotEmpty)
              .toList(growable: false);
        });
  }
}
