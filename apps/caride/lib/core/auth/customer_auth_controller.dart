import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/profile/data/account_repository.dart';
import '../services/deep_link_service.dart';

import 'auth_challenge.dart';
import 'auth_repository.dart';

class CustomerAuthController extends ChangeNotifier {
  CustomerAuthController({AuthRepository? repository})
    : _repository = repository ?? AuthRepository() {
    _sub = _repository.authStateChanges().listen((user) {
      _profileSub?.cancel();
      _metadataSub?.cancel();
      _currentProfile = null;
      _profileLoaded = false;
      _metadataLoaded = false;
      _loadedUid = user?.uid;

      if (user != null) {
        // 1. Watch the lightweight metadata document
        _metadataSub = FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .snapshots()
            .listen((snap) {
          if (snap.exists) {
            final data = snap.data() ?? {};
            _activeRole = data['activeRole'] as String? ?? 'customer';
            _customerExists = data['customerExists'] as bool? ?? true;
            _driverExists = data['driverExists'] as bool? ?? false;
            _fleetExists = (data['hasFleet'] as bool? ?? false) ||
                (data['fleetExists'] as bool? ?? false) ||
                (data['fleetId'] as String? ?? '').isNotEmpty;
          } else {
            // Default if metadata does not exist yet
            _activeRole = 'customer';
            _customerExists = true;
            _driverExists = false;
            _fleetExists = false;
          }
          _metadataLoaded = true;
          notifyListeners();

          // 2. Watch the profile based on the active role
          _profileSub?.cancel();
          if (_activeRole == 'customer') {
            _profileSub = _accountRepo.watchProfile().listen(
              (profile) {
                _currentProfile = profile;
                _profileLoaded = true;
                notifyListeners();
              },
              onError: (e) {
                debugPrint('Error listening to customer profile: $e');
                _profileLoaded = true;
                notifyListeners();
              },
            );
          } else if (_activeRole == 'fleet') {
            _profileLoaded = true;
            notifyListeners();
          } else {
            // Watch the driver profile document for onboarding and approval status
            _profileSub = FirebaseFirestore.instance
                .collection('drivers')
                .doc(user.uid)
                .snapshots()
                .listen((driverSnap) {
              if (driverSnap.exists) {
                final d = driverSnap.data() ?? {};
                _driverProfileCompleted = d['profileCompleted'] as bool? ?? false;
                _driverApprovalStatus = d['approvalStatus'] as String? ?? 'draft';
              } else {
                _driverProfileCompleted = false;
                _driverApprovalStatus = 'draft';
              }
              _profileLoaded = true;
              notifyListeners();
            });
          }
        }, onError: (e) {
          debugPrint('Error listening to user metadata: $e');
          _metadataLoaded = true;
          _profileLoaded = true;
          notifyListeners();
        });
      } else {
        _profileLoaded = true; // not signed in — no profile to wait for
        _metadataLoaded = true;
        _activeRole = 'customer';
        _customerExists = false;
        _driverExists = false;
        _driverProfileCompleted = false;
        _driverApprovalStatus = 'draft';
        notifyListeners();
      }
    });
  }

  final AuthRepository _repository;
  final AccountRepository _accountRepo = AccountRepository();
  StreamSubscription<Object?>? _sub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _metadataSub;
  StreamSubscription<dynamic>? _profileSub;
  
  AccountProfile? _currentProfile;
  bool _profileLoaded = false;
  bool _metadataLoaded = false;
  String? _loadedUid;

  String _activeRole = 'customer';
  bool _customerExists = false;
  bool _driverExists = false;
  bool _fleetExists = false;
  bool _driverProfileCompleted = false;
  String _driverApprovalStatus = 'draft';

  AccountProfile? get currentProfile => _currentProfile;
  bool get profileLoaded => _profileLoaded && _metadataLoaded && (_repository.currentUser == null || _loadedUid == _repository.currentUser?.uid);
  bool get isProfileComplete => true;
  
  String get activeRole => _activeRole;
  bool get customerExists => _customerExists;
  bool get driverExists => _driverExists;
  bool get fleetExists => _fleetExists;
  bool get driverProfileCompleted => _driverProfileCompleted;
  String get driverApprovalStatus => _driverApprovalStatus;

  AuthChallenge? _pendingChallenge;
  String? _tempPassword;
  String? _tempReferredByCode;
  String? tempFullName;
  String? tempPhone;
  File? tempPhotoFile;
  bool _isBusy = false;

  bool get isAuthenticated => _repository.currentUser != null;
  bool get isBusy => _isBusy;
  AuthChallenge? get pendingChallenge => _pendingChallenge;

  Future<String?> _resolveReferralCode(String? explicitCode) async {
    if (explicitCode != null && explicitCode.trim().isNotEmpty) {
      return explicitCode.trim().toUpperCase();
    }
    return await DeepLinkService.instance.getOrFetchPendingReferralCode();
  }

