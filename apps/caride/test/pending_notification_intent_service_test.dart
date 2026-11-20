import 'package:caride/core/notifications/pending_notification_intent_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PendingNotificationIntentService', () {
    test('captures, peeks, and consumes valid ride intent', () {
      final service = PendingNotificationIntentService();
      final now = DateTime(2026, 11, 19, 12, 0);

      service.capture({
        'type': 'ride_request',
        'rideId': 'ride_123',
      }, now: now);

      expect(service.peek(now: now), isNotNull);
      final consumed = service.consume(
        now: now.add(const Duration(seconds: 30)),
      );
      expect(consumed, isNotNull);
      expect(consumed!['rideId'], equals('ride_123'));
      expect(consumed['type'], equals('ride_request'));
      expect(service.consume(now: now.add(const Duration(seconds: 31))), isNull);
    });

    test('ignores empty and cancellation payloads', () {
      final service = PendingNotificationIntentService();
      service.capture({});
      expect(service.peek(), isNull);

      service.capture({'type': 'ride_alert_cancel', 'rideId': 'ride_99'});
      expect(service.peek(), isNull);
    });

    test('expires intents older than default TTL', () {
      final service = PendingNotificationIntentService();
      final t0 = DateTime(2026, 11, 19, 12, 0);
      service.capture({'type': 'ride_request', 'rideId': 'ride_old'}, now: t0);

      final expired = service.consume(
        now: t0.add(const Duration(minutes: 6)),
      );
      expect(expired, isNull);
    });
  });
}
