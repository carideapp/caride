import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service facilitating in-app support communication for accounts locked out
/// due to failed login attempts or administrative security policies.
class LockoutSupportService {
  LockoutSupportService({FirebaseFunctions? functions})
      : _functions =
            functions ?? FirebaseFunctions.instanceFor(region: 'us-east1');

  final FirebaseFunctions _functions;

  static const String _activeChatKeyPrefix = 'caride_locked_active_chat_';
  static const String _lockoutEmailKeyPrefix = 'caride_locked_email_';
  static const String _lockoutTimestampKeyPrefix = 'caride_locked_time_';

  /// Save an active lockout session locally so the user can easily re-access
  /// their ongoing support chat while the account remains locked.
  static Future<void> recordActiveLockout({
    required String role,
    required String email,
    String? chatId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final normalizedEmail = email.trim().toLowerCase();
    final roleKey = role.trim().toLowerCase();
    await prefs.setString('$_lockoutEmailKeyPrefix$roleKey', normalizedEmail);
    await prefs.setInt('$_lockoutTimestampKeyPrefix$roleKey',
        DateTime.now().millisecondsSinceEpoch);
    if (chatId != null && chatId.isNotEmpty) {
      await prefs.setString(
          '$_activeChatKeyPrefix${roleKey}_$normalizedEmail', chatId);
    }
  }

  /// Get the active ticket ID for a given role and email.
  static Future<String?> getActiveChatId({
    required String role,
    required String email,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final normalizedEmail = email.trim().toLowerCase();
    final roleKey = role.trim().toLowerCase();
    return prefs.getString('$_activeChatKeyPrefix${roleKey}_$normalizedEmail');
  }

  /// Save an active ticket ID.
  static Future<void> saveActiveChatId({
    required String role,
    required String email,
    required String chatId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final normalizedEmail = email.trim().toLowerCase();
    final roleKey = role.trim().toLowerCase();
    await prefs.setString(
        '$_activeChatKeyPrefix${roleKey}_$normalizedEmail', chatId);
  }

  /// Check if there is an active lockout recorded for this role.
  static Future<bool> hasActiveLockout({
    required String role,
    String? email,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final roleKey = role.trim().toLowerCase();
    final savedEmail = prefs.getString('$_lockoutEmailKeyPrefix$roleKey');
    if (savedEmail == null || savedEmail.isEmpty) return false;
    if (email != null && email.trim().isNotEmpty) {
      return savedEmail.toLowerCase() == email.trim().toLowerCase();
    }
    return true;
  }

  /// Get the last recorded locked email for a role.
  static Future<String?> getRecordedLockedEmail(String role) async {
    final prefs = await SharedPreferences.getInstance();
    final roleKey = role.trim().toLowerCase();
    return prefs.getString('$_lockoutEmailKeyPrefix$roleKey');
  }

  /// Clear the lockout record when the user successfully signs in or verifies unlock.
  static Future<void> clearLockoutRecord({
    required String role,
    required String email,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final normalizedEmail = email.trim().toLowerCase();
    final roleKey = role.trim().toLowerCase();
    await prefs.remove('$_lockoutEmailKeyPrefix$roleKey');
    await prefs.remove('$_lockoutTimestampKeyPrefix$roleKey');
    await prefs.remove('$_activeChatKeyPrefix${roleKey}_$normalizedEmail');
  }

  /// Submit a support message to backend (creates a new ticket or replies to an existing one).
  /// - Customer messages route to collection `supportChats` with `userType: 'customer'` (shown in CustomerSupportPage)
  /// - Driver messages route to collection `supportChats` with `userType: 'driver'` (shown in DriverSupportPage)
  /// - Fleet manager messages route to collection `support_tickets` with `userType: 'fleet'` (shown in FleetSupportPage)
  Future<Map<String, dynamic>> submitMessage({
    required String email,
    required String role,
    required String message,
    String? subject,
    String? chatId,
    String? stageName,
  }) async {
    final callable =
        _functions.httpsCallable('submitLockoutSupportMessageCallable');
    final response = await callable.call<Map<String, dynamic>>({
      'email': email.trim().toLowerCase(),
      'role': role.trim().toLowerCase(),
      'message': message.trim(),
      'subject': subject ?? 'Account Lockout Support Request',
      'chatId': chatId,
      'stageName': stageName ?? 'Final Lockout / Manual Unlock Required',
    });

    final data = Map<String, dynamic>.from(response.data);
    final returnedChatId = data['chatId'] as String?;
    if (returnedChatId != null && returnedChatId.isNotEmpty) {
      await saveActiveChatId(
        role: role,
        email: email,
        chatId: returnedChatId,
      );
    }
    return data;
  }

  /// Retrieve the status and messages for a specific lockout chat session.
  Future<Map<String, dynamic>> getChat({
    required String chatId,
    required String email,
    required String role,
  }) async {
    final callable = _functions.httpsCallable('getLockoutSupportChatCallable');
    final response = await callable.call<Map<String, dynamic>>({
      'chatId': chatId.trim(),
      'email': email.trim().toLowerCase(),
      'role': role.trim().toLowerCase(),
    });
    return Map<String, dynamic>.from(response.data);
  }

  /// Retrieve past support chats/tickets for this locked email and role.
  Future<List<Map<String, dynamic>>> listChats({
    required String email,
    required String role,
  }) async {
    final callable = _functions.httpsCallable('listLockoutSupportChatsCallable');
    final response = await callable.call<Map<String, dynamic>>({
      'email': email.trim().toLowerCase(),
      'role': role.trim().toLowerCase(),
    });
    final data = Map<String, dynamic>.from(response.data);
    final list = data['chats'] as List<dynamic>? ?? [];
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }
}
