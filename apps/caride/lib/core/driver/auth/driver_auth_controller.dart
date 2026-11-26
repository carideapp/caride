import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_challenge.dart';
import 'auth_repository.dart';
import '../../auth/account_lockout_exception.dart';
import '../../auth/pending_otp_session.dart';
import '../../auth/customer_auth_controller.dart';
import '../../config/app_env.dart';
import '../../services/termii_service.dart';

class DriverAuthController extends ChangeNotifier {
  DriverAuthController({DriverAuthRepository? repository})
    : _repository = repository ?? DriverAuthRepository() {
    _sub = _repository.authStateChanges().listen((_) => notifyListeners());
  }

  final DriverAuthRepository _repository;
  StreamSubscription<Object?>? _sub;

  AuthChallenge? _pendingChallenge;
  bool _isBusy = false;
  String? _pendingReferralCode;
  String? _pendingFullName;
  String? _pendingPhone;
  String? _tempEmail;
  String? _tempPassword;
  String? _tempUsername;
  String? _tempCountry;
  String? _tempState;
  String? _tempProfilePhotoUrl;

  bool get isAuthenticated => _repository.currentUser != null;
  bool get isBusy => _isBusy;
  AuthChallenge? get pendingChallenge => _pendingChallenge;
  String? get currentUid => _repository.currentUser?.uid;
  String? get currentEmail => _repository.currentUser?.email;
  String? get pendingReferralCode => _pendingReferralCode;
  String? get pendingFullName => _pendingFullName;
  String? get pendingPhone => _pendingPhone;
  String? get pendingEmail => _tempEmail;
  String? get tempPassword => _tempPassword;
  String? get tempUsername => _tempUsername;

  Future<void> requestOtpForSignup(
    String phone,
    String email, {
    String? referralCode,
    String? fullName,
    String? password,
    String? username,
    String? country,
    String? state,
    String? profilePhotoUrl,
  }) async {
    _pendingReferralCode = referralCode?.trim().isEmpty == true
        ? null
        : referralCode?.trim().toUpperCase();
    _pendingFullName = fullName?.trim().isEmpty == true
        ? null
        : fullName?.trim();
    if (email.trim().isNotEmpty) _tempEmail = email.trim();
    if (password != null) _tempPassword = password;
    if (username != null) _tempUsername = username;
    if (country != null) _tempCountry = country;
    if (state != null) _tempState = state;
    if (profilePhotoUrl != null) _tempProfilePhotoUrl = profilePhotoUrl;

    // Default: send OTP to SMS first
    final cleanPhone = TermiiService.formatToLocal11Digits(phone.trim());
    _pendingPhone = cleanPhone;
    _setBusy(true);
    try {
      if (cleanPhone.isNotEmpty) {
        try {
          final result = await TermiiService.instance.sendOtp(cleanPhone);
          _pendingChallenge = AuthChallenge(
            challengeId: result.pinId,
            email: (_tempEmail != null && _tempEmail!.isNotEmpty)
                ? _tempEmail!
                : '$cleanPhone@phone.caride.com',
            phone: cleanPhone,
            expiresAt: DateTime.now().add(const Duration(minutes: 10)),
            isSignUp: true,
            channel: 'sms',
          );
        } catch (smsError) {
          debugPrint(
            '[DriverAuthController] SMS OTP failed ($smsError). Trying email fallback...',
          );
          final targetEmail = _tempEmail;
          if (targetEmail != null && targetEmail.isNotEmpty) {
            _pendingChallenge = await _repository.requestEmailOtp(
              email: targetEmail,
              isSignUp: true,
            );
          } else {
            rethrow;
          }
        }
      } else {
        final targetEmail = _tempEmail;
        if (targetEmail != null && targetEmail.isNotEmpty) {
          _pendingChallenge = await _repository.requestEmailOtp(
            email: targetEmail,
            isSignUp: true,
          );
        }
      }

      if (_pendingChallenge != null) {
        await PendingOtpSessionService.instance.saveSession(
          PendingOtpSession(
            challenge: _pendingChallenge!,
            role: 'driver',
            tempPassword: _tempPassword,
            referralCode: _pendingReferralCode,
            fullName: _pendingFullName,
            phone: cleanPhone,
            email: _tempEmail,
            username: _tempUsername,
            country: _tempCountry,
            state: _tempState,
            savedAt: DateTime.now(),
          ),
        );
      }
      notifyListeners();
    } finally {
      _setBusy(false);
    }
  }

