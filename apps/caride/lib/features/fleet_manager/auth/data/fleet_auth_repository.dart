import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_models/shared_models.dart';

import '../../../../core/auth/auth_challenge.dart';
import '../../../../core/config/app_env.dart';

class FleetAuthRepository {
  FleetAuthRepository({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
    FirebaseFunctions? functions,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? _safeStorageInstance(),
        _functions = functions ??
            FirebaseFunctions.instanceFor(region: AppEnv.firebaseFunctionsRegion);

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final FirebaseFunctions _functions;

  static FirebaseStorage _safeStorageInstance() {
    try {
      return FirebaseStorage.instance;
    } catch (_) {
      try {
        return FirebaseStorage.instanceFor(
            bucket: 'gs://caride-app.firebasestorage.app');
      } catch (_) {
        return FirebaseStorage.instanceFor(
            bucket: 'caride-app.firebasestorage.app');
      }
    }
  }

  Stream<User?> authStateChanges() => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  // ── Authentication Operations ─────────────────────────────────────────


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
        'role': 'fleet',
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
    } on FirebaseFunctionsException catch (error) {
      throw FirebaseAuthException(
        code: error.code,
        message: error.message ?? 'Unable to verify OTP right now.',
      );
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
      // Look up fleet profile
      final fleetSnap = await _firestore
          .collection('fleets')
          .where('ownerUid', isEqualTo: uid)
          .limit(1)
          .get();

      final customerDoc =
          await _firestore.collection('customers').doc(uid).get();
      final driverDoc = await _firestore.collection('drivers').doc(uid).get();

      final userRef = _firestore.collection('users').doc(uid);
      final now = FieldValue.serverTimestamp();

      await userRef.set({
        'uid': uid,
        'activeRole': 'fleet',
        'customerExists': customerDoc.exists,
        'driverExists': driverDoc.exists,
        'fleetExists': fleetSnap.docs.isNotEmpty,
        'hasFleet': fleetSnap.docs.isNotEmpty,
        if (fleetSnap.docs.isNotEmpty) 'fleetId': fleetSnap.docs.first.id,
        'updatedAt': now,
        'lastLogin': now,
      }, SetOptions(merge: true));
    }

    return credential;
  }

