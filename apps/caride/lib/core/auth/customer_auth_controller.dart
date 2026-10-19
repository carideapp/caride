import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/profile/data/account_repository.dart';
import '../services/deep_link_service.dart';
import '../services/termii_service.dart';

import 'auth_challenge.dart';
import 'auth_repository.dart';
import 'pending_otp_session.dart';

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
  String? tempEmail;
  File? tempPhotoFile;
  DateTime? _lastOtpSentAt;
  bool _isBusy = false;

  bool get isAuthenticated => _repository.currentUser != null;
  bool get isBusy => _isBusy;
  AuthChallenge? get pendingChallenge => _pendingChallenge;
  DateTime? get lastOtpSentAt => _lastOtpSentAt;
  String? get pendingEmail => tempEmail;

  Future<String?> _resolveReferralCode(String? explicitCode) async {
    if (explicitCode != null && explicitCode.trim().isNotEmpty) {
      return explicitCode.trim().toUpperCase();
    }
    return await DeepLinkService.instance.getOrFetchPendingReferralCode();
  }

  Future<void> requestOtpForSignup(
    String phone, [
    String email = '',
    String? password,
    String? referredByCode,
    String? fullName,
  ]) async {
    if (password != null) {
      _tempPassword = password;
    }
    if (fullName != null && fullName.trim().isNotEmpty) {
      tempFullName = fullName.trim();
    }
    if (email.trim().isNotEmpty) tempEmail = email.trim();
    final resolvedCode = await _resolveReferralCode(referredByCode);
    _tempReferredByCode = resolvedCode;

    // Default: send OTP to email first (email is default since SMS Sender ID approval is pending)
    final cleanPhone = TermiiService.formatToLocal11Digits(phone.trim());
    tempPhone = cleanPhone;
    _setBusy(true);
    try {
      final targetEmail = tempEmail;
      if (targetEmail != null && targetEmail.isNotEmpty) {
        _pendingChallenge = await _repository.requestEmailOtp(
          email: targetEmail,
          isSignUp: true,
          referredByCode: _tempReferredByCode,
        );
      } else {
        final result = await TermiiService.instance.sendOtp(cleanPhone);
        _pendingChallenge = AuthChallenge(
          challengeId: result.pinId,
          email: '$cleanPhone@phone.caride.com',
          phone: cleanPhone,
          expiresAt: DateTime.now().add(const Duration(minutes: 10)),
          isSignUp: true,
          channel: 'sms',
        );
      }

      if (_pendingChallenge != null) {
        _lastOtpSentAt = DateTime.now();
        await PendingOtpSessionService.instance.saveSession(
          PendingOtpSession(
            challenge: _pendingChallenge!,
            role: 'customer',
            tempPassword: _tempPassword,
            referralCode: _tempReferredByCode,
            fullName: tempFullName,
            phone: cleanPhone,
            email: tempEmail,
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
    final email = tempEmail;
    if (email == null || email.isEmpty) {
      throw Exception('No email address available to switch to.');
    }
    _setBusy(true);
    try {
      _pendingChallenge = await _repository.requestEmailOtp(
        email: email,
        isSignUp: true,
        referredByCode: _tempReferredByCode,
      );
      if (_pendingChallenge != null) {
        _lastOtpSentAt = DateTime.now();
        await PendingOtpSessionService.instance.saveSession(
          PendingOtpSession(
            challenge: _pendingChallenge!,
            role: 'customer',
            tempPassword: _tempPassword,
            referralCode: _tempReferredByCode,
            fullName: tempFullName,
            phone: tempPhone,
            email: tempEmail,
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
    final phone = tempPhone;
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
      _lastOtpSentAt = DateTime.now();
      await PendingOtpSessionService.instance.saveSession(
        PendingOtpSession(
          challenge: _pendingChallenge!,
          role: 'customer',
          tempPassword: _tempPassword,
          referralCode: _tempReferredByCode,
          fullName: tempFullName,
          phone: cleanPhone,
          email: tempEmail,
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
      final cleanPhone = TermiiService.formatToLocal11Digits(trimmed);
      return requestOtpForSignup(cleanPhone);
    }
    return _requestOtp(email: trimmed, isSignUp: false);
  }

  Future<void> resendPendingOtp() async {
    final challenge = _pendingChallenge;
    if (challenge == null) return;
    if (challenge.isSms && challenge.phone != null) {
      // Resend via SMS
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
        _lastOtpSentAt = DateTime.now();
        await PendingOtpSessionService.instance.saveSession(
          PendingOtpSession(
            challenge: _pendingChallenge!,
            role: 'customer',
            tempPassword: _tempPassword,
            referralCode: _tempReferredByCode,
            fullName: tempFullName,
            phone: cleanPhone,
            email: tempEmail,
            savedAt: DateTime.now(),
          ),
        );
        notifyListeners();
      } finally {
        _setBusy(false);
      }
    } else {
      if (challenge.isSignUp) {
        await _requestOtp(email: challenge.email, isSignUp: true, referredByCode: _tempReferredByCode);
      } else {
        await requestOtpForLogin(challenge.email);
      }
    }
  }

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
      if (_pendingChallenge != null) {
        _lastOtpSentAt = DateTime.now();
        await PendingOtpSessionService.instance.saveSession(
          PendingOtpSession(
            challenge: _pendingChallenge!,
            role: 'customer',
            tempPassword: _tempPassword,
            referralCode: _tempReferredByCode,
            fullName: tempFullName,
            phone: tempPhone,
            savedAt: DateTime.now(),
          ),
        );
      }
      notifyListeners();
    } finally {
      _setBusy(false);
    }
  }

  /// Restores pending OTP session from storage if it exists and has not expired.
  Future<bool> restorePendingSession() async {
    final session = await PendingOtpSessionService.instance.loadSession(roleFilter: 'customer');
    if (session != null) {
      _pendingChallenge = session.challenge;
      _tempPassword = session.tempPassword;
      _tempReferredByCode = session.referralCode;
      tempFullName = session.fullName;
      tempPhone = session.phone ?? session.challenge.phone;
      tempEmail = session.email;
      _lastOtpSentAt = session.savedAt;
      notifyListeners();
      return true;
    }
    return false;
  }

  /// Clears pending OTP challenge from memory and storage (e.g., user changed email or cancelled).
  Future<void> clearPendingChallenge() async {
    _pendingChallenge = null;
    _lastOtpSentAt = null;
    _tempPassword = null;
    _tempReferredByCode = null;
    tempFullName = null;
    tempPhone = null;
    tempEmail = null;
    tempPhotoFile = null;
    await PendingOtpSessionService.instance.clearSession();
    notifyListeners();
  }

  Future<void> signInWithEmailAndPassword(String emailOrPhone, String password) async {
    _setBusy(true);
    try {
      String resolvedEmail = emailOrPhone.trim();
      final isPhone = TermiiService.isPhoneNumber(resolvedEmail);
      if (isPhone) {
        final cleanPhone = TermiiService.formatToLocal11Digits(resolvedEmail);
        resolvedEmail = '$cleanPhone@phone.caride.com';
      }

      try {
        await _repository.signInWithEmailAndPassword(email: resolvedEmail, password: password);
      } catch (authError) {
        // If user entered a real email, check if their account was created via phone OTP
        // (synthetic email in Auth, but real email saved in Firestore).
        if (!isPhone && resolvedEmail.contains('@') && !resolvedEmail.endsWith('@phone.caride.com')) {
          final cleanInputEmail = resolvedEmail.toLowerCase();
          final firestore = FirebaseFirestore.instance;

          String? matchedPhone;
          try {
            // Search customers, drivers, and users collections for this email
            final customerSnap = await firestore
                .collection('customers')
                .where('email', isEqualTo: cleanInputEmail)
                .limit(1)
                .get();

            if (customerSnap.docs.isNotEmpty) {
              matchedPhone = customerSnap.docs.first.data()['phone'] as String?;
            }

            if (matchedPhone == null || matchedPhone.isEmpty) {
              final driverSnap = await firestore
                  .collection('drivers')
                  .where('email', isEqualTo: cleanInputEmail)
                  .limit(1)
                  .get();
              if (driverSnap.docs.isNotEmpty) {
                matchedPhone = driverSnap.docs.first.data()['phone'] as String?;
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
          } catch (_) {
            // Firestore read error or permission denied: proceed to throw original authError
          }

          if (matchedPhone != null && matchedPhone.isNotEmpty) {
            final formattedPhone = TermiiService.formatToLocal11Digits(matchedPhone);
            final syntheticEmail = '$formattedPhone@phone.caride.com';

            // Sign in using the phone-based synthetic account
            await _repository.signInWithEmailAndPassword(email: syntheticEmail, password: password);

            // Attempt to link the real email credential so future direct logins succeed
            try {
              final user = FirebaseAuth.instance.currentUser;
              if (user != null) {
                final emailCred = EmailAuthProvider.credential(
                  email: cleanInputEmail,
                  password: password,
                );
                await user.linkWithCredential(emailCred);
              }
            } catch (_) {
              // Ignore if already linked or linking not permitted
            }
          } else {
            rethrow;
          }
        } else {
          rethrow;
        }
      }

      await clearPendingChallenge();
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

      if (challenge.isSms) {
        // 1. Verify 6-digit code via Termii
        await TermiiService.instance.verifyOtp(
          pinId: challenge.challengeId,
          code: code,
        );

        // 2. Sign in or create Firebase Auth user with phone-based synthetic email
        final cleanPhone = challenge.phone ?? TermiiService.formatToLocal11Digits(challenge.email);
        final syntheticEmail = '$cleanPhone@phone.caride.com';
        final pwd = _tempPassword ?? 'Caride@${cleanPhone.length >= 6 ? cleanPhone.substring(cleanPhone.length - 6) : "123456"}';

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

        // 3. Provision customer profile and user metadata
        await _repository.provisionUserMetadataAndProfile(
          email: tempEmail ?? '',
          phone: cleanPhone,
          referredByCode: _tempReferredByCode,
          selectedRole: selectedRole,
          fullName: tempFullName,
        );
      } else {
        await _repository.verifyEmailOtp(
          challenge: challenge,
          code: code,
          referredByCode: _tempReferredByCode,
          selectedRole: selectedRole,
          fullName: tempFullName,
          phone: tempPhone,
        );
      }

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

      if (challenge.isSignUp && tempFullName != null && tempFullName!.trim().isNotEmpty) {
        final uid = _repository.currentUser?.uid;
        if (uid != null) {
          final cleanName = tempFullName!.trim();
          try {
            await FirebaseFirestore.instance.collection('customers').doc(uid).set({
              'fullName': cleanName,
              'displayName': cleanName,
              if (challenge.phone != null) 'phone': challenge.phone,
              'updatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
          } catch (e) {
            debugPrint('Error updating customer full name: $e');
          }
          try {
            await FirebaseFirestore.instance.collection('users').doc(uid).set({
              'fullName': cleanName,
              'displayName': cleanName,
              if (challenge.phone != null) 'phone': challenge.phone,
            }, SetOptions(merge: true));
          } catch (e) {
            debugPrint('Error updating user full name: $e');
          }
          try {
            await _repository.currentUser?.updateDisplayName(cleanName);
          } catch (e) {
            debugPrint('Error updating auth display name: $e');
          }
        }
      }

      await PendingOtpSessionService.instance.clearDraft('customer');
      await clearPendingChallenge();
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
