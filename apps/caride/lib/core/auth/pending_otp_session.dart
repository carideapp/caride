import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'auth_challenge.dart';

/// Represents a persistent pending OTP session that survives background app kills
/// and process recycling (e.g., when a user minimizes to copy an OTP from Gmail).
class PendingOtpSession {
  const PendingOtpSession({
    required this.challenge,
    required this.role,
    this.tempPassword,
    this.referralCode,
    this.fullName,
    this.phone,
    this.email,
    this.username,
    this.country,
    this.state,
    required this.savedAt,
  });

  final AuthChallenge challenge;
  final String role; // 'customer', 'driver', 'fleet'
  final String? tempPassword;
  final String? referralCode;
  final String? fullName;
  final String? phone;
  /// The user's actual email address (stored separately from challenge.email,
  /// which may be a synthetic phone-based email when OTP is sent via SMS).
  final String? email;
  final String? username;
  final String? country;
  final String? state;
  final DateTime savedAt;

  bool get isExpired => DateTime.now().isAfter(challenge.expiresAt);

  Duration get remainingTime {
    final diff = challenge.expiresAt.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  Map<String, dynamic> toJson() => {
        'challengeId': challenge.challengeId,
        'email': challenge.email,
        'expiresAt': challenge.expiresAt.toIso8601String(),
        'isSignUp': challenge.isSignUp,
        'channel': challenge.channel,
        'challengePhone': challenge.phone,
        'role': role,
        'tempPassword': tempPassword,
        'referralCode': referralCode,
        'fullName': fullName,
        'phone': phone ?? challenge.phone,
        'userEmail': email,
        'username': username,
        'country': country,
        'state': state,
        'savedAt': savedAt.toIso8601String(),
      };

  factory PendingOtpSession.fromJson(Map<String, dynamic> json) {
    final phoneVal = (json['challengePhone'] ?? json['phone']) as String?;
    final channelVal = json['channel'] as String? ?? (phoneVal != null && phoneVal.isNotEmpty ? 'sms' : 'email');
    return PendingOtpSession(
      challenge: AuthChallenge(
        challengeId: json['challengeId'] as String? ?? '',
        email: json['email'] as String? ?? '',
        expiresAt: DateTime.tryParse(json['expiresAt'] as String? ?? '') ??
            DateTime.now().add(const Duration(minutes: 5)),
        isSignUp: json['isSignUp'] as bool? ?? true,
        phone: phoneVal,
        channel: channelVal,
      ),
      role: json['role'] as String? ?? 'customer',
      tempPassword: json['tempPassword'] as String?,
      referralCode: json['referralCode'] as String?,
      fullName: json['fullName'] as String?,
      phone: phoneVal,
      email: json['userEmail'] as String?,
      username: json['username'] as String?,
      country: json['country'] as String?,
      state: json['state'] as String?,
      savedAt: DateTime.tryParse(json['savedAt'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

/// Service that persists and restores active OTP sessions across app restarts.
class PendingOtpSessionService {
  PendingOtpSessionService._();
  static final PendingOtpSessionService instance = PendingOtpSessionService._();

  static const String _keySession = 'caride_pending_otp_session';
  static const String _keyDraftPrefix = 'caride_signup_draft_';

  /// Saves the active OTP session to SharedPreferences.
  Future<void> saveSession(PendingOtpSession session) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = jsonEncode(session.toJson());
      await prefs.setString(_keySession, jsonString);
    } catch (e) {
      debugPrint('[PendingOtpSessionService] Error saving OTP session: $e');
    }
  }

  /// Loads the active OTP session if it exists and has not expired.
  /// If expired, automatically removes it from storage and returns null.
  Future<PendingOtpSession?> loadSession({String? roleFilter}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_keySession);
      if (jsonString == null || jsonString.isEmpty) return null;

      final Map<String, dynamic> data = jsonDecode(jsonString) as Map<String, dynamic>;
      final session = PendingOtpSession.fromJson(data);

      if (session.isExpired) {
        debugPrint('[PendingOtpSessionService] Stored OTP session expired; clearing.');
        await clearSession();
        return null;
      }

      if (roleFilter != null && session.role != roleFilter) {
        return null;
      }

      return session;
    } catch (e) {
      debugPrint('[PendingOtpSessionService] Error loading OTP session: $e');
      return null;
    }
  }

  /// Checks if there is an active unexpired OTP challenge session.
  Future<bool> hasActiveSession({String? roleFilter}) async {
    final session = await loadSession(roleFilter: roleFilter);
    return session != null;
  }

  /// Clears the active OTP challenge session.
  Future<void> clearSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keySession);
    } catch (e) {
      debugPrint('[PendingOtpSessionService] Error clearing OTP session: $e');
    }
  }

  /// Saves a persistent signup draft for a role so fields are preserved if the user navigates away.
  Future<void> saveDraft(String role, Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('$_keyDraftPrefix$role', jsonEncode(data));
    } catch (e) {
      debugPrint('[PendingOtpSessionService] Error saving draft for $role: $e');
    }
  }

  /// Loads saved signup draft for a role.
  Future<Map<String, dynamic>?> loadDraft(String role) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_keyDraftPrefix$role');
      if (raw == null || raw.isEmpty) return null;
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('[PendingOtpSessionService] Error loading draft for $role: $e');
      return null;
    }
  }

  /// Clears the saved signup draft for a role.
  Future<void> clearDraft(String role) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('$_keyDraftPrefix$role');
    } catch (e) {
      debugPrint('[PendingOtpSessionService] Error clearing draft for $role: $e');
    }
  }
}
