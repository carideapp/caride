import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import 'auth_challenge.dart';
import '../config/app_env.dart';

class DriverAuthRepository {
  DriverAuthRepository({
    FirebaseAuth? auth,
    FirebaseFunctions? functions,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _functions =
            functions ?? FirebaseFunctions.instanceFor(region: AppEnv.firebaseFunctionsRegion),
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFunctions _functions;
  final FirebaseFirestore _firestore;

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;


  Future<AuthChallenge> requestEmailOtp({
    required String email,
    required bool isSignUp,
  }) async {
    try {
      final callable = _functions.httpsCallable('requestEmailOtp');
      final response = await callable.call<Map<String, dynamic>>({
        'email': email.trim().toLowerCase(),
        'isSignUp': isSignUp,
        'role': 'driver',
      });
      final data = response.data;
      final challengeId = data['challengeId'] as String?;
      final expiresAtIso = data['expiresAt'] as String?;
      if (challengeId == null || expiresAtIso == null) {
        throw FirebaseAuthException(
          code: 'invalid-otp-response',
          message: 'OTP challenge response is missing required fields.',
        );
      }
      return AuthChallenge(
        challengeId: challengeId,
        email: email.trim().toLowerCase(),
        expiresAt: DateTime.parse(expiresAtIso).toLocal(),
        isSignUp: isSignUp,
      );
    } on FirebaseFunctionsException catch (error) {
      throw FirebaseAuthException(
        code: error.code,
        message: error.message ?? 'Unable to request OTP right now.',
      );
    }
  }

  Future<void> verifyEmailOtp({
    required AuthChallenge challenge,
    required String code,
    String? referralCode,
    String? fullName,
    String? phone,
  }) async {
    try {
      final callable = _functions.httpsCallable('verifyEmailOtp');
      final response = await callable.call<Map<String, dynamic>>({
        'challengeId': challenge.challengeId,
        'code': code,
        'email': challenge.email,
      });
      final data = response.data;
      final customToken = data['customToken'] as String?;
      if (customToken == null || customToken.isEmpty) {
        throw FirebaseAuthException(
          code: 'invalid-custom-token-response',
          message: 'Unable to verify OTP at this time.',
        );
      }

      await _auth.signInWithCustomToken(customToken);
      await provisionDriverProfile(
        email: challenge.email,
        referralCode: referralCode,
        fullName: fullName,
        phone: phone,
      );
    } on FirebaseFunctionsException catch (error) {
      throw FirebaseAuthException(
        code: error.code,
        message: error.message ?? 'Unable to verify OTP right now.',
      );
    }
  }

  Future<void> provisionDriverProfile({
    required String email,
    String? referralCode,
    String? fullName,
    String? phone,
    String? username,
    String? country,
    String? state,
    String? profilePhotoUrl,
    String? coverPhotoUrl,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final now = FieldValue.serverTimestamp();
    final driverRef = _firestore.collection('drivers').doc(user.uid);

    try {
      final callable = _functions.httpsCallable('createDriverProfileCallable');
      await callable.call<Map<String, dynamic>>({
        'referredByCode': referralCode,
        'fullName': fullName,
        'phone': phone,
        if (username != null) 'username': username,
        if (country != null) 'country': country,
        if (state != null) 'state': state,
        if (profilePhotoUrl != null) 'profilePhotoUrl': profilePhotoUrl,
        if (coverPhotoUrl != null) 'coverPhotoUrl': coverPhotoUrl,
      });
    } catch (e) {
      debugPrint('Failed to provision driver profile via callable: $e');
      final snapshot = await driverRef.get();
      if (!snapshot.exists) {
        await driverRef.set({
          'uid': user.uid,
          'email': email,
          'role': 'driver',
          'profileCompleted': false,
          'createdAt': now,
          'updatedAt': now,
          if (fullName != null) 'fullName': fullName,
          if (phone != null) 'phone': phone,
          if (username != null) 'username': username,
          if (country != null) 'country': country,
          if (state != null) 'state': state,
          if (profilePhotoUrl != null) 'profilePhotoUrl': profilePhotoUrl,
          if (coverPhotoUrl != null) 'coverPhotoUrl': coverPhotoUrl,
        });
      } else {
        final updateMap = <String, dynamic>{
          'updatedAt': now,
          if (fullName != null) 'fullName': fullName,
          if (phone != null) 'phone': phone,
          if (username != null) 'username': username,
          if (country != null) 'country': country,
          if (state != null) 'state': state,
          if (profilePhotoUrl != null) 'profilePhotoUrl': profilePhotoUrl,
          if (coverPhotoUrl != null) 'coverPhotoUrl': coverPhotoUrl,
        };
        await driverRef.update(updateMap);
      }
    }

    // Set users/{uid} metadata with activeRole: 'driver' and driverExists: true
    // so router redirect guards route the user to the Driver App.
    try {
      final userRef = _firestore.collection('users').doc(user.uid);
      final userSnap = await userRef.get();
      if (!userSnap.exists) {
        await userRef.set({
          'uid': user.uid,
          'activeRole': 'driver',
          'customerExists': false,
          'driverExists': true,
          'onboardingComplete': true,
          'createdAt': now,
          'updatedAt': now,
          'lastLogin': now,
        }, SetOptions(merge: true));
      } else {
        await userRef.set({
          'activeRole': 'driver',
          'driverExists': true,
          'updatedAt': now,
          'lastLogin': now,
        }, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint('Failed to set users metadata for driver: $e');
    }
  }

  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim().toLowerCase(),
      password: password,
    );

    // Verify this user belongs to the 'drivers' collection.
    final uid = credential.user?.uid;
    if (uid != null) {
      final customerDoc = await _firestore.collection('customers').doc(uid).get();
      final driverDoc = await _firestore.collection('drivers').doc(uid).get();

      if (!driverDoc.exists) {
        if (customerDoc.exists) {
          final customerData = customerDoc.data() ?? {};
          // Automatic onboarding transition: Provision driver profile since they already have a customer account
          await provisionDriverProfile(
            email: email.trim().toLowerCase(),
            fullName: customerData['fullName'] as String?,
            phone: customerData['phone'] as String?,
          );
        } else {
          // Sign out immediately — this account is not a driver nor customer
          await _auth.signOut();
          throw FirebaseAuthException(
            code: 'not-found',
            message: 'No driver account found for this email.',
          );
        }
      }

      // Provision or update lightweight users/{uid} document
      final userRef = _firestore.collection('users').doc(uid);
      final now = FieldValue.serverTimestamp();
      final userSnap = await userRef.get();

      final activeRole = 'driver';

      if (!userSnap.exists) {
        await userRef.set({
          'uid': uid,
          'activeRole': activeRole,
          'customerExists': customerDoc.exists,
          'driverExists': true,
          'onboardingComplete': true,
          'createdAt': now,
          'updatedAt': now,
          'lastLogin': now,
        });
      } else {
        await userRef.update({
          'activeRole': activeRole,
          'customerExists': customerDoc.exists,
          'driverExists': true,
          'updatedAt': now,
          'lastLogin': now,
        });
      }
    }

    return credential;
  }

  Future<void> signUpWithEmailAndPassword({
    required String email,
    required String password,
    String? referralCode,
    String? fullName,
    String? phone,
    String? username,
    String? country,
    String? state,
    String? coverPhotoUrl,
  }) async {
    final userCredential = await _auth.createUserWithEmailAndPassword(
      email: email.trim().toLowerCase(),
      password: password,
    );
    if (userCredential.user != null) {
      await provisionDriverProfile(
        email: email.trim().toLowerCase(),
        referralCode: referralCode,
        fullName: fullName,
        phone: phone,
        username: username,
        country: country,
        state: state,
        coverPhotoUrl: coverPhotoUrl,
      );
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      final callable = _functions.httpsCallable('sendCustomPasswordResetEmail');
      await callable.call({'email': email.trim().toLowerCase()});
    } on FirebaseFunctionsException catch (error) {
      throw FirebaseAuthException(
        code: error.code,
        message: error.message ?? 'Unable to send password reset email.',
      );
    }
  }

  /// Provisions a customer profile for an existing driver using their driver profile data.
  /// Calls the Cloud Function first; falls back to a direct Firestore write if it fails.
  Future<void> becomeCustomer({
    required String email,
    String? fullName,
    String? phone,
    String? profilePhotoUrl,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final now = FieldValue.serverTimestamp();
    final customerRef = _firestore.collection('customers').doc(user.uid);
    final driverRef = _firestore.collection('drivers').doc(user.uid);
    final userRef = _firestore.collection('users').doc(user.uid);

    // 1. Try the Cloud Function first (mirrors createDriverProfileCallable pattern)
    try {
      final callable = _functions.httpsCallable('createCustomerProfileCallable');
      await callable.call<Map<String, dynamic>>({
        'fullName': fullName,
        'phone': phone,
        if (profilePhotoUrl != null) 'photoUrl': profilePhotoUrl,
      });
    } catch (e) {
      debugPrint('Cloud Function createCustomerProfileCallable failed: $e — falling back to Firestore');
      // 2. Fallback: write directly to Firestore using merge to preserve fields like fcmToken
      await customerRef.set({
        'uid': user.uid,
        'email': email.trim().toLowerCase(),
        'role': 'customer',
        'isEmailVerified': true,
        'profileCompleted': true,
        'fullName': fullName ?? '',
        if (phone != null && phone.isNotEmpty) 'phone': phone,
        if (profilePhotoUrl != null && profilePhotoUrl.isNotEmpty) 'photoUrl': profilePhotoUrl,
        'walletBalance': 0.0,
        'referralCode': '',
        'referralEarnings': 0.0,
        'createdAt': now,
        'updatedAt': now,
      }, SetOptions(merge: true));
    }

    // 3. Update users metadata: mark customerExists = true, switch activeRole = 'customer'
    final customerExists = (await customerRef.get()).exists;
    final driverExists = (await driverRef.get()).exists;

    await userRef.update({
      'activeRole': 'customer',
      'customerExists': customerExists,
      'driverExists': driverExists,
      'updatedAt': now,
    });
  }

  Future<void> signOut() => _auth.signOut();
}
