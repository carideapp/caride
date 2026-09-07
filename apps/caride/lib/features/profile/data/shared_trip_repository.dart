import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';

class SharedTripRepository {
  SharedTripRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _sharedCol =>
      _firestore.collection('sharedTrips');

  /// Generates a unique 6-digit sharing code for a ride, writes to Firestore.
  Future<String> createShareCode(String rideId) async {
    final random = Random();
    String code = '';
    bool unique = false;

    // Retry loop to ensure code uniqueness
    for (int i = 0; i < 5; i++) {
      final numCode = 100000 + random.nextInt(900000);
      code = numCode.toString();
      final doc = await _sharedCol.doc(code).get();
      if (!doc.exists) {
        unique = true;
        break;
      }
    }

    if (!unique) {
      throw Exception('Failed to generate a unique share code. Please try again.');
    }

    await _sharedCol.doc(code).set({
      'rideId': rideId,
      'createdAt': FieldValue.serverTimestamp(),
    });

    return code;
  }

  /// Looks up the rideId linked to a 6-digit sharing code.
  Future<String?> getRideIdFromCode(String code) async {
    final cleanedCode = code.replaceAll(' ', '').trim();
    if (cleanedCode.isEmpty) return null;
    final doc = await _sharedCol.doc(cleanedCode).get();
    if (!doc.exists) return null;
    return doc.data()?['rideId'] as String?;
  }

  /// Deletes a sharing code mapping.
  Future<void> deleteShareCode(String code) async {
    final cleanedCode = code.replaceAll(' ', '').trim();
    if (cleanedCode.isEmpty) return;
    await _sharedCol.doc(cleanedCode).delete();
  }
}
