import 'package:caride/features/profile/data/address_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SavedAddress.fromMap', () {
    test('parses required fields', () {
      final result = SavedAddress.fromMap('id1', {
        'label': 'Home',
        'address': '123 Main St',
      });

      expect(result.id, 'id1');
      expect(result.label, 'Home');
      expect(result.address, '123 Main St');
      expect(result.placeId, isNull);
      expect(result.lat, isNull);
      expect(result.lng, isNull);
    });

    test('parses optional coordinates', () {
      final result = SavedAddress.fromMap('id2', {
        'label': 'Office',
        'address': '456 Market St',
        'placeId': 'place.123',
        'lat': 6.5,
        'lng': 3.3,
      });

      expect(result.placeId, 'place.123');
      expect(result.lat, 6.5);
      expect(result.lng, 3.3);
    });
  });
}

