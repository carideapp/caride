import 'package:caride/features/home_map/data/recent_places_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('RecentPlace.fromMap', () {
    test('returns null for invalid input', () {
      expect(RecentPlace.fromMap('id', const {}), isNull);
      expect(
        RecentPlace.fromMap('id', {
          'placeName': '',
          'lat': 1,
          'lng': 2,
        }),
        isNull,
      );
      expect(
        RecentPlace.fromMap('id', {
          'placeName': 'X',
          'lat': '1',
          'lng': 2,
        }),
        isNull,
      );
    });

    test('parses valid record', () {
      final p = RecentPlace.fromMap('id1', {
        'placeName': 'My Place',
        'placeId': 'place.123',
        'lat': 6.5,
        'lng': 3.3,
      });

      expect(p, isNotNull);
      expect(p!.id, 'id1');
      expect(p.placeName, 'My Place');
      expect(p.placeId, 'place.123');
      expect(p.lat, 6.5);
      expect(p.lng, 3.3);
    });
  });
}

