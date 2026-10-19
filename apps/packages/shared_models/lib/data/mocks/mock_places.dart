import '../../models/place.dart';

abstract final class MockPlaces {
  static const Place pickup = Place(
    label: 'Current location',
    address: '12 Admiralty Way, Lekki Phase 1',
    lat: 6.4281,
    lng: 3.4219,
  );

  static const Place destination = Place(
    label: 'Ikeja City Mall',
    address: '194 Obafemi Awolowo Way, Ikeja',
    lat: 6.6018,
    lng: 3.3515,
  );
}
