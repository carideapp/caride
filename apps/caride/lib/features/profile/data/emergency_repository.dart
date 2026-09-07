import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:caride/core/config/app_env.dart';

class EmergencyRepository {
  EmergencyRepository({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _functions = functions ??
            FirebaseFunctions.instanceFor(region: AppEnv.firebaseFunctionsRegion),
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;
  final FirebaseAuth _auth;

  String? get _uid => _auth.currentUser?.uid;

  /// Sends an emergency alert email to a trusted contact via Cloud Function.
  /// Returns the generated event ID.
  Future<String> sendEmergencyAlert({
    required String trustedContactEmail,
    required String trustedContactName,
    String? rideId,
    String? shareCode,
  }) async {
    if (_uid == null) throw Exception('Not signed in.');

    final callable = _functions.httpsCallable('sendEmergencyAlert');
    final result = await callable.call<Map<dynamic, dynamic>>({
      'trustedContactEmail': trustedContactEmail,
      'trustedContactName': trustedContactName,
      if (rideId != null) 'rideId': rideId,
      if (shareCode != null) 'shareCode': shareCode,
    });

    return (result.data['eventId'] as String?) ?? '';
  }

  /// Returns the startCodeEnabled setting for the current customer.
  /// Defaults to true if not set (opt-in by default).
  Future<bool> isStartCodeEnabled() async {
    final uid = _uid;
    if (uid == null) return true;
    try {
      final doc =
          await _firestore.collection('customers').doc(uid).get();
      final raw = doc.data()?['startCodeEnabled'];
      if (raw == false) return false;
      return true;
    } catch (_) {
      return true;
    }
  }

  /// Sets the startCodeEnabled preference for the current customer.
  Future<void> setStartCodeEnabled(bool enabled) async {
    final uid = _uid;
    if (uid == null) return;
    await _firestore.collection('customers').doc(uid).update({
      'startCodeEnabled': enabled,
    });
  }
}
