import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class SavedAddress {
  const SavedAddress({
    required this.id,
    required this.label,
    required this.address,
    this.placeId,
    this.lat,
    this.lng,
  });

  final String id;
  final String label;
  final String address;
  final String? placeId;
  final double? lat;
  final double? lng;

  factory SavedAddress.fromMap(String id, Map<String, dynamic> data) {
    final lat = data['lat'];
    final lng = data['lng'];
    return SavedAddress(
      id: id,
      label: (data['label'] as String?) ?? '',
      address: (data['address'] as String?) ?? '',
      placeId: data['placeId'] as String?,
      lat: lat is num ? lat.toDouble() : null,
      lng: lng is num ? lng.toDouble() : null,
    );
  }

  factory SavedAddress.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return SavedAddress.fromMap(doc.id, data);
  }
}

class AddressRepository {
  AddressRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  String? get _uid => _auth.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> get _addressesCol =>
      _firestore.collection('customers').doc(_uid).collection('savedAddresses');

  /// Watches the user's saved addresses in real time.
  Stream<List<SavedAddress>> watchAddresses() {
    if (_uid == null) return Stream.value(const []);
    return _addressesCol
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(SavedAddress.fromDoc).toList());
  }

  /// Adds a new address.
  Future<void> addAddress({
    required String label,
    required String address,
    String? placeId,
    double? lat,
    double? lng,
  }) async {
    if (_uid == null) throw Exception('Not signed in.');
    await _addressesCol.add({
      'label': label.trim(),
      'address': address.trim(),
      if (placeId != null) 'placeId': placeId,
      if (lat != null) 'lat': lat,
      if (lng != null) 'lng': lng,
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Updates an existing address.
  Future<void> updateAddress({
    required String id,
    required String label,
    required String address,
    String? placeId,
    double? lat,
    double? lng,
  }) async {
    if (_uid == null) throw Exception('Not signed in.');
    await _addressesCol.doc(id).update({
      'label': label.trim(),
      'address': address.trim(),
      if (placeId != null) 'placeId': placeId,
      if (lat != null) 'lat': lat,
      if (lng != null) 'lng': lng,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Deletes an address.
  Future<void> deleteAddress(String id) async {
    if (_uid == null) throw Exception('Not signed in.');
    await _addressesCol.doc(id).delete();
  }
}
