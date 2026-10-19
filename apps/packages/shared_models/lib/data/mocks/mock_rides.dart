import '../../models/ride.dart';
import '../../models/ride_status.dart';
import 'mock_places.dart';

abstract final class MockRides {
  static Ride activeCustomerRide() => Ride(
        id: 'ride_001',
        pickup: MockPlaces.pickup,
        destination: MockPlaces.destination,
        customerPrice: 3500,
        suggestedMin: 3200,
        suggestedMax: 4200,
        status: RideStatus.bidding,
        distanceKm: 14.2,
        etaMinutes: 28,
      );

  static Ride driverAssignedRide() => Ride(
        id: 'ride_002',
        pickup: MockPlaces.pickup,
        destination: MockPlaces.destination,
        customerPrice: 3400,
        suggestedMin: 3100,
        suggestedMax: 4000,
        status: RideStatus.accepted,
        driverId: 'drv_01',
        distanceKm: 14.2,
        etaMinutes: 26,
      );
}
