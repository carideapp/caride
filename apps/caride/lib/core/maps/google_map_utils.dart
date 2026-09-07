import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:geolocator/geolocator.dart' as geo;
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Shared Google Maps helper utilities — GPS fly-to and custom pin bitmaps.
abstract final class GoogleMapUtils {
  // ── Camera / GPS ───────────────────────────────────────────────────────────

  /// Animates the camera to the device's current GPS position.
  /// Returns the GPS [geo.Position] if successful, or null if permission
  /// denied / unavailable.
  static Future<geo.Position?> flyToGps(
    GoogleMapController controller, {
    double zoom = 15.0,
  }) async {
    try {
      final perm = await geo.Geolocator.checkPermission();
      if (perm == geo.LocationPermission.denied ||
          perm == geo.LocationPermission.deniedForever) {
        return null;
      }

      // 1. Instantly fly to last known location if available
      final lastKnown = await geo.Geolocator.getLastKnownPosition();
      if (lastKnown != null) {
        await controller.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: LatLng(lastKnown.latitude, lastKnown.longitude),
              zoom: zoom,
            ),
          ),
        );
      }

      // 2. Fetch fresh high-accuracy position in background
      final pos = await geo.Geolocator.getCurrentPosition(
        locationSettings: const geo.LocationSettings(
          accuracy: geo.LocationAccuracy.high,
          timeLimit: Duration(seconds: 4),
        ),
      );
      await controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(pos.latitude, pos.longitude),
            zoom: zoom,
          ),
        ),
      );
      return pos;
    } catch (_) {
      try {
        return await geo.Geolocator.getLastKnownPosition();
      } catch (_) {
        return null;
      }
    }
  }

  // ── Custom pin bitmaps ─────────────────────────────────────────────────────

  /// Renders a teardrop / map-pin bitmap at [size] x [size*1.5] pixels.
  /// Compatible with [BitmapDescriptor.bytes].
  static Future<Uint8List> createPinBitmap({
    required Color color,
    Color iconColor = Colors.white,
    double size = 36,
  }) async {
    final w = size;
    final h = size * 1.5;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, w, h));

    final radius = w / 2;
    final cx = w / 2;
    final cy = radius;

    // Drop shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.22)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawCircle(Offset(cx + 1, cy + 2), radius - 1, shadowPaint);

    // Pin circle
    final fillPaint = Paint()..color = color;
    canvas.drawCircle(Offset(cx, cy), radius - 2, fillPaint);

    // White ring
    final ringPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawCircle(Offset(cx, cy), radius - 3.5, ringPaint);

    // Inner dot
    final dotPaint = Paint()..color = iconColor;
    canvas.drawCircle(Offset(cx, cy), radius * 0.22, dotPaint);

    // Tail
    final path = Path();
    final tailW = radius * 0.46;
    path.moveTo(cx - tailW, cy + radius - 4);
    path.quadraticBezierTo(cx, h + 2, cx + tailW, cy + radius - 4);
    path.close();
    canvas.drawPath(path, fillPaint);

    final picture = recorder.endRecording();
    final image = await picture.toImage(w.round(), h.round());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    return bytes!.buffer.asUint8List();
  }

  /// Green teardrop pin for pickup.
  static Future<BitmapDescriptor> createPickupPin({double size = 34}) async {
    final bytes = await createPinBitmap(
      color: const Color(0xFF16A34A),
      size: size,
    );
    return BitmapDescriptor.bytes(bytes);
  }

  /// Dark teardrop pin for dropoff.
  static Future<BitmapDescriptor> createDropoffPin({double size = 34}) async {
    final bytes = await createPinBitmap(
      color: const Color(0xFF0F172A),
      size: size,
    );
    return BitmapDescriptor.bytes(bytes);
  }

  /// Cached driver icon descriptors keyed by [targetWidth].
  /// Avoids re-running the dart:ui codec pipeline on every marker update.
  static final Map<int, BitmapDescriptor> _iconCache = {};

  /// Loads the driver car icon, resizing it to a target width of 65px, with a fallback if the asset is missing.
  static Future<BitmapDescriptor> getDriverIcon({int targetWidth = 65}) async {
    final cached = _iconCache[targetWidth];
    if (cached != null) return cached;

    try {
      final data = await rootBundle.load('lib/assets/motorcycle.png');
      final codec = await ui.instantiateImageCodec(
        data.buffer.asUint8List(),
        targetWidth: targetWidth,
      );
      final frame = await codec.getNextFrame();
      final byteData = await frame.image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception('Failed to decode image');
      final descriptor = BitmapDescriptor.bytes(byteData.buffer.asUint8List());
      _iconCache[targetWidth] = descriptor;
      return descriptor;
    } catch (_) {
      // Fallback custom circular pin for the driver
      final bytes = await createPinBitmap(
        color: const Color(0xFF1E3A8A),
        size: (targetWidth * 0.4).clamp(10.0, 30.0),
      );
      final descriptor = BitmapDescriptor.bytes(bytes);
      _iconCache[targetWidth] = descriptor;
      return descriptor;
    }
  }

  // ── Math helpers ───────────────────────────────────────────────────────────

  /// Bearing from point A to point B in degrees (0 = north).
  static double bearingBetween(
      double lat1, double lng1, double lat2, double lng2) {
    final dLng = (lng2 - lng1) * math.pi / 180;
    final radLat1 = lat1 * math.pi / 180;
    final radLat2 = lat2 * math.pi / 180;
    final y = math.sin(dLng) * math.cos(radLat2);
    final x = math.cos(radLat1) * math.sin(radLat2) -
        math.sin(radLat1) * math.cos(radLat2) * math.cos(dLng);
    return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
  }

  // ── Encoded polyline decoder ───────────────────────────────────────────────

  /// Decodes a Google Maps encoded polyline string into a list of [LatLng].
  static List<LatLng> decodePolyline(String encoded) {
    final List<LatLng> result = [];
    int index = 0;
    int lat = 0;
    int lng = 0;

    while (index < encoded.length) {
      int shift = 0;
      int result0 = 0;
      int b;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result0 |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dlat = (result0 & 1) != 0 ? ~(result0 >> 1) : result0 >> 1;
      lat += dlat;

      shift = 0;
      result0 = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result0 |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final dlng = (result0 & 1) != 0 ? ~(result0 >> 1) : result0 >> 1;
      lng += dlng;

      result.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return result;
  }
}
