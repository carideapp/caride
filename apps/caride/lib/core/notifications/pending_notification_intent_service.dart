import 'package:flutter/foundation.dart';

/// Holds a notification deep-link payload captured at cold start until
/// authentication and initial routing complete in [SplashScreen].
class PendingNotificationIntentService {
  PendingNotificationIntentService._();

  @visibleForTesting
  PendingNotificationIntentService();

  static final PendingNotificationIntentService instance =
      PendingNotificationIntentService._();

  static const Duration defaultTtl = Duration(minutes: 5);

  Map<String, dynamic>? _pendingData;
  DateTime? _capturedAt;

  bool get hasPending => peek() != null;

  void capture(Map<String, dynamic> data, {DateTime? now}) {
    if (data.isEmpty) return;
    final type = data['type']?.toString().trim() ?? '';
    final rideId = data['rideId']?.toString().trim() ?? '';
    if (type.isEmpty && rideId.isEmpty) return;
    if (type.toLowerCase() == 'ride_alert_cancel') return;

    _pendingData = Map<String, dynamic>.from(data);
    _capturedAt = now ?? DateTime.now();
  }

  Map<String, dynamic>? peek({DateTime? now}) {
    final data = _pendingData;
    final capturedAt = _capturedAt;
    if (data == null || capturedAt == null) return null;

    final currentTime = now ?? DateTime.now();
    if (currentTime.difference(capturedAt) > defaultTtl) {
      clear();
      return null;
    }
    return Map<String, dynamic>.from(data);
  }

  Map<String, dynamic>? consume({DateTime? now}) {
    final data = peek(now: now);
    clear();
    return data;
  }

  void clear() {
    _pendingData = null;
    _capturedAt = null;
  }
}
