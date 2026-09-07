import 'package:caride/core/maps/google_map_utils.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Manages pickup/dropoff pin [Marker]s and the route [Polyline] on a
/// [GoogleMapController].
///
/// Drop-in replacement for the old MapboxRouteOverlay, with the same API
/// surface (setPins, setRouteLine, fitToRoute, clear).
class GoogleRouteOverlay {
  GoogleRouteOverlay(this._controller);

  final GoogleMapController _controller;

  // Markers keyed so Google Maps replaces them in place
  static const MarkerId _pickupId = MarkerId('pickup');
  static const MarkerId _dropoffId = MarkerId('dropoff');
  static const PolylineId _casingId = PolylineId('route_casing');
  static const PolylineId _foregroundId = PolylineId('route_foreground');

  // Lazy-loaded custom bitmaps
  BitmapDescriptor? _pickupIcon;
  BitmapDescriptor? _dropoffIcon;

  // Cached state for change detection
  LatLng? _lastPickup;
  LatLng? _lastDropoff;
  List<LatLng>? _lastRoute;

  // Publicly readable map objects — callers set these on the GoogleMap widget
  final Map<MarkerId, Marker> markers = {};
  final Map<PolylineId, Polyline> polylines = {};

  /// Clears all overlays.
  void clear() {
    markers.clear();
    polylines.clear();
    _lastPickup = null;
    _lastDropoff = null;
    _lastRoute = null;
  }

  /// Places pickup and optionally dropoff teardrop pins on the map.
  Future<void> setPins({
    required LatLng pickup,
    LatLng? dropoff,
  }) async {
    final same = _lastPickup == pickup && _lastDropoff == dropoff;
    if (same) return;
    _lastPickup = pickup;
    _lastDropoff = dropoff;

    _pickupIcon ??= await GoogleMapUtils.createPickupPin(size: 34);

    markers[_pickupId] = Marker(
      markerId: _pickupId,
      position: pickup,
      icon: _pickupIcon!,
      anchor: const Offset(0.5, 1.0),
    );

    if (dropoff != null) {
      _dropoffIcon ??= await GoogleMapUtils.createDropoffPin(size: 34);
      markers[_dropoffId] = Marker(
        markerId: _dropoffId,
        position: dropoff,
        icon: _dropoffIcon!,
        anchor: const Offset(0.5, 1.0),
      );
    } else {
      markers.remove(_dropoffId);
    }
  }

  /// Draws a double-layered route polyline (white casing + green foreground).
  void setRouteLine(List<LatLng> coords) {
    if (_sameRoute(_lastRoute, coords)) return;
    _lastRoute = List<LatLng>.unmodifiable(coords);

    // White casing beneath the route for depth
    polylines[_casingId] = Polyline(
      polylineId: _casingId,
      points: coords,
      color: const Color(0xFFFFFFFF),
      width: 8,
    );

    // Brand-green foreground
    polylines[_foregroundId] = Polyline(
      polylineId: _foregroundId,
      points: coords,
      color: const Color(0xFF16A34A),
      width: 5,
    );
  }

  /// Animates the camera to fit both pins (and the route if provided) with padding.
  Future<void> fitToRoute({
    required LatLng pickup,
    required LatLng dropoff,
    List<LatLng>? route,
  }) async {
    final allPoints = <LatLng>[pickup, dropoff, ...?route];
    double minLat = allPoints.first.latitude;
    double maxLat = allPoints.first.latitude;
    double minLng = allPoints.first.longitude;
    double maxLng = allPoints.first.longitude;

    for (final p in allPoints) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    await _controller.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(
          southwest: LatLng(minLat, minLng),
          northeast: LatLng(maxLat, maxLng),
        ),
        80, // padding in logical pixels
      ),
    );
  }
}

bool _sameRoute(List<LatLng>? a, List<LatLng>? b) {
  if (a == null || b == null) return false;
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i].latitude != b[i].latitude || a[i].longitude != b[i].longitude) {
      return false;
    }
  }
  return true;
}
