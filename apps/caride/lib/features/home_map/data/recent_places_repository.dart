import 'package:caride/features/home_map/data/mapbox_search_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RecentPlace {
  const RecentPlace({
    required this.id,
    required this.placeName,
    required this.lat,
    required this.lng,
    this.placeId,
  });

  final String id;
  final String placeName;
  final String? placeId;
  final double lat;
  final double lng;

  static RecentPlace? fromMap(String id, Map<String, dynamic> data) {
    final name = data['placeName'];
    final lat = data['lat'];
    final lng = data['lng'];
    if (name is! String || name.trim().isEmpty) return null;
    if (lat is! num || lng is! num) return null;
    return RecentPlace(
      id: id,
      placeName: name,
      placeId: data['placeId'] as String?,
      lat: lat.toDouble(),
      lng: lng.toDouble(),
    );
  }
}

class RecentPlacesRepository {
  RecentPlacesRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  String? get _uid => _auth.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> get _col => _firestore
      .collection('customers')
      .doc(_uid)
      .collection('recentPlaces');

  Stream<List<RecentPlace>> watchRecentPlaces({int limit = 10}) {
    if (_uid == null) return Stream.value(const []);
    return _col
        .orderBy('updatedAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) {
      final out = <RecentPlace>[];
      for (final doc in snap.docs) {
        final parsed = RecentPlace.fromMap(doc.id, doc.data());
        if (parsed != null) out.add(parsed);
      }
      return out;
    });
  }

  Future<void> recordPlace(MapboxPlace place) async {
    final uid = _uid;
    if (uid == null) return;

    final id = place.id.isNotEmpty
        ? place.id
        : DateTime.now().millisecondsSinceEpoch.toString();

    await _col.doc(id).set(
      {
        'placeName': place.placeName,
        'placeId': place.id,
        'lat': place.centerLat,
        'lng': place.centerLng,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }
}