  /// Switches OTP delivery from SMS to email. Keeps all session data.
  Future<void> switchToEmailOtp() async {
    final email = _tempEmail;
    if (email == null || email.isEmpty) {
      throw Exception('No email address available to switch to.');
    }
    _setBusy(true);
    try {
      _pendingChallenge = await _repository.requestEmailOtp(
        email: email,
        isSignUp: true,
      );
      if (_pendingChallenge != null) {
        await PendingOtpSessionService.instance.saveSession(
          PendingOtpSession(
            challenge: _pendingChallenge!,
            role: 'driver',
            tempPassword: _tempPassword,
            referralCode: _pendingReferralCode,
            fullName: _pendingFullName,
            phone: _pendingPhone,
            email: _tempEmail,
            username: _tempUsername,
            country: _tempCountry,
            state: _tempState,
            savedAt: DateTime.now(),
          ),
        );
      }
      notifyListeners();
    } finally {
      _setBusy(false);
    }
  }

  /// Switches OTP delivery from email to SMS. Keeps all session data.
  Future<void> switchToPhoneOtp() async {
    final phone = _pendingPhone;
    if (phone == null || phone.isEmpty) {
      throw Exception('No phone number available to switch to.');
    }
    _setBusy(true);
    try {
      final cleanPhone = TermiiService.formatToLocal11Digits(phone);
      final result = await TermiiService.instance.sendOtp(cleanPhone);
      _pendingChallenge = AuthChallenge(
        challengeId: result.pinId,
        email: '$cleanPhone@phone.caride.com',
        phone: cleanPhone,
        expiresAt: DateTime.now().add(const Duration(minutes: 10)),
        isSignUp: true,
        channel: 'sms',
      );
      await PendingOtpSessionService.instance.saveSession(
        PendingOtpSession(
          challenge: _pendingChallenge!,
          role: 'driver',
          tempPassword: _tempPassword,
          referralCode: _pendingReferralCode,
          fullName: _pendingFullName,
          phone: cleanPhone,
          email: _tempEmail,
          username: _tempUsername,
          country: _tempCountry,
          state: _tempState,
          savedAt: DateTime.now(),
        ),
      );
      notifyListeners();
    } finally {
      _setBusy(false);
    }
  }

  Future<void> requestOtpForLogin(String emailOrPhone) {
    final trimmed = emailOrPhone.trim();
    if (TermiiService.isPhoneNumber(trimmed)) {
      return requestOtpForSignup(trimmed, '');
    }
    _pendingReferralCode = null;
    return _requestOtp(email: trimmed, isSignUp: false);
  }

  Future<void> resendPendingOtp() async {
    final challenge = _pendingChallenge;
    if (challenge == null) return;
    if (challenge.isSms && challenge.phone != null) {
      final cleanPhone = challenge.phone!;
      _setBusy(true);
      try {
        final result = await TermiiService.instance.sendOtp(cleanPhone);
        _pendingChallenge = AuthChallenge(
          challengeId: result.pinId,
          email: '$cleanPhone@phone.caride.com',
          phone: cleanPhone,
          expiresAt: DateTime.now().add(const Duration(minutes: 10)),
          isSignUp: challenge.isSignUp,
          channel: 'sms',
        );
        await PendingOtpSessionService.instance.saveSession(
          PendingOtpSession(
            challenge: _pendingChallenge!,
            role: 'driver',
            tempPassword: _tempPassword,
            referralCode: _pendingReferralCode,
            fullName: _pendingFullName,
            phone: cleanPhone,
            email: _tempEmail,
            username: _tempUsername,
            country: _tempCountry,
            state: _tempState,
            savedAt: DateTime.now(),
          ),
        );
        notifyListeners();
      } finally {
        _setBusy(false);
      }
    } else {
      if (challenge.isSignUp) {
        final email = _tempEmail ?? challenge.email;
        _setBusy(true);
        try {
          _pendingChallenge = await _repository.requestEmailOtp(
            email: email,
            isSignUp: true,
          );
          if (_pendingChallenge != null) {
            await PendingOtpSessionService.instance.saveSession(
              PendingOtpSession(
                challenge: _pendingChallenge!,
                role: 'driver',
                tempPassword: _tempPassword,
                referralCode: _pendingReferralCode,
                fullName: _pendingFullName,
                phone: _pendingPhone,
                email: _tempEmail,
                username: _tempUsername,
                country: _tempCountry,
                state: _tempState,
                savedAt: DateTime.now(),
              ),
            );
          }
          notifyListeners();
        } finally {
          _setBusy(false);
        }
      } else {
        await requestOtpForLogin(challenge.email);
      }
    }
  }

