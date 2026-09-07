import 'package:caride/features/profile/data/activity_repository.dart';
import 'package:caride/features/ride_booking/data/ride_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RideModel.fromMap', () {
    test('falls back to legacy name keys when labels are absent', () {
      final ride = RideModel.fromMap(
        id: 'ride_1',
        data: const {
          'customerUid': 'uid_1',
          'pickupName': 'Ikeja',
          'dropoffName': 'Lekki',
          'status': 'requested',
        },
      );

      expect(ride.pickupLabel, 'Ikeja');
      expect(ride.dropoffLabel, 'Lekki');
      expect(ride.status, 'requested');
    });
  });

  group('RideActivityRecord.fromMap', () {
    test('maps labels and amount fallback from customer offer', () {
      final record = RideActivityRecord.fromMap(
        id: 'ride_2',
        data: const {
          'status': 'completed',
          'pickupLabel': 'Yaba',
          'dropoffLabel': 'Ajah',
          'customerOffer': 3500,
          'paymentMethod': 'wallet',
        },
      );

      expect(record.tab, RideActivityTab.completed);
      expect(record.pickup, 'Yaba');
      expect(record.dropoff, 'Ajah');
      expect(record.amountNaira, 3500);
      expect(record.paymentMethod, 'Wallet');
    });
  });
}
