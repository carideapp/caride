import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_challenge.dart';
import 'auth_repository.dart';

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

  bool get isAuthenticated => _repository.currentUser != null;
  bool get isBusy => _isBusy;
  AuthChallenge? get pendingChallenge => _pendingChallenge;
  String? get currentUid => _repository.currentUser?.uid;
  String? get currentEmail => _repository.currentUser?.email;
  String? get pendingReferralCode => _pendingReferralCode;
  String? get pendingFullName => _pendingFullName;
  String? get pendingPhone => _pendingPhone;

  Future<void> requestOtpForSignup(
    String email, {
    String? referralCode,
    String? fullName,
    String? phone,
  }) {
    _pendingReferralCode = referralCode?.trim().isEmpty == true ? null : referralCode?.trim().toUpperCase();
    _pendingFullName = fullName?.trim().isEmpty == true ? null : fullName?.trim();
    _pendingPhone = phone?.trim().isEmpty == true ? null : phone?.trim();
    return _requestOtp(email: email, isSignUp: true);
  }

  Future<void> requestOtpForLogin(String email) {
    _pendingReferralCode = null;
    return _requestOtp(email: email, isSignUp: false);
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
      notifyListeners();
    } finally {
      _setBusy(false);
    }
  }

  Future<void> verifyPendingOtp(String code) async {
    final challenge = _pendingChallenge;
    if (challenge == null) {
      throw StateError('There is no active OTP challenge.');
    }

    _setBusy(true);
    try {
      await _repository.verifyEmailOtp(
        challenge: challenge,
        code: code,
        referralCode: _pendingReferralCode,
        fullName: _pendingFullName,
        phone: _pendingPhone,
      );
      _pendingChallenge = null;
      notifyListeners();
    } finally {
      _setBusy(false);
    }
  }

  void clearPendingChallenge() {
    _pendingChallenge = null;
    _pendingReferralCode = null;
    _pendingFullName = null;
    _pendingPhone = null;
    notifyListeners();
  }

  Future<void> signInWithEmailAndPassword(String email, String password) async {
    _setBusy(true);
    try {
      await _repository.signInWithEmailAndPassword(email: email, password: password);
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
  }) async {
    _setBusy(true);
    try {
      await _repository.signUpWithEmailAndPassword(
        email: email,
        password: password,
        referralCode: referralCode,
        fullName: fullName,
        phone: phone,
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
    // Wipe all locally cached credentials and user-scoped preferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('selected_role');
    await prefs.remove('dismissed_popup_announcements');
    await _repository.signOut();
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
