import 'dart:ui';

import 'package:caride/core/driver/models/ride_model.dart';
import 'package:caride/core/driver/notifications/driver_alert_audio_service.dart';
import 'package:caride/core/driver/notifications/driver_alert_controller.dart';
import 'package:caride/core/notifications/app_notification_service.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAudioService extends DriverAlertAudioService {
  int startCalls = 0;
  int stopCalls = 0;
  bool playing = false;

  @override
  bool get isPlaying => playing;

  @override
  Future<void> startAlert() async {
    startCalls++;
    playing = true;
  }

  @override
  Future<void> stopAlert() async {
    stopCalls++;
    playing = false;
  }
}

class _FakeNotificationService extends AppNotificationService {
  _FakeNotificationService() : super.forTest();

  final List<String> cancelledIds = [];
  final List<String> declinedIds = [];

  @override
  Future<void> cancelRideNotification(String rideId) async {
    cancelledIds.add(rideId);
  }

  @override
  Future<void> markRideDeclined(String rideId) async {
    declinedIds.add(rideId);
  }

  @override
  Future<List<String>> getDeclinedRideIds() async => List.unmodifiable(declinedIds);
}

RideModel _makeRide({
  required String id,
  String status = 'searching',
  double offer = 3500,
  DateTime? expiresAt,
}) {
  return RideModel(
    id: id,
    customerUid: 'cust_1',
    status: status,
    pickupLabel: 'Lekki Phase 1',
    dropoffLabel: 'Victoria Island',
    rideType: 'Regular',
    customerOffer: offer,
    paymentMethod: 'cash',
    pickupLat: 6.4474,
    pickupLng: 3.4723,
    expiresAt: expiresAt ?? DateTime.now().add(const Duration(minutes: 2)),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('DriverAlertController', () {
    test('alerts once per ride, deduplicates, and refreshes canonical data', () async {
      final audio = _FakeAudioService();
      final notif = _FakeNotificationService();
      final controller = DriverAlertController(
        audioService: audio,
        notificationService: notif,
        isForeground: true,
      );

      final initial = _makeRide(id: 'ride_1', offer: 3000);
      controller.onRidesUpdated([initial], driverLat: 6.45, driverLng: 3.47);

      expect(controller.activeForegroundOffer.value?.id, equals('ride_1'));
      expect(audio.startCalls, equals(1));
      expect(audio.playing, isTrue);

      // Re-emitting same ride ID with updated offer refreshes modal without re-triggering audio.
      final updated = _makeRide(id: 'ride_1', offer: 3800);
      controller.onRidesUpdated([updated], driverLat: 6.46, driverLng: 3.48);

      expect(audio.startCalls, equals(1));
      expect(controller.activeForegroundOffer.value?.customerOffer, equals(3800));
      expect(controller.activeOfferDistanceKm.value, isNotNull);

      await controller.dispose();
    });

    test('silenceAudio stops ringtone while keeping foreground offer modal open', () async {
      final audio = _FakeAudioService();
      final notif = _FakeNotificationService();
      final controller = DriverAlertController(
        audioService: audio,
        notificationService: notif,
        isForeground: true,
      );

      controller.onRidesUpdated([_makeRide(id: 'ride_2')]);
      expect(controller.activeForegroundOffer.value?.id, equals('ride_2'));
      expect(audio.playing, isTrue);

      controller.silenceAudio(rideId: 'ride_2');
      expect(audio.playing, isFalse);
      expect(audio.stopCalls, equals(1));
      expect(notif.cancelledIds, contains('ride_2'));
      expect(controller.activeForegroundOffer.value?.id, equals('ride_2'));

      await controller.dispose();
    });

    test('declineRide clears alert and prevents re-alerting for the same ride', () async {
      final audio = _FakeAudioService();
      final notif = _FakeNotificationService();
      final controller = DriverAlertController(
        audioService: audio,
        notificationService: notif,
        isForeground: true,
      );

      final ride = _makeRide(id: 'ride_3');
      controller.onRidesUpdated([ride]);
      expect(controller.activeForegroundOffer.value?.id, equals('ride_3'));

      await controller.declineRide('ride_3');
      expect(controller.activeForegroundOffer.value, isNull);
      expect(audio.playing, isFalse);
      expect(notif.declinedIds, contains('ride_3'));
      expect(controller.isRideDeclined('ride_3'), isTrue);

      // Next stream update still containing declined ride must not re-alert.
      controller.onRidesUpdated([ride]);
      expect(controller.activeForegroundOffer.value, isNull);
      expect(audio.startCalls, equals(1));

      await controller.dispose();
    });

    test('stops alert when ride disappears or driver goes offline', () async {
      final audio = _FakeAudioService();
      final notif = _FakeNotificationService();
      final controller = DriverAlertController(
        audioService: audio,
        notificationService: notif,
        isForeground: true,
      );

      controller.onRidesUpdated([_makeRide(id: 'ride_4')]);
      expect(controller.activeForegroundOffer.value?.id, equals('ride_4'));

      // Another driver took it -> disappeared from available list.
      controller.onRidesUpdated([]);
      expect(controller.activeForegroundOffer.value, isNull);
      expect(audio.playing, isFalse);

      controller.onRidesUpdated([_makeRide(id: 'ride_5')]);
      expect(controller.activeForegroundOffer.value?.id, equals('ride_5'));

      controller.setDriverOnline(false);
      expect(controller.activeForegroundOffer.value, isNull);
      expect(audio.playing, isFalse);

      await controller.dispose();
    });

    test('ignores foreground alerts when backgrounded and ignores expired rides', () async {
      final audio = _FakeAudioService();
      final notif = _FakeNotificationService();
      final controller = DriverAlertController(
        audioService: audio,
        notificationService: notif,
        isForeground: false,
      );

      controller.onRidesUpdated([_makeRide(id: 'ride_bg')]);
      expect(controller.activeForegroundOffer.value, isNull);
      expect(audio.startCalls, equals(0));

      controller.setLifecycleForTest(AppLifecycleState.resumed);
      final expired = _makeRide(
        id: 'ride_exp',
        expiresAt: DateTime.now().subtract(const Duration(seconds: 5)),
      );
      controller.onRidesUpdated([expired]);
      expect(controller.activeForegroundOffer.value, isNull);
      expect(audio.startCalls, equals(0));

      await controller.dispose();
    });
  });
}
