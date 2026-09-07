import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'auth_challenge.dart';
import '../config/app_env.dart';

class AuthRepository {
  AuthRepository({
    FirebaseAuth? auth,
    FirebaseFunctions? functions,
    FirebaseFirestore? firestore,
  }) : _auth = auth ?? FirebaseAuth.instance,
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
    String? referredByCode,
  }) async {
    try {
      final callable = _functions.httpsCallable('requestEmailOtp');
      final response = await callable.call<Map<String, dynamic>>({
        'email': email.trim().toLowerCase(),
        'isSignUp': isSignUp,
        if (referredByCode != null && referredByCode.isNotEmpty)
          'referredByCode': referredByCode.trim().toUpperCase(),
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
    String? referredByCode,
    String? selectedRole, // 'customer' or 'driver'
    String? fullName, // for driver
    String? phone, // for driver
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
      await provisionUserMetadataAndProfile(
        email: challenge.email,
        referredByCode: referredByCode,
        selectedRole: selectedRole ?? 'customer',
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

  Future<void> provisionUserMetadataAndProfile({
    required String email,
    String? referredByCode,
    required String selectedRole,
    String? fullName,
    String? phone,
    String? profilePhotoUrl,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final now = FieldValue.serverTimestamp();
    final userRef = _firestore.collection('users').doc(user.uid);
    final customerRef = _firestore.collection('customers').doc(user.uid);
    final driverRef = _firestore.collection('drivers').doc(user.uid);

    // 1. Provision the role-specific document
    if (selectedRole == 'driver') {
      try {
        final callable = _functions.httpsCallable('createDriverProfileCallable');
        await callable.call<Map<String, dynamic>>({
          'referredByCode': referredByCode,
          'fullName': fullName,
          'phone': phone,
          if (profilePhotoUrl != null) 'profilePhotoUrl': profilePhotoUrl,
        });
      } catch (e) {
        // Fallback: If cloud function fails, write a basic driver document directly
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
            if (profilePhotoUrl != null) 'profilePhotoUrl': profilePhotoUrl,
          });
        }
      }
    } else {
      // customer
      final snapshot = await customerRef.get();
      if (!snapshot.exists) {
        await customerRef.set({
          'uid': user.uid,
          'email': email,
          'role': 'customer',
          'isEmailVerified': true,
          'profileCompleted': false,
          'fullName': fullName ?? '',
          if (phone != null) 'phone': phone,
          if (profilePhotoUrl != null) 'photoUrl': profilePhotoUrl,
          'referredByCode': referredByCode != null && referredByCode.trim().isNotEmpty
              ? referredByCode.trim().toUpperCase()
              : null,
          'createdAt': now,
          'updatedAt': now,
        });
      }
    }

    // 2. Determine existing roles to set correct metadata flags
    final customerExists = (await customerRef.get()).exists;
    final driverExists = (await driverRef.get()).exists;

    // 3. Set/Update lightweight user metadata document
    final userSnap = await userRef.get();
    if (!userSnap.exists) {
      await userRef.set({
        'uid': user.uid,
        'activeRole': selectedRole,
        'customerExists': customerExists,
        'driverExists': driverExists,
        'onboardingComplete': false,
        'createdAt': now,
        'updatedAt': now,
        'lastLogin': now,
      });
    } else {
      await userRef.update({
        'activeRole': selectedRole,
        'customerExists': customerExists,
        'driverExists': driverExists,
        'updatedAt': now,
        'lastLogin': now,
      });
    }

    // 4. Process signup referral if code was provided
    if (referredByCode != null && referredByCode.trim().isNotEmpty) {
      try {
        await processSignupReferral(
          newUid: user.uid,
          email: email,
          referredByCode: referredByCode,
          newUserRole: selectedRole,
        );
      } catch (_) {}
    }
  }

  Future<void> processSignupReferral({
    required String newUid,
    required String email,
    required String referredByCode,
    required String newUserRole,
  }) async {
    final cleanCode = referredByCode.trim();
    final codeLower = cleanCode.toLowerCase();

    // 1. Search customers and drivers for referrer
    final custSnapLower = await _firestore
        .collection('customers')
        .where('referralCodeLower', isEqualTo: codeLower)
        .limit(1)
        .get();

    final custSnapLegacy = custSnapLower.docs.isNotEmpty
        ? custSnapLower
        : await _firestore
            .collection('customers')
            .where('referralCode', isEqualTo: cleanCode)
            .limit(1)
            .get();

    DocumentSnapshot<Map<String, dynamic>>? referrerDoc;
    String referrerType = 'customer';

    if (custSnapLegacy.docs.isNotEmpty) {
      referrerDoc = custSnapLegacy.docs.first;
    } else {
      final driverSnapLower = await _firestore
          .collection('drivers')
          .where('referralCodeLower', isEqualTo: codeLower)
          .limit(1)
          .get();

      final driverSnapLegacy = driverSnapLower.docs.isNotEmpty
          ? driverSnapLower
          : await _firestore
              .collection('drivers')
              .where('referralCode', isEqualTo: cleanCode)
              .limit(1)
              .get();

      if (driverSnapLegacy.docs.isNotEmpty) {
        referrerDoc = driverSnapLegacy.docs.first;
        referrerType = 'driver';
      }
    }

    if (referrerDoc == null || referrerDoc.id == newUid) return;

    final targetColl = referrerType == 'driver' ? 'drivers' : 'customers';
    const double creditAmt = 1000.0;

    // Check if referral record already created for this user
    final existingRef = await _firestore
        .collection(targetColl)
        .doc(referrerDoc.id)
        .collection('referrals')
        .where('referredUid', isEqualTo: newUid)
        .limit(1)
        .get();

    if (existingRef.docs.isEmpty) {
      // Record referral document
      await _firestore.collection(targetColl).doc(referrerDoc.id).collection('referrals').add({
        'referredUid': newUid,
        'email': email,
        'userType': newUserRole == 'driver' ? 'Driver' : 'Customer',
        'status': 'completed',
        'rewardAmount': creditAmt,
        'joinedAt': FieldValue.serverTimestamp(),
      });

      // Update referrer stats
      await _firestore.collection(targetColl).doc(referrerDoc.id).set({
        'referralEarnings': FieldValue.increment(creditAmt),
        'successfulReferralsCount': FieldValue.increment(1),
      }, SetOptions(merge: true));

      // Credit the new user's credit balance
      final newUserColl = newUserRole == 'driver' ? 'drivers' : 'customers';
      await _firestore.collection(newUserColl).doc(newUid).set({
        'creditBalance': FieldValue.increment(creditAmt),
      }, SetOptions(merge: true));
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

    final uid = credential.user?.uid;
    if (uid != null) {
      // Check both collections to see if user exists as either customer or driver
      final customerDoc = await _firestore.collection('customers').doc(uid).get();
      final driverDoc = await _firestore.collection('drivers').doc(uid).get();

      if (!customerDoc.exists && !driverDoc.exists) {
        await _auth.signOut();
        throw FirebaseAuthException(
          code: 'not-found',
          message: 'No account found for this email.',
        );
      }

      if (!customerDoc.exists && driverDoc.exists) {
        final driverData = driverDoc.data() ?? {};
        await provisionUserMetadataAndProfile(
          email: email.trim().toLowerCase(),
          selectedRole: 'customer',
          fullName: driverData['fullName'] as String?,
          phone: driverData['phone'] as String?,
          profilePhotoUrl: driverData['profilePhotoUrl'] as String?,
        );
      }

      // Provision or update lightweight users/{uid} document
      final userRef = _firestore.collection('users').doc(uid);
      final now = FieldValue.serverTimestamp();
      final userSnap = await userRef.get();

      final activeRole = customerDoc.exists ? 'customer' : 'driver';

      if (!userSnap.exists) {
        await userRef.set({
          'uid': uid,
          'activeRole': activeRole,
          'customerExists': customerDoc.exists,
          'driverExists': driverDoc.exists,
          'onboardingComplete': true,
          'createdAt': now,
          'updatedAt': now,
          'lastLogin': now,
        });
      } else {
        await userRef.update({
          'activeRole': activeRole,
          'customerExists': customerDoc.exists,
          'driverExists': driverDoc.exists,
          'updatedAt': now,
          'lastLogin': now,
        });
      }
    }

    return credential;
  }

  Future<void> updatePassword(String password) async {
    final user = _auth.currentUser;
    if (user != null) {
      await user.updatePassword(password);
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

  Future<void> signOut() => _auth.signOut();
}