  Future<void> _requestOtp({
    required String email,
    required bool isSignUp,
  }) async {
    _setBusy(true);
    try {
      _pendingChallenge = await _repository.requestEmailOtp(
        email: email,
        isSignUp: isSignUp,
      );
      if (_pendingChallenge != null) {
        await PendingOtpSessionService.instance.saveSession(
          PendingOtpSession(
            challenge: _pendingChallenge!,
            role: 'driver',
            tempPassword: _tempPassword,
            referralCode: _pendingReferralCode,
            fullName: _pendingFullName,
            phone: _pendingPhone,
            username: _tempUsername,
            country: _tempCountry,
            state: _tempState,
            savedAt: DateTime.now(),
          ),
        );
      }
      notifyListeners();
    } finally {
      _setBusy(false);
    }
  }

  /// Restores pending driver OTP session from storage if it exists and has not expired.
  Future<bool> restorePendingSession() async {
    final session = await PendingOtpSessionService.instance.loadSession(
      roleFilter: 'driver',
    );
    if (session != null) {
      _pendingChallenge = session.challenge;
      _pendingReferralCode = session.referralCode;
      _pendingFullName = session.fullName;
      _pendingPhone = session.phone ?? session.challenge.phone;
      _tempEmail = session.email;
      _tempPassword = session.tempPassword;
      _tempUsername = session.username;
      _tempCountry = session.country;
      _tempState = session.state;
      notifyListeners();
      return true;
    }
    return false;
  }

  Future<void> verifyPendingOtp(String code) async {
    final challenge = _pendingChallenge;
    if (challenge == null) {
      throw StateError('There is no active OTP challenge.');
    }

    _setBusy(true);
    try {
      if (challenge.isSms) {
        // 1. Verify 6-digit code via Termii
        await TermiiService.instance.verifyOtp(
          pinId: challenge.challengeId,
          code: code,
        );

        // 2. Sign in or create Firebase Auth user with phone-based synthetic email
        final cleanPhone =
            challenge.phone ??
            TermiiService.formatToLocal11Digits(challenge.email);
        final syntheticEmail = '$cleanPhone@phone.caride.com';
        final pwd =
            _tempPassword ??
            'Caride@${cleanPhone.length >= 6 ? cleanPhone.substring(cleanPhone.length - 6) : "123456"}';

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

        // 3. Provision driver profile doc in Firestore
        await _repository.provisionDriverProfile(
          email:
              (_tempEmail != null &&
                  _tempEmail!.trim().isNotEmpty &&
                  !_tempEmail!.trim().endsWith('@phone.caride.com'))
              ? _tempEmail!.trim()
              : '',
          referralCode: _pendingReferralCode,
          fullName: _pendingFullName,
          phone: cleanPhone,
          username: _tempUsername,
          country: _tempCountry,
          state: _tempState,
          profilePhotoUrl: _tempProfilePhotoUrl,
        );
        await clearPendingChallenge();
        return;
      }

      await _repository.verifyEmailOtp(
        challenge: challenge,
        code: code,
        referralCode: _pendingReferralCode,
        fullName: _pendingFullName,
        phone: _pendingPhone,
      );
      await clearPendingChallenge();
    } finally {
      _setBusy(false);
    }
  }