  Future<UserCredential> signUpWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    return await _auth.createUserWithEmailAndPassword(
      email: email.trim().toLowerCase(),
      password: password,
    );
  }

  /// Called immediately after OTP verification succeeds.
  /// Writes users/{uid} with activeRole='fleet' and a draft fleet_managers/{uid}
  /// document so the redirect guard does NOT bounce the user to customer home.
  Future<void> provisionFleetUserAfterOtp({
    required String email,
    String? password,
  }) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    final now = FieldValue.serverTimestamp();

    // 1. Set users/{uid} with activeRole='fleet' as a client-side best effort.
    // Note: Cloud Function verifyEmailOtp already sets this with Admin privileges.
    try {
      await _firestore.collection('users').doc(uid).set({
        'uid': uid,
        'activeRole': 'fleet',
        'customerExists': false,
        'driverExists': false,
        'fleetExists': false,
        'hasFleet': false,
        'isFleetSignupInProgress': true,
        'createdAt': now,
        'updatedAt': now,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('provisionFleetUserAfterOtp users doc set (handled): $e');
    }

    // 2. Write initial draft to fleet_managers/{uid}.
    try {
      await _firestore.collection('fleet_managers').doc(uid).set({
        'uid': uid,
        'email': email.trim().toLowerCase(),
        'signupStatus': 'onboarding',
        'signupStep': 1,
        'verificationStatus': 'draft',
        'createdAt': now,
        'updatedAt': now,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('provisionFleetUserAfterOtp fleet_managers doc set (handled): $e');
    }

    // 3. Set password via email/password link if provided (allows email+pass login later).
    if (password != null && password.isNotEmpty) {
      try {
        final user = _auth.currentUser;
        if (user != null) {
          final credential = EmailAuthProvider.credential(
            email: email.trim().toLowerCase(),
            password: password,
          );
          await user.linkWithCredential(credential);
        }
      } catch (e) {
        debugPrint('provisionFleetUserAfterOtp password link: $e');
      }
    }
  }

  /// Progressively saves/updates the fleet manager signup draft in Firestore.
  Future<void> saveFleetSignupDraft({
    required String uid,
    required String email,
    String? businessType,
    String? fullName,
    String? phone,
    String? gender,
    String? companyName,
    String? companyAddress,
    String? rcNumber,
    String? identityDocumentType,
    int? signupStep,
  }) async {
    final now = FieldValue.serverTimestamp();
    final Map<String, dynamic> data = {
      'uid': uid,
      'email': email,
      'signupStatus': 'onboarding',
      'updatedAt': now,
    };
    if (businessType != null) data['businessType'] = businessType;
    if (fullName != null && fullName.isNotEmpty) data['fullName'] = fullName;
    if (phone != null && phone.isNotEmpty) data['phone'] = phone;
    if (gender != null) data['gender'] = gender;
    if (companyName != null && companyName.isNotEmpty) data['businessName'] = companyName;
    if (companyAddress != null && companyAddress.isNotEmpty) data['address'] = companyAddress;
    if (rcNumber != null && rcNumber.isNotEmpty) data['registrationNumber'] = rcNumber;
    if (identityDocumentType != null) data['identityDocumentType'] = identityDocumentType;
    if (signupStep != null) data['signupStep'] = signupStep;

    await _firestore.collection('fleet_managers').doc(uid).set(data, SetOptions(merge: true));
  }

  /// Fetches the draft onboarding document for the fleet manager.
  Future<Map<String, dynamic>?> getFleetSignupDraft(String uid) async {
    try {
      final doc = await _firestore.collection('fleet_managers').doc(uid).get();
      if (doc.exists) {
        return doc.data();
      }
    } catch (e) {
      debugPrint('getFleetSignupDraft error: $e');
    }
    return null;
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

  // ── Document & Registration Submission ────────────────────────────────

  Future<String> uploadFleetDocument({
    required String uid,
    required String docName,
    required File file,
  }) async {
    final ext = file.path.split('.').last;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final storageRef =
        _storage.ref().child('fleet_documents/$uid/${docName}_$timestamp.$ext');

    final uploadTask = await storageRef.putFile(file);
    return await uploadTask.ref.getDownloadURL();
  }

  Future<FleetProfile> submitFleetApplication({
    required String uid,
    required FleetProfile profileDraft,
    File? profilePhotoFile,
    File? companyLogoFile,
    File? identityDocFile,
    File? cacDocFile,
  }) async {
    String? photoUrl = profileDraft.profilePictureUrl;
    String? logoUrl = profileDraft.logoUrl;
    String? identityUrl = profileDraft.identityDocumentUrl;
    String? cacUrl = profileDraft.cacDocumentUrl;

    // 1. Upload files to Storage if present
    if (profilePhotoFile != null) {
      try {
        photoUrl = await uploadFleetDocument(
          uid: uid,
          docName: 'profile_photo',
          file: profilePhotoFile,
        );
      } catch (e) {
        debugPrint('Error uploading profile photo: $e');
      }
    }

    if (companyLogoFile != null) {
      try {
        logoUrl = await uploadFleetDocument(
          uid: uid,
          docName: 'company_logo',
          file: companyLogoFile,
        );
      } catch (e) {
        debugPrint('Error uploading company logo: $e');
      }
    }

    if (identityDocFile != null) {
      try {
        identityUrl = await uploadFleetDocument(
          uid: uid,
          docName: 'identity_doc',
          file: identityDocFile,
        );
      } catch (e) {
        debugPrint('Error uploading identity doc: $e');
      }
    }

    if (cacDocFile != null) {
      try {
        cacUrl = await uploadFleetDocument(
          uid: uid,
          docName: 'cac_doc',
          file: cacDocFile,
        );
      } catch (e) {
        debugPrint('Error uploading CAC doc: $e');
      }
    }

    // 2. Prepare FleetProfile document
    final fleetsCol = _firestore.collection('fleets');
    DocumentReference<Map<String, dynamic>> docRef;

    if (profileDraft.fleetId.isNotEmpty) {
      docRef = fleetsCol.doc(profileDraft.fleetId);
    } else {
      // Check if one already exists for this owner
      final existing = await fleetsCol
          .where('ownerUid', isEqualTo: uid)
          .limit(1)
          .get();
      if (existing.docs.isNotEmpty) {
        docRef = existing.docs.first.reference;
      } else {
        docRef = fleetsCol.doc();
      }
    }

    final finalProfile = profileDraft.copyWith(
      fleetId: docRef.id,
      ownerUid: uid,
      profilePictureUrl: photoUrl,
      logoUrl: logoUrl,
      identityDocumentUrl: identityUrl,
      cacDocumentUrl: cacUrl,
      verificationStatus: 'pending',
      identityDocumentStatus: 'pending',
      cacDocumentStatus: profileDraft.isCompany ? 'pending' : null,
      createdAt: profileDraft.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await docRef.set(finalProfile.toMap(), SetOptions(merge: true));

    // 3. Update users/{uid} metadata
    final userRef = _firestore.collection('users').doc(uid);
    await userRef.set({
      'uid': uid,
      'activeRole': 'fleet',
      'fleetExists': true,
      'hasFleet': true,
      'fleetId': docRef.id,
      'verificationStatus': 'pending',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // 4. Process signup referral if provided
    if (profileDraft.referredByCode != null &&
        profileDraft.referredByCode!.trim().isNotEmpty) {
      try {
        await _processReferral(
          newUid: uid,
          email: profileDraft.email,
          referredByCode: profileDraft.referredByCode!.trim(),
        );
      } catch (e) {
        debugPrint('Error processing fleet referral: $e');
      }
    }

    // 5. Trigger Welcome Email and In-App Welcome Notification
    try {
      await _sendFleetWelcomeEmailAndNotification(
        uid: uid,
        profile: finalProfile,
      );
    } catch (e) {
      debugPrint('Error triggering fleet welcome notification/email: $e');
    }

    return finalProfile;
  }

  Future<void> _processReferral({
    required String newUid,
    required String email,
    required String referredByCode,
  }) async {
    final cleanCode = referredByCode.trim().toLowerCase();

    // Check customers, drivers, fleets for referrer
    final custSnap = await _firestore
        .collection('customers')
        .where('referralCodeLower', isEqualTo: cleanCode)
        .limit(1)
        .get();

    String targetColl = 'customers';
    DocumentSnapshot<Map<String, dynamic>>? referrerDoc;

    if (custSnap.docs.isNotEmpty) {
      referrerDoc = custSnap.docs.first;
    } else {
      final driverSnap = await _firestore
          .collection('drivers')
          .where('referralCodeLower', isEqualTo: cleanCode)
          .limit(1)
          .get();

      if (driverSnap.docs.isNotEmpty) {
        referrerDoc = driverSnap.docs.first;
        targetColl = 'drivers';
      }
    }

    if (referrerDoc == null || referrerDoc.id == newUid) return;

    const double creditAmt = 1000.0;

    await _firestore
        .collection(targetColl)
        .doc(referrerDoc.id)
        .collection('referrals')
        .add({
      'referredUid': newUid,
      'email': email,
      'userType': 'FleetManager',
      'status': 'completed',
      'rewardAmount': creditAmt,
      'joinedAt': FieldValue.serverTimestamp(),
    });

    await _firestore.collection(targetColl).doc(referrerDoc.id).set({
      'referralEarnings': FieldValue.increment(creditAmt),
      'successfulReferralsCount': FieldValue.increment(1),
    }, SetOptions(merge: true));
  }

  Future<void> _sendFleetWelcomeEmailAndNotification({
    required String uid,
    required FleetProfile profile,
  }) async {
    final now = FieldValue.serverTimestamp();
    final isCompany = profile.businessType.toLowerCase() == 'company';
    final name = profile.fullName.isNotEmpty ? profile.fullName : 'Fleet Partner';
    final businessTitle =
        profile.businessName.isNotEmpty ? profile.businessName : name;

    // 1. Trigger Cloud Function (if deployed on backend)
    try {
      final callable = _functions.httpsCallable('sendFleetWelcomeEmail');
      await callable.call({
        'uid': uid,
        'email': profile.email,
        'fullName': name,
        'businessName': businessTitle,
        'businessType': profile.businessType,
      });
    } catch (e) {
      debugPrint('Cloud Function sendFleetWelcomeEmail fallback: $e');
    }

    // 2. Queue Firestore Mail Document for Trigger Extension / SMTP
    try {
      if (profile.email.isNotEmpty) {
        await _firestore.collection('mail').add({
          'to': [profile.email],
          'message': {
            'subject': 'Welcome to CaRide Fleet Partner Program, $name!',
            'text': '''
Welcome to CaRide Fleet Partner Program!

Hello $name,

Thank you for registering your fleet with CaRide. Your application for $businessTitle (${isCompany ? "Registered Company" : "Individual Operator"}) has been received and is currently under review by our operations team.

What's Next:
1. Document Review: Our verification team will review your submitted credentials within 24 to 48 hours.
2. Fleet Portal Access: Once approved, you can immediately add vehicles, set daily rental rates, assign chauffeurs, and accept rental bookings.

If you have any questions, feel free to reply to this email or reach out to support@caride.com.

Best regards,
The CaRide Operations Team
            '''
                .trim(),
            'html': '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; background-color: #F9FAFB; margin: 0; padding: 24px; color: #1F2937; }
    .card { max-width: 580px; margin: 0 auto; background: #FFFFFF; border-radius: 20px; padding: 36px 32px; border: 1px solid #E5E7EB; box-shadow: 0 4px 16px rgba(0,0,0,0.04); }
    .badge { display: inline-block; background-color: #DCFCE7; color: #16A34A; padding: 6px 14px; border-radius: 20px; font-weight: 700; font-size: 12px; margin-bottom: 16px; }
    .h1 { font-size: 24px; font-weight: 800; color: #111827; margin: 0 0 12px 0; }
    .p { font-size: 15px; line-height: 1.6; color: #4B5563; margin: 0 0 16px 0; }
    .box { background-color: #F0FDF4; border: 1px solid #BBF7D0; border-radius: 16px; padding: 18px; margin: 24px 0; }
    .box-title { font-weight: 700; color: #15803D; font-size: 14px; margin-bottom: 8px; }
    .step { font-size: 14px; color: #166534; margin: 6px 0; line-height: 1.4; }
    .footer { font-size: 12px; color: #9CA3AF; text-align: center; margin-top: 32px; border-top: 1px solid #F3F4F6; padding-top: 20px; }
  </style>
</head>
<body>
  <div class="card">
    <div class="badge">CaRide Fleet Partner</div>
    <h1 class="h1">Welcome to CaRide!</h1>
    <p class="p">Hello <strong>$name</strong>,</p>
    <p class="p">Thank you for registering with CaRide. Your application for <strong>$businessTitle</strong> has been submitted successfully and is currently under review by our operations team.</p>
    
    <div class="box">
      <div class="box-title">What happens next?</div>
      <div class="step"><strong>1. Verification Review:</strong> Our team reviews your uploaded identity and registration documents (typically within 24–48 hours).</div>
      <div class="step"><strong>2. Portal Activation:</strong> As soon as approved, your vehicle inventory listing and chauffeur dispatch tools will be fully unlocked.</div>
      <div class="step"><strong>3. Start Earning:</strong> Accept daily rentals, chauffeur bookings, and receive automated weekly payouts.</div>
    </div>

    <p class="p">You can check your review status anytime directly inside the CaRide app.</p>
    <div class="footer">
      &copy; ${DateTime.now().year} CaRide Technologies Ltd. All rights reserved.
    </div>
  </div>
</body>
</html>
            '''
                .trim(),
          },
          'createdAt': now,
        });
      }
    } catch (e) {
      debugPrint('Error enqueuing Firestore mail document: $e');
    }

    // 3. Create In-App Notification Document
    try {
      await _firestore
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .add({
        'title': 'Welcome to CaRide Fleet Program!',
        'body':
            'Your Fleet Manager application for $businessTitle has been received and is in review.',
        'type': 'fleet_application_submitted',
        'isRead': false,
        'createdAt': now,
      });
    } catch (e) {
      debugPrint('Error creating in-app notification: $e');
    }
  }

  Stream<FleetProfile?> streamFleetProfile(String uid) {
    if (uid.isEmpty) return Stream.value(null);

    return _firestore
        .collection('fleets')
        .where('ownerUid', isEqualTo: uid)
        .limit(1)
        .snapshots()
        .map((snap) {
      if (snap.docs.isEmpty) return null;
      final doc = snap.docs.first;
      return FleetProfile.fromMap(doc.data(), doc.id);
    });
  }
}

final fleetAuthRepository = FleetAuthRepository();
