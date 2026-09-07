import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ---------------------------------------------------------------------------
// PendingDeepLink — typed model for a deep link pending processing.
// ---------------------------------------------------------------------------

enum DeepLinkType { referral, trip }

class PendingDeepLink {
  const PendingDeepLink({
    required this.type,
    required this.code,
    required this.receivedAt,
  });

  final DeepLinkType type;
  final String code;
  final DateTime receivedAt;

  /// Referral codes valid 48 h; trip codes valid 24 h.
  Duration get _ttl => type == DeepLinkType.referral
      ? const Duration(hours: 48)
      : const Duration(hours: 24);

  bool get isExpired => DateTime.now().isAfter(receivedAt.add(_ttl));
}

// ---------------------------------------------------------------------------
// DeepLinkService
// ---------------------------------------------------------------------------

/// Singleton that handles App Links (Android) and Universal Links (iOS).
///
/// URL structure:
///   https://www.caride.ng/app/referral/{code}
///   https://www.caride.ng/app/trip/{code}
///   caride://app/referral/{code}  (custom scheme fallback)
///   caride://app/trip/{code}
class DeepLinkService {
  DeepLinkService._internal();

  static final DeepLinkService _instance = DeepLinkService._internal();
  static DeepLinkService get instance => _instance;

  // SharedPreferences keys
  static const String _referralCodeKey      = 'dl_pending_referral_code';
  static const String _referralTimestampKey  = 'dl_pending_referral_ts';
  static const String _tripCodeKey           = 'dl_pending_trip_code';
  static const String _tripTimestampKey      = 'dl_pending_trip_ts';
  static const String _processedLinksKey     = 'dl_processed_links';

  // Public URL base
  static const String baseDomain   = 'https://www.caride.ng';
  static const String baseAppPath  = '$baseDomain/app';

  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _sub;

  PendingDeepLink? _pendingReferral;
  PendingDeepLink? _pendingTrip;

  // Typed broadcast streams
  final StreamController<PendingDeepLink> _referralController =
      StreamController<PendingDeepLink>.broadcast();
  final StreamController<PendingDeepLink> _tripController =
      StreamController<PendingDeepLink>.broadcast();

  Stream<PendingDeepLink> get onReferralReceived => _referralController.stream;
  Stream<PendingDeepLink> get onTripReceived     => _tripController.stream;

  // Convenience getters — return null if expired
  PendingDeepLink? get pendingReferral =>
      (_pendingReferral == null || _pendingReferral!.isExpired) ? null : _pendingReferral;
  String? get pendingReferralCode => pendingReferral?.code;

  PendingDeepLink? get pendingTrip =>
      (_pendingTrip == null || _pendingTrip!.isExpired) ? null : _pendingTrip;
  String? get pendingTripCode => pendingTrip?.code;

  // ── Init ──────────────────────────────────────────────────────────────────

