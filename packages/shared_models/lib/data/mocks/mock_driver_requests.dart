import '../../models/driver_incoming_request.dart';

abstract final class MockDriverRequests {
  static List<DriverIncomingRequest> pending() => const [
        DriverIncomingRequest(
          id: 'req_1',
          routeLabel: 'Lekki → Ikeja City Mall',
          customerOffer: 3500,
          pickupEtaMinutes: 4,
          passengerRating: 4.8,
        ),
        DriverIncomingRequest(
          id: 'req_2',
          routeLabel: 'VI → Airport',
          customerOffer: 9000,
          pickupEtaMinutes: 9,
          passengerRating: 4.6,
        ),
      ];
}
