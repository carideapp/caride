import 'dart:async';

import 'package:caride/features/home_map/data/mapbox_search_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('MapboxSearchService.searchPlaces', () {
    test('returns parsed places on successful response', () async {
      final client = MockClient((_) async {
        return http.Response(
          '{"places":[{"id":"place.1","displayName":{"text":"Ikeja City Mall"},"formattedAddress":"Ikeja City Mall","location":{"latitude":6.60,"longitude":3.35}}]}',
          200,
        );
      });
      final service = MapboxSearchService('token', httpClient: client);

      final places = await service.searchPlaces('ikeja');

      expect(places, hasLength(1));
      expect(places.first.id, 'place.1');
      expect(places.first.placeName, 'Ikeja City Mall, Ikeja City Mall');
      expect(places.first.centerLng, 3.35);
      expect(places.first.centerLat, 6.60);
    });

    test('returns empty list on timeout exception', () async {
      final client = MockClient((_) async {
        throw TimeoutException('request timed out');
      });
      final service = MapboxSearchService('token', httpClient: client);

      final places = await service.searchPlaces('lekki');

      expect(places, isEmpty);
    });
  });
}
