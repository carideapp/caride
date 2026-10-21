import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_models/shared_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/auth/auth_challenge.dart';
import '../../../../core/auth/customer_auth_controller.dart';
import '../../../../core/auth/pending_otp_session.dart';
import '../../../../core/services/termii_service.dart';
import '../../controllers/fleet_manager_controller.dart';
import '../data/fleet_auth_repository.dart';

class FleetAuthController extends ChangeNotifier {
  FleetAuthController({FleetAuthRepository? repository})
      : _repository = repository ?? fleetAuthRepository {
    _authSub = _repository.authStateChanges().listen((user) {
      _profileSub?.cancel();
      _currentUserUid = user?.uid;
      if (user != null) {
        _profileSub = _repository.streamFleetProfile(user.uid).listen((profile) {
          _currentProfile = profile;
          notifyListeners();
        }, onError: (err) {
          debugPrint('[FleetAuthController] streamFleetProfile error: $err');
        });
      } else {
        _currentProfile = null;
        notifyListeners();
      }
    });
  }

  final FleetAuthRepository _repository;
  StreamSubscription<Object?>? _authSub;
  StreamSubscription<FleetProfile?>? _profileSub;

  String? _currentUserUid;
  FleetProfile? _currentProfile;
  bool _isBusy = false;
  String? _errorMessage;

  // ── Multi-Step Signup Draft State ─────────────────────────────────────
  int currentSignupStep = 0;

  // Step 1: Account
  String email = '';       // user's real email address
  String phone = '';       // user's phone number (11-digit local)
  String password = '';
  String confirmPassword = '';
  String referralCode = '';
  bool termsAccepted = false;

  // Step 2: OTP
  AuthChallenge? pendingChallenge;

  // Step 3: Business Type
  String businessType = 'individual'; // 'individual' | 'company'

  // Step 4: Information & Documents
  String fullName = '';
  String? gender = 'Male';
  File? profilePhotoFile;
  String companyName = '';
  String companyAddress = '';
  String rcNumber = '';
  File? companyLogoFile;
  String identityDocumentType = 'NIN Slip';
  File? identityDocumentFile;
  File? cacDocumentFile;

  // ── Getters ───────────────────────────────────────────────────────────
  bool get isAuthenticated => _repository.currentUser != null;
  String? get currentUid => _currentUserUid ?? _repository.currentUser?.uid;
  FleetProfile? get currentProfile => _currentProfile;
  bool get isBusy => _isBusy;
  String? get errorMessage => _errorMessage;

  bool get isApproved => _currentProfile?.isApproved ?? false;
  bool get isPending => _currentProfile?.isPending ?? true;
  bool get isRejected => _currentProfile?.isRejected ?? false;
  bool get isSuspended => _currentProfile?.isSuspended ?? false;

  // ── Step Navigation & Draft State ─────────────────────────────────────

  void setStep(int step) {
    currentSignupStep = step;
    notifyListeners();
  }

  void nextStep() {
    currentSignupStep++;
    notifyListeners();
  }

  void previousStep() {
    if (currentSignupStep > 0) {
      currentSignupStep--;
      notifyListeners();
    }
  }

  void resetDraft() {
    currentSignupStep = 0;
    email = '';
    password = '';
    confirmPassword = '';
    referralCode = '';
    termsAccepted = false;
    pendingChallenge = null;
    businessType = 'individual';
    fullName = '';
    phone = '';
    gender = 'Male';
    profilePhotoFile = null;
    companyName = '';
    companyAddress = '';
    rcNumber = '';
    companyLogoFile = null;
    identityDocumentType = 'NIN Slip';
    identityDocumentFile = null;
    cacDocumentFile = null;
    _errorMessage = null;
    PendingOtpSessionService.instance.clearSession();
    notifyListeners();
  }

  void preloadFromUser({String? email, String? fullName, String? phone}) {
    if (email != null && email.isNotEmpty) this.email = email;
    if (fullName != null && fullName.isNotEmpty) this.fullName = fullName;
    if (phone != null && phone.isNotEmpty) this.phone = phone;
    notifyListeners();
  }

  // ── Authentication Actions ────────────────────────────────────────────

