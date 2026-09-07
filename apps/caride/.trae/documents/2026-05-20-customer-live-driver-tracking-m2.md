# Customer App “Live Driver Tracking Map” — Milestone 2 Plan

**Goal:** Replace the mocked `DriverTrackingScreen` with a live Mapbox tracking experience that shows pickup/dropoff + a moving car icon from Firestore real-time driver location, plus working Chat and Call actions.

**Scope (Milestone 2):**
- Upgrade [driver_tracking_screen.dart](file:///Users/alphonsus/Desktop/CaRide/caride/apps/caride/lib/features/profile/driver_tracking_screen.dart) to stream live ride + driver + driver-location data (no timers, no mock stages).
- Render Mapbox map with 3 markers: pickup, dropoff, driver-car (rotated by heading if present).
- Wire entry points so tracking always receives a `rideId` (from ride history → trip details → tracking).
- Implement Call via `tel:` deep link (driver phone from `drivers/{driverUid}.phone`).

**Out of Scope (Milestone 2):**
- Full-blown route polylines / turn-by-turn navigation in customer app.
- Full redesign of all ride-history/trip-details UI; only refactors needed to pass rideId + remove hardcoded driver/ride fields that are now displayed in the tracking UI.

---

## Current State (Grounded)

- `DriverTrackingScreen` is fully mocked:
  - Uses a `Timer` to advance fake stages.
  - Uses placeholder map image and hardcoded addresses/driver/car values.
  - Hardcodes chat rideId `'active-ride'`.
  - File: [driver_tracking_screen.dart](file:///Users/alphonsus/Desktop/CaRide/caride/apps/caride/lib/features/profile/driver_tracking_screen.dart)
- Real ride status streaming exists already:
  - [RideRepository.watchRide](file:///Users/alphonsus/Desktop/CaRide/caride/apps/caride/lib/features/ride_booking/data/ride_repository.dart#L169-L175)
- Driver app publishes live location to Firestore:
  - `driverLocations/{rideId}` with `lat/lng/heading/...`
  - Source: [driver_app LocationRepository](file:///Users/alphonsus/Desktop/CaRide/caride/apps/driver_app/lib/features/location/data/location_repository.dart#L30-L76)
- Trip details screen is currently mocked and launches tracking without ride context:
  - [trip_details_screen.dart](file:///Users/alphonsus/Desktop/CaRide/caride/apps/caride/lib/features/profile/trip_details_screen.dart)
  - Invoked by ride history list: [ride_history_screen.dart](file:///Users/alphonsus/Desktop/CaRide/caride/apps/caride/lib/features/profile/ride_history_screen.dart#L137-L151)

---

## Design (Decision Complete)

### Data sources
- **Ride**: `rides/{rideId}` via `RideRepository.watchRide(rideId)`
  - Extend `RideModel` to include `pickupLat/pickupLng/dropoffLat/dropoffLng` and `driverUid` (already), plus optional `driverName`.
- **Driver live location**: `driverLocations/{rideId}` via a new `DriverLocationRepository.watchRideDriverLocation(rideId)`
  - If doc missing, show “Waiting for driver location…” and keep map centered on pickup.
- **Driver contact**: `drivers/{driverUid}` via a new `DriverPublicProfileRepository.watchDriver(driverUid)`
  - Use `phone` for Call; use `fullName/profilePhotoUrl/averageRating` if present.

### Map rendering approach
- Use Mapbox Flutter **PointAnnotationManager** with a custom PNG asset for the car icon.
- Markers:
  - Pickup pin: point annotation (simple pin asset or a small colored circle annotation).
  - Dropoff pin: point annotation (distinct color).
  - Driver car: point annotation with `iconRotate` set from `heading` when available.
- Auto-follow: when driver location updates, animate camera to follow driver (unless user manually pans; we will provide a “Re-center” button to restore following).

Reference implementation pattern for custom icon point annotations (Mapbox official guide): https://docs.mapbox.com/flutter/maps/guides/markers-and-annotations/annotations/

### UX flow
- From ride activity list (RideHistory), open TripDetails with rideId.
- From TripDetails, open DriverTracking and pass rideId.
- DriverTracking shows:
  - Fullscreen map behind.
  - Top card: pickup + dropoff labels (from ride).
  - Bottom card: status text derived from ride.status + driver row (name/rating) + chat + call.
  - If ride.status becomes `completed` or `cancelled`, tracking screen offers “Back” and stops following.

---

## Planned Firestore Contract (No Breaking Changes)

### `driverLocations/{rideId}`
Already produced by driver app:
- `driverUid: string`
- `lat: number`
- `lng: number`
- `heading: number?`
- `speedMps: number?`
- `accuracyM: number?`
- `updatedAt: timestamp`

### `drivers/{driverUid}`
Already exists in driver app; customer will read:
- `fullName: string?`
- `phone: string?`
- `profilePhotoUrl: string?`
- `averageRating: number?`

---

## Proposed Code Changes

### 1) Add customer-side repositories/models for driver data

**Create**
- `lib/features/profile/data/driver_location_repository.dart`
  - `DriverRideLocation` model (lat/lng/heading/speed/accuracy)
  - `Stream<DriverRideLocation?> watchRideDriverLocation(String rideId)`
- `lib/features/profile/data/driver_public_profile_repository.dart`
  - `DriverPublicProfile` model (fullName/phone/photoUrl/rating)
  - `Stream<DriverPublicProfile?> watchDriver(String driverUid)`

**Modify**
- `lib/features/ride_booking/data/ride_repository.dart`
  - Extend `RideModel` to parse pickup/dropoff coordinates (already written in `createRideRequest`)

### 2) Add a small phone launcher utility + dependency

**Modify**
- `pubspec.yaml` (customer app) to include `url_launcher`
- `flutter/assets` section to include the new car icon PNG

**Create**
- `lib/core/utils/phone_launcher.dart`
  - `PhoneLauncher.call(String phone)` using `launchUrl(Uri.parse('tel:$phone'))`
  - Mirror the style of driver app’s [MapsLauncher](file:///Users/alphonsus/Desktop/CaRide/caride/apps/driver_app/lib/core/utils/maps_launcher.dart)

### 3) Upgrade DriverTrackingScreen to be live

**Modify**
- [driver_tracking_screen.dart](file:///Users/alphonsus/Desktop/CaRide/caride/apps/caride/lib/features/profile/driver_tracking_screen.dart)

**Implementation details**
- Remove `_stages`, `_timer`, `RideFlowSession` stage simulation, and hardcoded labels.
- Add `rideId` input:
  - Prefer `GoRouterState.of(context).extra` when opened via routes.
  - Also allow a constructor param for `MaterialPageRoute` callers.
- Build the screen from combined streams:
  - `StreamBuilder<RideModel?>` (ride)
  - Nested `StreamBuilder<DriverRideLocation?>` (driver location)
  - Nested `StreamBuilder<DriverPublicProfile?>` (driver profile)
- Mapbox:
  - Create `PointAnnotationManager` in `onMapCreated` and load the PNG bytes via `rootBundle.load(...)`.
  - Keep references to created annotations so we can update driver position without recreating layers each tick.
  - Update the driver annotation geometry/rotation on each location update.

### 4) Wire rideId through Trip Details entry point

**Modify**
- [ride_history_screen.dart](file:///Users/alphonsus/Desktop/CaRide/caride/apps/caride/lib/features/profile/ride_history_screen.dart)
  - Pass `rideId: item.id` into TripDetailsScreen.
- [trip_details_screen.dart](file:///Users/alphonsus/Desktop/CaRide/caride/apps/caride/lib/features/profile/trip_details_screen.dart)
  - Accept `rideId` and stream the ride doc to show real pickup/dropoff, price, status.
  - “Track Driver” button pushes DriverTrackingScreen with the same rideId.

---

## Verification

**Static checks**
- `dart analyze` for `apps/caride`

**Runtime manual QA**
- With an active ride that has a driver assigned:
  - Open Activity → Trip Details → Track Driver
  - Map loads (token present) and shows pickup/dropoff + moving car icon
  - Chat opens the correct ride thread
  - Call launches dialer using driver phone from Firestore
- With missing driverLocations doc:
  - Tracking shows “Waiting for driver location…” and does not crash

---

## Assumptions

- Customer rides store `pickupLat/pickupLng/dropoffLat/dropoffLng` (already written during ride creation).
- Driver app continues publishing `driverLocations/{rideId}` for assigned rides.
- Driver phone is stored as a dialable string in `drivers/{uid}.phone`.