  Future<void> requestOtpForSignup(String email, [String? password, String? referredByCode]) async {
    if (password != null) {
      _tempPassword = password;
    }
    final resolvedCode = await _resolveReferralCode(referredByCode);
    _tempReferredByCode = resolvedCode;
    return _requestOtp(email: email, isSignUp: true, referredByCode: resolvedCode);
  }

  Future<void> requestOtpForLogin(String email) =>
      _requestOtp(email: email, isSignUp: false);

  Future<void> _requestOtp({
    required String email,
    required bool isSignUp,
    String? referredByCode,
  }) async {
    _setBusy(true);
    try {
      _pendingChallenge = await _repository.requestEmailOtp(
        email: email,
        isSignUp: isSignUp,
        referredByCode: referredByCode,
      );
      notifyListeners();
    } finally {
      _setBusy(false);
    }
  }

  Future<void> signInWithEmailAndPassword(String email, String password) async {
    _setBusy(true);
    try {
      await _repository.signInWithEmailAndPassword(email: email, password: password);
      _pendingChallenge = null;
      _tempPassword = null;
      _tempReferredByCode = null;
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
      final prefs = await SharedPreferences.getInstance();
      final selectedRole = prefs.getString('selected_role') ?? 'customer';

      await _repository.verifyEmailOtp(
        challenge: challenge,
        code: code,
        referredByCode: _tempReferredByCode,
        selectedRole: selectedRole,
        fullName: tempFullName,
        phone: tempPhone,
      );

      if (challenge.isSignUp) {
        await DeepLinkService.instance.clearPendingReferralCode();
      }

      if (challenge.isSignUp && _tempPassword != null) {
        try {
          await _repository.updatePassword(_tempPassword!);
        } catch (e) {
          debugPrint('Error updating password after OTP: $e');
        }
      }

      if (challenge.isSignUp && selectedRole == 'customer' && tempFullName != null && tempPhone != null && tempPhotoFile != null) {
        final photoUrl = await _accountRepo.uploadProfilePhoto(tempPhotoFile!);
        await _accountRepo.createProfile(
          fullName: tempFullName!,
          phone: tempPhone!,
          photoUrl: photoUrl,
        );
      }


      _tempPassword = null;
      _tempReferredByCode = null;
      tempFullName = null;
      tempPhone = null;
      tempPhotoFile = null;
      _pendingChallenge = null;
      notifyListeners();
    } finally {
      _setBusy(false);
    }
  }

  Future<void> switchRole(String role) async {
    final user = _repository.currentUser;
    if (user == null) {
      _activeRole = role;
      notifyListeners();
      return;
    }
    _setBusy(true);
    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'activeRole': role,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      _activeRole = role;
      notifyListeners();
    } catch (e) {
      debugPrint('[CustomerAuthController] Error switching role in Firestore: $e');
      _activeRole = role;
      notifyListeners();
    } finally {
      _setBusy(false);
    }
  }

  /// Provisions a driver profile for an existing customer account.
  /// Uses the customer's existing profile data (name, phone, email) and
  /// updates driverExists + activeRole in the users metadata document.
  Future<void> becomeDriver() async {
    final user = _repository.currentUser;
    if (user == null) return;
    _setBusy(true);
    try {
      final profile = _currentProfile;
      await _repository.provisionUserMetadataAndProfile(
        email: user.email ?? '',
        selectedRole: 'driver',
        fullName: profile?.fullName,
        phone: profile?.phone,
      );
      _driverExists = true;
      _activeRole = 'driver';
      notifyListeners();
    } finally {
      _setBusy(false);
    }
  }

  /// Provisions/switches to fleet role for an existing user account.
  Future<void> becomeFleetPartner() async {
    final user = _repository.currentUser;
    if (user == null) return;
    _setBusy(true);
    try {
      final profile = _currentProfile;
      await _repository.provisionUserMetadataAndProfile(
        email: user.email ?? '',
        selectedRole: 'fleet',
        fullName: profile?.fullName,
        phone: profile?.phone,
      );
      _activeRole = 'fleet';
      notifyListeners();
    } finally {
      _setBusy(false);
    }
  }

  Future<void> provisionRole(String role, {String? fullName, String? phone}) async {
    final user = _repository.currentUser;
    if (user == null) return;
    _setBusy(true);
    try {
      await _repository.provisionUserMetadataAndProfile(
        email: user.email ?? '',
        selectedRole: role,
        fullName: fullName,
        phone: phone,
      );
      notifyListeners();
    } finally {
      _setBusy(false);
    }
  }

  void clearPendingChallenge() {
    _pendingChallenge = null;
    _tempPassword = null;
    notifyListeners();
  }

  Future<void> sendPasswordResetEmail(String email) async {
    _setBusy(true);
    try {
      await _repository.sendPasswordResetEmail(email);
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
    _profileSub?.cancel();
    _metadataSub?.cancel();
    _sub?.cancel();
    super.dispose();
  }
}

final customerAuthController = CustomerAuthController();
