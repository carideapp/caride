import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:caride/core/config/app_env.dart';

class DriverSecurityPinRepository {
  DriverSecurityPinRepository({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
    FirebaseAuth? auth,
  })  : _firestore = firestore ?? FirebaseFirestore.instance,
        _functions = functions ??
            FirebaseFunctions.instanceFor(
                region: AppEnv.firebaseFunctionsRegion),
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;
  final FirebaseAuth _auth;

  String? get _uid => _auth.currentUser?.uid;

  /// Returns whether this customer has already set a security PIN.
  Future<bool> hasPinSet() async {
    final uid = _uid;
    if (uid == null) return false;
    final doc = await _firestore.collection('drivers').doc(uid).get();
    return (doc.data()?['hasPinSet'] as bool?) ?? false;
  }

  /// Creates a new 4-digit security PIN. Hashed server-side.
  Future<void> createPin(String pin) async {
    if (_uid == null) throw Exception('Not signed in.');
    await _functions.httpsCallable('createDriverSecurityPin').call({
      'pin': pin,
    });
  }

  /// Changes PIN. Verifies the old PIN server-side before updating.
  Future<void> changePin({
    required String oldPin,
    required String newPin,
  }) async {
    if (_uid == null) throw Exception('Not signed in.');
    await _functions.httpsCallable('changeDriverSecurityPin').call({
      'oldPin': oldPin,
      'newPin': newPin,
    });
  }

  /// Sends a 6-digit OTP to the user's email to begin PIN reset.
  Future<void> sendResetOtp() async {
    if (_uid == null) throw Exception('Not signed in.');
    await _functions.httpsCallable('sendDriverPinResetOtp').call({});
  }

  /// Resets the PIN using the OTP code received by email.
  Future<void> resetPin({
    required String otp,
    required String newPin,
  }) async {
    if (_uid == null) throw Exception('Not signed in.');
    await _functions.httpsCallable('resetDriverSecurityPin').call({
      'otp': otp,
      'newPin': newPin,
    });
  }

  /// Verifies a PIN (used internally; the actual verify happens server-side
  /// during withdrawal — this is just for pre-check in the UI).
  Future<bool> verifyPin(String pin) async {
    if (_uid == null) return false;
    try {
      final result = await _functions
          .httpsCallable('verifyDriverSecurityPin')
          .call({'pin': pin});
      final data = result.data as Map<dynamic, dynamic>;
      return (data['valid'] as bool?) ?? false;
    } catch (_) {
      return false;
    }
  }
}
