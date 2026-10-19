import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class WeatherData {
  final double temperature;
  final String locationName;
  final int weatherCode;

  const WeatherData({
    required this.temperature,
    required this.locationName,
    required this.weatherCode,
  });

  String get formattedTemp => '${temperature.round()}°C';

  IconData get weatherIcon {
    if (weatherCode == 0 || weatherCode == 1) {
      return Icons.wb_sunny_rounded;
    } else if (weatherCode == 2 || weatherCode == 3) {
      return Icons.wb_cloudy_rounded;
    } else if (weatherCode >= 51 && weatherCode <= 82) {
      return Icons.water_drop_rounded;
    } else if (weatherCode >= 95) {
      return Icons.thunderstorm_rounded;
    }
    return Icons.wb_sunny_rounded;
  }
}

class WeatherService {
  static WeatherData? _cachedData;

  static WeatherData? get cachedData => _cachedData;

  static Future<WeatherData?> fetchWeather(double lat, double lng) async {
    try {
      // 1. Fetch weather from Open-Meteo API
      final weatherUri = Uri.parse(
        'https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lng&current=temperature_2m,weather_code',
      );
      final weatherResponse = await http.get(weatherUri).timeout(const Duration(seconds: 6));

      if (weatherResponse.statusCode != 200) return _cachedData;

      final weatherJson = jsonDecode(weatherResponse.body) as Map<String, dynamic>;
      final current = weatherJson['current'] as Map<String, dynamic>?;
      if (current == null) return _cachedData;

      final temp = (current['temperature_2m'] as num).toDouble();
      final code = (current['weather_code'] as num?)?.toInt() ?? 0;

      // 2. Reverse geocode to get current state name
      String locationName = '';
      try {
        final geoUri = Uri.parse(
          'https://api.bigdatacloud.net/data/reverse-geocode-client?latitude=$lat&longitude=$lng&localityLanguage=en',
        );
        final geoResponse = await http.get(geoUri).timeout(const Duration(seconds: 5));
        if (geoResponse.statusCode == 200) {
          final geoJson = jsonDecode(geoResponse.body) as Map<String, dynamic>;
          final state = (geoJson['principalSubdivision'] as String?)?.trim();
          final city = (geoJson['city'] as String?)?.trim();
          final locality = (geoJson['locality'] as String?)?.trim();

          if (state != null && state.isNotEmpty) {
            var s = state.replaceAll(RegExp(r'\s+State$', caseSensitive: false), '').trim();
            if (s.toLowerCase().contains('federal capital territory')) {
              s = 'Abuja';
            }
            locationName = s;
          } else if (city != null && city.isNotEmpty) {
            locationName = city;
          } else if (locality != null && locality.isNotEmpty) {
            locationName = locality;
          }
        }
      } catch (_) {}

      _cachedData = WeatherData(
        temperature: temp,
        locationName: locationName,
        weatherCode: code,
      );

      return _cachedData;
    } catch (_) {
      return _cachedData;
    }
  }
}
