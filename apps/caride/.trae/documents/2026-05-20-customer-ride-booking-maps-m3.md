# Customer App “Ride Booking Maps” — Milestone 3 Plan

**Goal:** Make ride booking screens fully map-driven: show pickup/dropoff pins and a Mapbox route polyline during booking (home → choose ride), replacing static map placeholders.

**In Scope (Milestone 3):**
- Draw pickup/dropoff pins + route line on:
  - [customer_home_screen.dart](file:///Users/alphonsus/Desktop/CaRide/caride/apps/caride/lib/features/home_map/customer_home_screen.dart) (when selecting a destination)
  - [choose_ride_screen.dart](file:///Users/alphonsus/Desktop/CaRide/caride/apps/caride/lib/features/ride_booking/choose_ride_screen.dart)
- Add a Mapbox Directions “route geometry” fetcher (polyline coordinates) and render it as a map polyline overlay.
- Auto-fit camera to show the whole route (pickup + dropoff + route line) and keep the UX responsive.

**Out of Scope (Milestone 3):**
- Turn-by-turn navigation in-app.
- Driver discovery map (nearby drivers), unless we add it later as a follow-up.

---

## Current State (Grounded)

- Home map exists (`MapWidget`) but does not render pins or a route line; the “route sheet” is text-driven.
  - [customer_home_screen.dart](file:///Users/alphonsus/Desktop/CaRide/caride/apps/caride/lib/features/home_map/customer_home_screen.dart)
- Choose ride screen still uses a static map image placeholder.
  - [choose_ride_screen.dart](file:///Users/alphonsus/Desktop/CaRide/caride/apps/caride/lib/features/ride_booking/choose_ride_screen.dart#L146-L167)
- Directions API integration exists, but returns only distance/duration (no geometry).
  - [RidePricingRepository.getRouteInfo](file:///Users/alphonsus/Desktop/CaRide/caride/apps/caride/lib/features/ride_booking/data/ride_pricing_repository.dart#L107-L140)

---

## Design (Decision Complete)

### Map rendering approach
- Use `mapbox_maps_flutter` annotation managers:
  - `CircleAnnotationManager` for pickup/dropoff pins (simple colored circles).
  - `PolylineAnnotationManager` for the route polyline overlay.

This stays consistent with Mapbox’s annotations approach (point + polyline + circle annotations) and avoids custom style-layer complexity. (Mapbox annotation overview: https://docs.mapbox.com/flutter/maps/guides/markers-and-annotations/annotations/)

### Route geometry fetch
- Extend [ride_pricing_repository.dart](file:///Users/alphonsus/Desktop/CaRide/caride/apps/caride/lib/features/ride_booking/data/ride_pricing_repository.dart) with:
  - `Future<List<List<double>>?> getRouteLine({fromLng, fromLat, toLng, toLat})`
  - Use Mapbox Directions API with:
    - `overview=full`
    - `geometries=geojson`
  - Parse `routes[0].geometry.coordinates` into a list of `[lng, lat]`.

### Camera fitting
- Compute bounds from:
  - pickup coordinate
  - dropoff coordinate
  - all polyline coordinates
- Use `mapboxMap.cameraForCoordinates(...)` (preferred) if available in the SDK; otherwise:
  - set camera center to mid-point and zoom heuristically (fallback).

---

## Proposed Code Changes

### 1) Add a reusable “route overlay” controller

**Create**
- `lib/core/maps/mapbox_route_overlay.dart`
  - Holds `MapboxMap`, and lazily creates:
    - `CircleAnnotationManager` (pins)
    - `PolylineAnnotationManager` (route)
  - Public API:
    - `Future<void> setPins({required Position pickup, required Position dropoff})`
    - `Future<void> setRouteLine(List<Position> coords)`
    - `Future<void> clear()`
    - `Future<void> fitToRoute({required Position pickup, required Position dropoff, List<Position>? route})`
  - Behavior:
    - Idempotent updates (only redraw when inputs change)
    - Cleans up by deleting annotations before re-creating (safe + simple)

### 2) Extend Directions integration to return route geometry

**Modify**
- [ride_pricing_repository.dart](file:///Users/alphonsus/Desktop/CaRide/caride/apps/caride/lib/features/ride_booking/data/ride_pricing_repository.dart)
  - Add `getRouteLine(...)` that returns a `List<Position>` (or null).
  - Keep `getRouteInfo(...)` as-is for pricing and ETA (no breaking change).

### 3) Upgrade ChooseRideScreen map background to live Mapbox

**Modify**
- [choose_ride_screen.dart](file:///Users/alphonsus/Desktop/CaRide/caride/apps/caride/lib/features/ride_booking/choose_ride_screen.dart)

**Implementation**
- Replace the `Image.asset(map_placeholder)` background with:
  - `MapWidget` when token is present
  - fallback placeholder image when token is missing
- In `onMapCreated`:
  - Create `MapboxRouteOverlay` and call:
    - `setPins(pickup, dropoff)` using `widget.params`
    - `getRouteLine(...)` and `setRouteLine(...)`
    - `fitToRoute(...)`

**Acceptance**
- The top map shows the live route (line + two pins) for the current booking.

### 4) Render booking pins + route on the home map during destination selection

**Modify**
- [customer_home_screen.dart](file:///Users/alphonsus/Desktop/CaRide/caride/apps/caride/lib/features/home_map/customer_home_screen.dart)

**Implementation**
- Keep the existing UX (search + recent + saved) but add map overlays:
  - When `_selectedFrom` exists → show pickup pin
  - When `_selectedTo` exists → show dropoff pin
  - When both exist → fetch route geometry with `RidePricingRepository.getRouteLine(...)` (new method), then draw polyline + fit camera.
- Cache the last requested route to avoid refetching on rebuilds.

**Acceptance**
- While selecting “To”, the map visually updates to the selected place and, once both points are set, shows the full route.

---

## Verification

**Static checks**
- No analyzer errors in edited files (IDE diagnostics should be clean).

**Manual QA**
- Home:
  - Select destination from search results → pins appear and route line draws.
  - Switch between saved/recent/search → map updates correctly.
- Choose ride:
  - When opened with params → map shows route + pins and fits camera.
  - When Mapbox token missing → placeholder is shown and UI still works.

---

## Assumptions

- `AppEnv.mapboxAccessToken` is configured for environments where maps are expected.
- `customer_home_screen.dart` provides both pickup and dropoff coordinates (it already uses Mapbox geocoding and stored lat/lng).

