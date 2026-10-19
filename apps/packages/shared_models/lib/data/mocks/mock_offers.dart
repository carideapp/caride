import '../../models/driver_offer.dart';

abstract final class MockOffers {
  static List<DriverOffer> forRide() => const [
        DriverOffer(
          id: 'off_1',
          driverId: 'drv_01',
          driverName: 'Chidi O.',
          rating: 4.9,
          vehicleLabel: 'Toyota Corolla · ABC 123 KJ',
          offeredPrice: 3500,
          etaMinutes: 6,
        ),
        DriverOffer(
          id: 'off_2',
          driverId: 'drv_02',
          driverName: 'Amaka N.',
          rating: 4.8,
          vehicleLabel: 'Honda Civic · LND 482 AB',
          offeredPrice: 3600,
          etaMinutes: 8,
          isCounter: true,
        ),
        DriverOffer(
          id: 'off_3',
          driverId: 'drv_03',
          driverName: 'Tunde A.',
          rating: 4.7,
          vehicleLabel: 'Kia Rio · FCT 901 XY',
          offeredPrice: 3400,
          etaMinutes: 10,
        ),
      ];
}
