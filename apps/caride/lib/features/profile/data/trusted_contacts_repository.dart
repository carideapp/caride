import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// A trusted contact saved by the passenger for emergency alerts and trip sharing.
class TrustedContact {
  const TrustedContact({
    required this.id,
    required this.name,
    this.email = '',
    this.relationship = '',
    this.isActive = true,
    this.createdAt,
  });

  final String id;
  final String name;
  final String email;
  final String relationship;
  final bool isActive;
  final DateTime? createdAt;

  factory TrustedContact.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return TrustedContact(
      id: doc.id,
      name: (data['name'] as String?) ?? '',
      email: (data['email'] as String?) ?? '',
      relationship: (data['relationship'] as String?) ?? '',
      isActive: (data['isActive'] as bool?) ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  TrustedContact copyWith({
    String? name,
    String? email,
    String? relationship,
    bool? isActive,
  }) {
    return TrustedContact(
      id: id,
      name: name ?? this.name,
      email: email ?? this.email,
      relationship: relationship ?? this.relationship,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'email': email,
        'relationship': relationship,
        'isActive': isActive,
      };
}

class TrustedContactsRepository {
  TrustedContactsRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  String? get _uid => _auth.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> _contactsCol() {
    final uid = _uid;
    if (uid == null) throw Exception('Not signed in.');
    return _firestore
        .collection('customers')
        .doc(uid)
        .collection('trustedContacts');
  }

  /// Streams the list of trusted contacts in real time.
  Stream<List<TrustedContact>> watchContacts() {
    final uid = _uid;
    if (uid == null) return Stream.value([]);
    return _firestore
        .collection('customers')
        .doc(uid)
        .collection('trustedContacts')
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((snap) => snap.docs.map(TrustedContact.fromDoc).toList());
  }

  /// Returns all active trusted contacts once.
  Future<List<TrustedContact>> getActiveContacts() async {
    final uid = _uid;
    if (uid == null) return [];
    final snap = await _firestore
        .collection('customers')
        .doc(uid)
        .collection('trustedContacts')
        .where('isActive', isEqualTo: true)
        .get();
    return snap.docs.map(TrustedContact.fromDoc).toList();
  }

  /// Creates a new trusted contact.
  Future<String> addContact(TrustedContact contact) async {
    final ref = _contactsCol().doc();
    await ref.set({
      ...contact.toMap(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  /// Updates an existing trusted contact.
  Future<void> updateContact(TrustedContact contact) async {
    await _contactsCol().doc(contact.id).update({
      ...contact.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Deletes a trusted contact.
  Future<void> deleteContact(String contactId) async {
    await _contactsCol().doc(contactId).delete();
  }

  /// Toggles a contact's active status.
  Future<void> toggleActive(String contactId, {required bool isActive}) async {
    await _contactsCol().doc(contactId).update({
      'isActive': isActive,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }
}