  Future<void> clearPendingChallenge() async {
    _pendingChallenge = null;
    _pendingReferralCode = null;
    _pendingFullName = null;
    _pendingPhone = null;
    _tempEmail = null;
    _tempPassword = null;
    _tempUsername = null;
    _tempCountry = null;
    _tempState = null;
    _tempProfilePhotoUrl = null;
    await PendingOtpSessionService.instance.clearSession();
    notifyListeners();
  }

  Future<void> signInWithEmailAndPassword(
    String emailOrPhone,
    String password,
  ) async {
    _setBusy(true);
    try {
      String resolved = emailOrPhone.trim();
      final isPhone = TermiiService.isPhoneNumber(resolved);
      if (isPhone) {
        final cleanPhone = TermiiService.formatToLocal11Digits(resolved);
        resolved = '$cleanPhone@phone.caride.com';
      }

      try {
        await _repository.signInWithEmailAndPassword(
          email: resolved,
          password: password,
        );
      } catch (authError) {
        if (AccountLockoutHelper.isLockout(authError)) {
          rethrow;
        }
        // If user entered a real email, check if driver account was created via phone OTP
        if (!isPhone &&
            resolved.contains('@') &&
            !resolved.endsWith('@phone.caride.com')) {
          final cleanInputEmail = resolved.toLowerCase();
          final firestore = FirebaseFirestore.instance;

          String? matchedPhone;
          try {
            final driverSnap = await firestore
                .collection('drivers')
                .where('email', isEqualTo: cleanInputEmail)
                .limit(1)
                .get();

            if (driverSnap.docs.isNotEmpty) {
              matchedPhone = driverSnap.docs.first.data()['phone'] as String?;
            }

            if (matchedPhone == null || matchedPhone.isEmpty) {
              final customerSnap = await firestore
                  .collection('customers')
                  .where('email', isEqualTo: cleanInputEmail)
                  .limit(1)
                  .get();
              if (customerSnap.docs.isNotEmpty) {
                matchedPhone =
                    customerSnap.docs.first.data()['phone'] as String?;
              }
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
            final formattedPhone = TermiiService.formatToLocal11Digits(
              matchedPhone,
            );
            final syntheticEmail = '$formattedPhone@phone.caride.com';

            // Sign in using the phone-based synthetic account
            await _repository.signInWithEmailAndPassword(
              email: syntheticEmail,
              password: password,
            );

            // Attempt to link real email credential
            try {
              final user = FirebaseAuth.instance.currentUser;
              if (user != null) {
                final emailCred = EmailAuthProvider.credential(
                  email: cleanInputEmail,
                  password: password,
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
    } finally {
      _setBusy(false);
    }
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
    _setBusy(true);
    try {
      await _repository.signUpWithEmailAndPassword(
        email: email,
        password: password,
        referralCode: referralCode,
        fullName: fullName,
        phone: phone,
        username: username,
        country: country,
        state: state,
        coverPhotoUrl: coverPhotoUrl,
      );
    } finally {
      _setBusy(false);
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    _setBusy(true);
    try {
      await _repository.sendPasswordResetEmail(email);
    } finally {
      _setBusy(false);
    }
  }

  String? _verifiedResetCode;
  String? get verifiedResetCode => _verifiedResetCode;
  void setVerifiedResetCode(String code) => _verifiedResetCode = code;

  /// Requests a password reset OTP sent via SMS to the driver's registered phone number.
  Future<void> requestPasswordResetPhoneOtp(String phone) async {
    final cleanPhone = TermiiService.formatToLocal11Digits(phone.trim());
    if (cleanPhone.length != 11 || !cleanPhone.startsWith('0')) {
      throw Exception('Please enter a valid 11-digit phone number (e.g. 08012345678).');
    }

    _setBusy(true);
    try {
      // 1. Verify that a driver account exists for this phone number
      final driverSnap = await FirebaseFirestore.instance
          .collection('drivers')
          .where('phone', isEqualTo: cleanPhone)
          .limit(1)
          .get();

      if (driverSnap.docs.isEmpty) {
        final userSnap = await FirebaseFirestore.instance
            .collection('users')
            .where('phone', isEqualTo: cleanPhone)
            .limit(1)
            .get();

        if (userSnap.docs.isEmpty) {
          throw Exception('No driver account found registered with this phone number.');
        }
      }

      // 2. Dispatch OTP via Termii SMS
      final result = await TermiiService.instance.sendOtp(cleanPhone);
      _pendingChallenge = AuthChallenge(
        challengeId: result.pinId,
        email: '$cleanPhone@phone.caride.com',
        phone: cleanPhone,
        expiresAt: DateTime.now().add(const Duration(minutes: 10)),
        isSignUp: false,
        isPasswordReset: true,
        channel: 'sms',
      );
      _pendingPhone = cleanPhone;

      await PendingOtpSessionService.instance.saveSession(
        PendingOtpSession(
          challenge: _pendingChallenge!,
          role: 'driver',
          phone: cleanPhone,
          savedAt: DateTime.now(),
        ),
      );
      notifyListeners();
    } finally {
      _setBusy(false);
    }
  }

  /// Verifies the OTP code for password reset.
  Future<void> verifyPasswordResetOtp(String code) async {
    final challenge = _pendingChallenge;
    if (challenge == null) {
      throw Exception('Session expired. Please request a new verification code.');
    }

    _setBusy(true);
    try {
      await TermiiService.instance.verifyOtp(
        pinId: challenge.challengeId,
        code: code.trim(),
      );
      _verifiedResetCode = code.trim();
      notifyListeners();
    } finally {
      _setBusy(false);
    }
  }

  /// Resets the driver password using verified phone OTP.
  Future<void> resetPasswordWithPhoneOtp(String newPassword) async {
    final challenge = _pendingChallenge;
    final phone = challenge?.phone ?? _pendingPhone;
    final pinId = challenge?.challengeId;
    final code = _verifiedResetCode;

    if (phone == null || pinId == null || code == null) {
      throw Exception('Verification details missing. Please start password reset again.');
    }

    _setBusy(true);
    try {
      final callable = FirebaseFunctions.instanceFor(region: AppEnv.firebaseFunctionsRegion)
          .httpsCallable('resetPasswordWithPhoneOtp');
      await callable.call<Map<String, dynamic>>({
        'phone': phone,
        'pinId': pinId,
        'code': code,
        'newPassword': newPassword.trim(),
        'role': 'driver',
      });

      _pendingChallenge = null;
      _verifiedResetCode = null;
      _pendingPhone = null;
      await PendingOtpSessionService.instance.clearSession();
      notifyListeners();
    } finally {
      _setBusy(false);
    }
  }

  /// Provisions a customer profile for an existing driver account.
  /// Uses the driver's existing profile data (email, fullName, phone) and
  /// updates customerExists in the users metadata document.
  Future<void> becomeCustomer({
    required String email,
    String? fullName,
    String? phone,
    String? profilePhotoUrl,
  }) async {
    _setBusy(true);
    try {
      await _repository.becomeCustomer(
        email: email,
        fullName: fullName,
        phone: phone,
        profilePhotoUrl: profilePhotoUrl,
      );
    } finally {
      _setBusy(false);
    }
  }

  Future<void> signOut() async {
    _pendingChallenge = null;
    _pendingReferralCode = null;
    _pendingFullName = null;
    _pendingPhone = null;
    _tempEmail = null;
    _tempPassword = null;
    _tempUsername = null;
    _tempCountry = null;
    _tempState = null;
    _tempProfilePhotoUrl = null;

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('selected_role');
      await prefs.remove('dismissed_popup_announcements');
    } catch (e) {
      debugPrint('[DriverAuthController] Error clearing preferences: $e');
    }

    try {
      await PendingOtpSessionService.instance.clearSession();
    } catch (_) {}

    try {
      await _repository.signOut();
    } catch (e) {
      debugPrint('[DriverAuthController] Error during repository signOut: $e');
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
    _sub?.cancel();
    super.dispose();
  }
}

final driverAuthController = DriverAuthController();