  Future<void> requestSignupOtp() async {
    _setBusy(true);
    _errorMessage = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('selected_role', 'fleet');

      // Default: send OTP to SMS first
      final cleanPhone = TermiiService.formatToLocal11Digits(phone.trim());
      final userEmail = email.trim();

      if (cleanPhone.isNotEmpty) {
        final result = await TermiiService.instance.sendOtp(cleanPhone);
        pendingChallenge = AuthChallenge(
          challengeId: result.pinId,
          email: userEmail.isNotEmpty ? userEmail : '$cleanPhone@phone.caride.com',
          phone: cleanPhone,
          expiresAt: DateTime.now().add(const Duration(minutes: 10)),
          isSignUp: true,
          channel: 'sms',
        );
      } else if (userEmail.isNotEmpty) {
        pendingChallenge = await _repository.requestEmailOtp(
          email: userEmail,
          isSignUp: true,
          referredByCode: referralCode.trim().isNotEmpty ? referralCode.trim() : null,
        );
      }

      if (pendingChallenge != null) {
        await PendingOtpSessionService.instance.saveSession(
          PendingOtpSession(
            challenge: pendingChallenge!,
            role: 'fleet',
            tempPassword: password,
            referralCode: referralCode.trim().isNotEmpty ? referralCode.trim() : null,
            phone: cleanPhone,
            email: userEmail.isNotEmpty ? userEmail : null,
            fullName: fullName,
            savedAt: DateTime.now(),
          ),
        );
      }
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      rethrow;
    } finally {
      _setBusy(false);
    }
  }

  /// Switches OTP delivery from SMS to email. Keeps all session data.
  Future<void> switchToEmailOtp() async {
    final userEmail = email.trim();
    if (userEmail.isEmpty) {
      throw Exception('No email address available to switch to.');
    }
    _setBusy(true);
    _errorMessage = null;
    try {
      pendingChallenge = await _repository.requestEmailOtp(
        email: userEmail,
        isSignUp: true,
        referredByCode: referralCode.trim().isNotEmpty ? referralCode.trim() : null,
      );
      if (pendingChallenge != null) {
        await PendingOtpSessionService.instance.saveSession(
          PendingOtpSession(
            challenge: pendingChallenge!,
            role: 'fleet',
            tempPassword: password,
            referralCode: referralCode.trim().isNotEmpty ? referralCode.trim() : null,
            phone: phone.trim().isNotEmpty ? phone.trim() : null,
            email: userEmail,
            fullName: fullName,
            savedAt: DateTime.now(),
          ),
        );
      }
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      rethrow;
    } finally {
      _setBusy(false);
    }
  }

  /// Switches OTP delivery from email to SMS. Keeps all session data.
  Future<void> switchToPhoneOtp() async {
    final userPhone = phone.trim();
    if (userPhone.isEmpty) {
      throw Exception('No phone number available to switch to.');
    }
    _setBusy(true);
    _errorMessage = null;
    try {
      final cleanPhone = TermiiService.formatToLocal11Digits(userPhone);
      final result = await TermiiService.instance.sendOtp(cleanPhone);
      pendingChallenge = AuthChallenge(
        challengeId: result.pinId,
        email: '$cleanPhone@phone.caride.com',
        phone: cleanPhone,
        expiresAt: DateTime.now().add(const Duration(minutes: 10)),
        isSignUp: true,
        channel: 'sms',
      );
      await PendingOtpSessionService.instance.saveSession(
        PendingOtpSession(
          challenge: pendingChallenge!,
          role: 'fleet',
          tempPassword: password,
          referralCode: referralCode.trim().isNotEmpty ? referralCode.trim() : null,
          phone: cleanPhone,
          email: email.trim().isNotEmpty ? email.trim() : null,
          fullName: fullName,
          savedAt: DateTime.now(),
        ),
      );
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      rethrow;
    } finally {
      _setBusy(false);
    }
  }

  /// Restores pending fleet OTP session from storage if it exists and has not expired.
  Future<bool> restorePendingSession() async {
    final session = await PendingOtpSessionService.instance.loadSession(roleFilter: 'fleet');
    if (session != null) {
      pendingChallenge = session.challenge;
      // Restore the user's real email (session.email), not the synthetic one
      if (session.email != null && session.email!.isNotEmpty) {
        email = session.email!;
      } else if (!session.challenge.isSms) {
        email = session.challenge.email;
      }
      if (session.phone != null && session.phone!.isNotEmpty) {
        phone = session.phone!;
      }
      if (session.tempPassword != null) {
        password = session.tempPassword!;
        confirmPassword = session.tempPassword!;
      }
      if (session.referralCode != null) {
        referralCode = session.referralCode!;
      }
      if (session.fullName != null && session.fullName!.isNotEmpty) {
        fullName = session.fullName!;
      }
      currentSignupStep = 1;
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<void> verifySignupOtp(String code) async {
    final challenge = pendingChallenge;
    if (challenge == null) {
      throw StateError('No active OTP challenge found.');
    }

    _setBusy(true);
    _errorMessage = null;
    try {
      if (challenge.isSms) {
        // 1. Verify code via Termii
        await TermiiService.instance.verifyOtp(
          pinId: challenge.challengeId,
          code: code,
        );

        // 2. Sign in or create Firebase Auth user
        final cleanPhone = challenge.phone ?? TermiiService.formatToLocal11Digits(challenge.email);
        final syntheticEmail = '$cleanPhone@phone.caride.com';
        final pwd = password.isNotEmpty ? password : 'Caride@${cleanPhone.length >= 6 ? cleanPhone.substring(cleanPhone.length - 6) : "123456"}';

        try {
          await FirebaseAuth.instance.signInWithEmailAndPassword(
            email: syntheticEmail,
            password: pwd,
          );
        } catch (_) {
          try {
            await FirebaseAuth.instance.createUserWithEmailAndPassword(
              email: syntheticEmail,
              password: pwd,
            );
          } on FirebaseAuthException catch (fe) {
            if (fe.code == 'email-already-in-use') {
              await FirebaseAuth.instance.signInWithEmailAndPassword(
                email: syntheticEmail,
                password: pwd,
              );
            } else {
              rethrow;
            }
          }
        }

        pendingChallenge = null;
        await PendingOtpSessionService.instance.clearSession();

        // 3. Provision fleet user
        await _repository.provisionFleetUserAfterOtp(
          email: syntheticEmail,
          password: pwd,
        );

        notifyListeners();
        return;
      }

      await _repository.verifyEmailOtp(
        challenge: challenge,
        code: code,
      );
      pendingChallenge = null;
      await PendingOtpSessionService.instance.clearSession();

      // After OTP verification, immediately provision the user metadata
      // document so that CustomerAuthController sees activeRole='fleet'
      // and does NOT redirect to the customer home screen.
      await _repository.provisionFleetUserAfterOtp(
        email: email.trim(),
        password: password,
      );

      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      rethrow;
    } finally {
      _setBusy(false);
    }
  }

  /// Saves the current signup draft data to Firestore.
  /// Called progressively after each signup step to persist partial data.
  Future<void> saveSignupDraft() async {
    final uid = _repository.currentUser?.uid;
    if (uid == null) return;
    try {
      await _repository.saveFleetSignupDraft(
        uid: uid,
        email: email.trim(),
        businessType: businessType,
        fullName: fullName.trim(),
        phone: phone.trim(),
        gender: gender,
        companyName: companyName.trim(),
        companyAddress: companyAddress.trim(),
        rcNumber: rcNumber.trim(),
        identityDocumentType: identityDocumentType,
        signupStep: currentSignupStep,
      );
    } catch (e) {
      debugPrint('saveSignupDraft error: $e');
    }
  }

  /// Loads saved signup draft from Firestore and restores the form fields and step.
  Future<void> loadSignupDraft() async {
    final uid = _repository.currentUser?.uid;
    if (uid == null) return;
    try {
      final draft = await _repository.getFleetSignupDraft(uid);
      if (draft != null) {
        if (draft['businessType'] != null && (draft['businessType'] as String).isNotEmpty) {
          businessType = draft['businessType'] as String;
        }
        if (draft['fullName'] != null && (draft['fullName'] as String).isNotEmpty) {
          fullName = draft['fullName'] as String;
        }
        if (draft['phone'] != null && (draft['phone'] as String).isNotEmpty) {
          phone = draft['phone'] as String;
        }
        if (draft['gender'] != null && (draft['gender'] as String).isNotEmpty) {
          gender = draft['gender'] as String;
        }
        if (draft['businessName'] != null && (draft['businessName'] as String).isNotEmpty) {
          companyName = draft['businessName'] as String;
        }
        if (draft['address'] != null && (draft['address'] as String).isNotEmpty) {
          companyAddress = draft['address'] as String;
        }
        if (draft['registrationNumber'] != null && (draft['registrationNumber'] as String).isNotEmpty) {
          rcNumber = draft['registrationNumber'] as String;
        }
        if (draft['identityDocumentType'] != null && (draft['identityDocumentType'] as String).isNotEmpty) {
          identityDocumentType = draft['identityDocumentType'] as String;
        }
        if (draft['email'] != null && (draft['email'] as String).isNotEmpty) {
          email = draft['email'] as String;
        }
        final savedStep = draft['signupStep'] as int?;
        if (savedStep != null && savedStep > 0) {
          currentSignupStep = savedStep;
        } else if (_repository.currentUser != null && currentSignupStep == 0) {
          // If already authenticated via Firebase Auth, resume at Step 1 (Business Structure)
          currentSignupStep = 1;
        }
        notifyListeners();
      } else if (_repository.currentUser != null && currentSignupStep == 0) {
        // Authenticated user with no draft: start at Step 1 (Business Structure)
        currentSignupStep = 1;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('loadSignupDraft error: $e');
    }
  }

  Future<FleetProfile> submitFleetApplication() async {
    final uid = _repository.currentUser?.uid;
    if (uid == null) {
      throw StateError('User must be authenticated before submitting fleet application.');
    }

    _setBusy(true);
    _errorMessage = null;
    try {
      final isCompany = businessType.toLowerCase() == 'company';
      final draft = FleetProfile(
        fleetId: _currentProfile?.fleetId ?? '',
        ownerUid: uid,
        businessName: isCompany ? companyName.trim() : '$fullName\'s Fleet',
        phone: phone.trim(),
        email: email.trim().isNotEmpty ? email.trim() : (_repository.currentUser?.email ?? ''),
        businessType: businessType,
        fullName: fullName.trim(),
        gender: gender,
        registrationNumber: isCompany ? rcNumber.trim() : '',
        address: companyAddress.trim(),
        state: 'FCT (Abuja)',
        city: 'Abuja',
        identityDocumentType: identityDocumentType,
        verificationStatus: 'pending',
        referredByCode: referralCode.trim().isNotEmpty ? referralCode.trim() : null,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final result = await _repository.submitFleetApplication(
        uid: uid,
        profileDraft: draft,
        profilePhotoFile: profilePhotoFile,
        companyLogoFile: isCompany ? companyLogoFile : null,
        identityDocFile: identityDocumentFile,
        cacDocFile: isCompany ? cacDocumentFile : null,
      );

      _currentProfile = result;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('selected_role', 'fleet');
      notifyListeners();
      return result;
    } catch (e) {
      _errorMessage = e.toString();
      rethrow;
    } finally {
      _setBusy(false);
    }
  }

  Future<void> signInWithEmailAndPassword(String emailInput, String passInput) async {
    _setBusy(true);
    _errorMessage = null;
    try {
      String resolved = emailInput.trim();
      final isPhone = TermiiService.isPhoneNumber(resolved);
      if (isPhone) {
        final cleanPhone = TermiiService.formatToLocal11Digits(resolved);
        resolved = '$cleanPhone@phone.caride.com';
      }

      try {
        await _repository.signInWithEmailAndPassword(
          email: resolved,
          password: passInput,
        );
      } catch (authError) {
        // If user entered a real email, check if fleet account was created via phone OTP
        if (!isPhone && resolved.contains('@') && !resolved.endsWith('@phone.caride.com')) {
          final cleanInputEmail = resolved.toLowerCase();
          final firestore = FirebaseFirestore.instance;

          String? matchedPhone;
          try {
            final fleetSnap = await firestore
                .collection('fleet_managers')
                .where('email', isEqualTo: cleanInputEmail)
                .limit(1)
                .get();

            if (fleetSnap.docs.isNotEmpty) {
              matchedPhone = fleetSnap.docs.first.data()['phone'] as String?;
            }

            if (matchedPhone == null || matchedPhone.isEmpty) {
              final userSnap = await firestore
                  .collection('users')
                  .where('email', isEqualTo: cleanInputEmail)
                  .limit(1)
                  .get();
              if (userSnap.docs.isNotEmpty) {
                matchedPhone = userSnap.docs.first.data()['phone'] as String?;
              }
            }
          } catch (_) {}

          if (matchedPhone != null && matchedPhone.isNotEmpty) {
            final formattedPhone = TermiiService.formatToLocal11Digits(matchedPhone);
            final syntheticEmail = '$formattedPhone@phone.caride.com';

            await _repository.signInWithEmailAndPassword(
              email: syntheticEmail,
              password: passInput,
            );

            // Attempt to link real email credential
            try {
              final user = FirebaseAuth.instance.currentUser;
              if (user != null) {
                final emailCred = EmailAuthProvider.credential(
                  email: cleanInputEmail,
                  password: passInput,
                );
                await user.linkWithCredential(emailCred);
              }
            } catch (_) {}
          } else {
            rethrow;
          }
        } else {
          rethrow;
        }
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('selected_role', 'fleet');
      notifyListeners();
    } catch (e) {
      _errorMessage = e.toString();
      rethrow;
    } finally {
      _setBusy(false);
    }
  }


  Future<void> sendPasswordResetEmail(String emailInput) async {
    _setBusy(true);
    _errorMessage = null;
    try {
      await _repository.sendPasswordResetEmail(emailInput.trim());
    } catch (e) {
      _errorMessage = e.toString();
      rethrow;
    } finally {
      _setBusy(false);
    }
  }

  Future<void> signOut() async {
    resetDraft();
    pendingChallenge = null;
    fleetManagerController.reset();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('selected_role');
      await prefs.remove('dismissed_popup_announcements');
    } catch (_) {}

    try {
      await PendingOtpSessionService.instance.clearSession();
    } catch (_) {}

    try {
      await _repository.signOut();
    } catch (e) {
      debugPrint('[FleetAuthController] Error during repository signOut: $e');
    }

    try {
      await customerAuthController.signOut();
    } catch (_) {}

    notifyListeners();
  }

  void _setBusy(bool value) {
    if (_isBusy == value) return;
    _isBusy = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _profileSub?.cancel();
    super.dispose();
  }
}

final fleetAuthController = FleetAuthController();