  Future<void> init() async {
    await _restoreFromPrefs();

    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) await _handleUri(initialUri);
    } catch (e) {
      debugPrint('[DeepLinkService] Error reading initial link: $e');
    }

    _sub?.cancel();
    _sub = _appLinks.uriLinkStream.listen(
      (uri) async => _handleUri(uri),
      onError: (err) => debugPrint('[DeepLinkService] Stream error: $err'),
    );
  }

  // ── URI Parsing ───────────────────────────────────────────────────────────

  Future<void> _handleUri(Uri uri) async {
    debugPrint('[DeepLinkService] Received URI: $uri');
    final normalised = _normalise(uri);
    if (normalised == null) return;

    final segments = normalised.pathSegments;
    // Path: [..., 'app', 'referral'|'trip', '{code}']
    final appIdx = segments.indexOf('app');
    if (appIdx == -1 || appIdx + 2 >= segments.length) return;

    final type = segments[appIdx + 1];
    final code = segments[appIdx + 2].trim().toUpperCase();
    if (code.isEmpty) return;

    if (await _wasAlreadyProcessed('$type:$code')) {
      debugPrint('[DeepLinkService] Already processed $type:$code');
      return;
    }

    if (type == 'referral') {
      final link = PendingDeepLink(
        type: DeepLinkType.referral,
        code: code,
        receivedAt: DateTime.now(),
      );
      _pendingReferral = link;
      await _persistReferral(code);
      _referralController.add(link);
      debugPrint('[DeepLinkService] Referral captured: $code');
    } else if (type == 'trip') {
      final link = PendingDeepLink(
        type: DeepLinkType.trip,
        code: code,
        receivedAt: DateTime.now(),
      );
      _pendingTrip = link;
      await _persistTrip(code);
      _tripController.add(link);
      debugPrint('[DeepLinkService] Trip captured: $code');
    } else {
      debugPrint('[DeepLinkService] Unknown link type: $type');
    }
  }

  /// Normalise caride://app/referral/CODE to https://www.caride.ng/app/referral/CODE.
  Uri? _normalise(Uri uri) {
    if (uri.scheme == 'caride') {
      return Uri.parse('$baseDomain/${uri.host}${uri.path}');
    }
    if (uri.scheme == 'https' || uri.scheme == 'http') return uri;
    return null;
  }

  // ── Public API ────────────────────────────────────────────────────────────

  Future<String?> getOrFetchPendingReferralCode() async {
    if (pendingReferralCode != null) return pendingReferralCode;
    await _restoreFromPrefs();
    return pendingReferralCode;
  }

  Future<String?> getOrFetchPendingTripCode() async {
    if (pendingTripCode != null) return pendingTripCode;
    await _restoreFromPrefs();
    return pendingTripCode;
  }

  Future<void> clearPendingReferralCode() async {
    if (_pendingReferral != null) {
      await _markProcessed('referral:${_pendingReferral!.code}');
    }
    _pendingReferral = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_referralCodeKey);
      await prefs.remove(_referralTimestampKey);
    } catch (e) {
      debugPrint('[DeepLinkService] Error clearing referral: $e');
    }
  }

  Future<void> clearPendingTripCode() async {
    if (_pendingTrip != null) {
      await _markProcessed('trip:${_pendingTrip!.code}');
    }
    _pendingTrip = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tripCodeKey);
      await prefs.remove(_tripTimestampKey);
    } catch (e) {
      debugPrint('[DeepLinkService] Error clearing trip code: $e');
    }
  }

  // ── Link Generation ───────────────────────────────────────────────────────

  /// Canonical referral deep link: https://www.caride.ng/app/referral/{code}
  String generateReferralLink(String referralCode) {
    if (referralCode.isEmpty) return baseAppPath;
    return '$baseAppPath/referral/${Uri.encodeComponent(referralCode)}';
  }

  /// Canonical shared trip deep link: https://www.caride.ng/app/trip/{code}
  String generateTripLink(String tripCode) {
    if (tripCode.isEmpty) return baseAppPath;
    return '$baseAppPath/trip/${Uri.encodeComponent(tripCode)}';
  }

  // ── Persistence ───────────────────────────────────────────────────────────

  Future<void> _restoreFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final refCode = prefs.getString(_referralCodeKey);
      final refTs   = prefs.getInt(_referralTimestampKey);
      if (refCode != null && refTs != null) {
        final link = PendingDeepLink(
          type: DeepLinkType.referral,
          code: refCode,
          receivedAt: DateTime.fromMillisecondsSinceEpoch(refTs),
        );
        if (!link.isExpired) _pendingReferral = link;
      }

      final tripCode = prefs.getString(_tripCodeKey);
      final tripTs   = prefs.getInt(_tripTimestampKey);
      if (tripCode != null && tripTs != null) {
        final link = PendingDeepLink(
          type: DeepLinkType.trip,
          code: tripCode,
          receivedAt: DateTime.fromMillisecondsSinceEpoch(tripTs),
        );
        if (!link.isExpired) _pendingTrip = link;
      }
    } catch (e) {
      debugPrint('[DeepLinkService] Error restoring from prefs: $e');
    }
  }

  Future<void> _persistReferral(String code) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_referralCodeKey, code);
      await prefs.setInt(_referralTimestampKey, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      debugPrint('[DeepLinkService] Error persisting referral: $e');
    }
  }

  Future<void> _persistTrip(String code) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tripCodeKey, code);
      await prefs.setInt(_tripTimestampKey, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      debugPrint('[DeepLinkService] Error persisting trip: $e');
    }
  }

  // ── Idempotency ───────────────────────────────────────────────────────────

  Future<bool> _wasAlreadyProcessed(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return (prefs.getStringList(_processedLinksKey) ?? []).contains(key);
    } catch (_) {
      return false;
    }
  }

  Future<void> _markProcessed(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_processedLinksKey) ?? [];
      if (list.contains(key)) return;
      if (list.length >= 50) list.removeAt(0);
      list.add(key);
      await prefs.setStringList(_processedLinksKey, list);
    } catch (e) {
      debugPrint('[DeepLinkService] Error marking processed: $e');
    }
  }

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  void dispose() {
    _sub?.cancel();
    _referralController.close();
    _tripController.close();
  }
}