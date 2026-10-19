import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class TermiiSendOtpResult {
  const TermiiSendOtpResult({
    required this.pinId,
    required this.to,
    required this.phone,
    required this.message,
  });

  final String pinId;
  final String to;
  final String phone;
  final String message;
}

class TermiiException implements Exception {
  const TermiiException(this.message, {this.code});
  final String message;
  final String? code;

  @override
  String toString() => message;
}

class TermiiService {
  TermiiService._();
  static final TermiiService instance = TermiiService._();

  static const String apiKey = 'tlv_lp0hynBHneUEuT09j_HiNTndWrNCKilFOQE9ck7gNTw';
  static const String defaultBaseUrl = 'https://v4.api.termii.com';
  static const String fallbackBaseUrl = 'https://api.ng.termii.com';
  static const String senderId = String.fromEnvironment(
    'TERMII_SENDER_ID',
    defaultValue: 'N-Alert',
  );

  /// Validates whether the given string is formatted as an email or phone number.
  /// If it is a phone number, it must be an 11-digit number.
  static String? validateEmailOrPhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your email address or phone number.';
    }

    final trimmed = value.trim();
    if (trimmed.contains('@')) {
      final emailRegex = RegExp(r'^[\w\.\-]+@[a-zA-Z0-9\-]+(\.[a-zA-Z0-9\-]+)+$');
      if (!emailRegex.hasMatch(trimmed)) {
        return 'Please enter a valid email address.';
      }
      return null;
    }

    // Phone number verification: remove formatting characters
    final digits = trimmed.replaceAll(RegExp(r'\D'), '');
    if (digits.length != 11) {
      return 'Phone number must be exactly 11 digits (e.g. 08012345678).';
    }

    // Must start with 0 (Nigerian mobile standard: 080, 070, 090, 081, etc.)
    if (!digits.startsWith('0')) {
      return 'Phone number must start with 0 and be 11 digits.';
    }

    return null;
  }

  /// Determines whether the input is treated as a phone number.
  static bool isPhoneNumber(String input) {
    final trimmed = input.trim();
    if (trimmed.contains('@')) return false;
    final digits = trimmed.replaceAll(RegExp(r'\D'), '');
    return digits.length == 11;
  }

  /// Normalizes an 11-digit Nigerian phone number to international format:
  /// e.g. '08012345678' -> '2348012345678'.
  static String formatToInternational(String phone) {
    final digits = phone.trim().replaceAll(RegExp(r'\D'), '');
    if (digits.length == 11 && digits.startsWith('0')) {
      return '234${digits.substring(1)}';
    }
    if (digits.startsWith('234') && digits.length == 13) {
      return digits;
    }
    return digits;
  }

  /// Normalizes to standard 11-digit Nigerian format:
  /// e.g. '2348012345678' -> '08012345678' or keeps '08012345678'.
  static String formatToLocal11Digits(String phone) {
    final digits = phone.trim().replaceAll(RegExp(r'\D'), '');
    if (digits.length == 13 && digits.startsWith('234')) {
      return '0${digits.substring(3)}';
    }
    return digits;
  }

  /// Sends a 6-digit numeric OTP via Termii Token API.
  Future<TermiiSendOtpResult> sendOtp(String phone) async {
    final cleanLocal = formatToLocal11Digits(phone);
    final intlPhone = formatToInternational(phone);

    final payload = {
      'api_key': apiKey,
      'message_type': 'NUMERIC',
      'pin_type': 'NUMERIC',
      'to': intlPhone,
      'from': senderId,
      'channel': 'dnd',
      'pin_attempts': 3,
      'pin_time_to_live': 10,
      'pin_length': 6,
      'pin_placeholder': '< 123456 >',
      'message_text': 'Your CaRide verification code is < 123456 >. Valid for 10 minutes.',
    };

    final bodyJson = jsonEncode(payload);
    final headers = {'Content-Type': 'application/json'};

    // Attempt primary URL first, fall back to regional ng endpoint if needed
    for (final base in [defaultBaseUrl, fallbackBaseUrl]) {
      try {
        final uri = Uri.parse('$base/api/sms/otp/send');
        final response = await http
            .post(uri, headers: headers, body: bodyJson)
            .timeout(const Duration(seconds: 15));

        final dynamic data = jsonDecode(response.body);
        if (data is Map<String, dynamic>) {
          // Check for rate-limiting message
          if (data['error'] == true && data['message'] != null) {
            final msg = data['message'].toString();
            throw TermiiException(msg, code: 'rate-limited');
          }

          // Check if pinId is present (success)
          final pinId = data['pinId'] ?? data['pin_id'];
          if (pinId != null && pinId.toString().isNotEmpty) {
            return TermiiSendOtpResult(
              pinId: pinId.toString(),
              to: intlPhone,
              phone: cleanLocal,
              message: (data['smsStatus'] ?? 'OTP Sent').toString(),
            );
          }

          // If Country Inactive or similar routing issue, try next endpoint
          final errMsg = (data['message'] ?? data['error'] ?? '').toString();
          if (errMsg.toLowerCase().contains('country inactive')) {
            if (base == defaultBaseUrl) {
              debugPrint('[TermiiService] $base returned country inactive, trying fallback...');
              continue;
            } else {
              throw const TermiiException(
                'OTP code via sms is unavailable at the moment, please try again later.',
                code: 'country-inactive',
              );
            }
          }

          if (response.statusCode >= 400) {
            throw const TermiiException(
              'OTP code via sms is unavailable at the moment, please try again later.',
              code: 'sms-unavailable',
            );
          }
        }
      } catch (e) {
        if (e is TermiiException) rethrow;
        debugPrint('[TermiiService] Error sending OTP via $base: $e');
        if (base == defaultBaseUrl) continue;
        throw const TermiiException(
          'OTP code via sms is unavailable at the moment, please try again later.',
          code: 'network-error',
        );
      }
    }

    throw const TermiiException(
      'OTP code via sms is unavailable at the moment, please try again later.',
      code: 'send-failed',
    );
  }

  /// Verifies a 6-digit numeric OTP via Termii Verify Token API.
  Future<bool> verifyOtp({
    required String pinId,
    required String code,
  }) async {
    final payload = {
      'api_key': apiKey,
      'pin_id': pinId,
      'pin': code.trim(),
    };
    final bodyJson = jsonEncode(payload);
    final headers = {'Content-Type': 'application/json'};

    for (final base in [defaultBaseUrl, fallbackBaseUrl]) {
      try {
        final uri = Uri.parse('$base/api/sms/otp/verify');
        final response = await http
            .post(uri, headers: headers, body: bodyJson)
            .timeout(const Duration(seconds: 15));

        final dynamic data = jsonDecode(response.body);
        if (data is Map<String, dynamic>) {
          final verified = data['verified'];
          final msg = (data['message'] ?? data['error'] ?? '').toString();
          final msgLower = msg.toLowerCase();

          // Handle true flag OR Termii's "Token [pinId] has been verified" success message
          if (verified == true ||
              verified == 'True' ||
              verified == 'true' ||
              msgLower.contains('has been verified') ||
              msgLower.contains('have been verified') ||
              msgLower.contains('already verified') ||
              msgLower.contains('successfully verified')) {
            return true;
          }

          final status = response.statusCode;
          if (status == 404 || msg.toLowerCase().contains('not found')) {
            throw const TermiiException(
              'Invalid verification code. Please check the code and try again.',
              code: 'invalid-pin',
            );
          }
          if (msg.toLowerCase().contains('expired')) {
            throw const TermiiException(
              'Verification code has expired. Please request a new code.',
              code: 'expired-pin',
            );
          }
          if (data['verified'] == false || data['verified'] == 'False') {
            throw const TermiiException(
              'Incorrect verification code. Please enter the 6 digits received.',
              code: 'wrong-pin',
            );
          }

          if (status >= 400 && base == defaultBaseUrl) {
            continue;
          }

          throw TermiiException(
            msg.isNotEmpty ? msg : 'Unable to verify code.',
            code: 'verification-failed',
          );
        }
      } catch (e) {
        if (e is TermiiException) rethrow;
        debugPrint('[TermiiService] Error verifying OTP via $base: $e');
        if (base == defaultBaseUrl) continue;
        throw TermiiException(
          'Failed to verify SMS code. Please check your internet connection.',
          code: 'network-error',
        );
      }
    }

    return false;
  }
}
