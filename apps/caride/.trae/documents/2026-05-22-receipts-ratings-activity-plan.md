# Receipts + Ratings + Activity = 100% Real Data (Customer + Driver) — Plan

## Summary

Replace remaining placeholder/mock UI content in:
- Customer **Activity** (ride history list + arrival prompt)
- Customer **Trip Receipt**
- Customer **Rate Driver**

…with live Firestore data derived from existing `rides/{rideId}` fields (no new schema/Cloud Functions changes). Also update driver app screens that still rely on mocks so both apps stay consistent.

Constraints / Preferences (from you)
- Do **not** create new test files and do **not** run `flutter test`.
- Do run `flutter analyze` and fix lint errors.
- Receipt should be **minimal from existing ride fields** (no receipt snapshot / no new backend breakdown).
- Customer rating should be **one-time**: show “already rated” UI if `driverRating` is already set.
- Keep sync with `/apps/driver_app` by updating corresponding screens/services when they are mock/misaligned.
- No Figma file available → skip Figma generation for this milestone.

## Current State (Grounded)

### Customer app issues (placeholders)
- Trip receipt is fully hardcoded:
  - [share_receipt_screen.dart](file:///Users/alphonsus/Desktop/CaRide/caride/apps/caride/lib/features/profile/share_receipt_screen.dart)
- Rate driver includes placeholder brand text, hardcoded amounts, hardcoded avatar initial:
  - [rate_driver_screen.dart](file:///Users/alphonsus/Desktop/CaRide/caride/apps/caride/lib/features/profile/rate_driver_screen.dart)
- Activity screen has remaining mock logic:
  - Uses `RideFlowSession` to override a “fake” arrival prompt (hardcoded destination/metrics)
  - Calls `RateDriverScreen()` without passing `rideId`
  - Calls `CancelRideScreen()` without passing `rideId`
  - [ride_history_screen.dart](file:///Users/alphonsus/Desktop/CaRide/caride/apps/caride/lib/features/profile/ride_history_screen.dart)
- ActivityRepository already streams rides from Firestore, but falls back to placeholder labels for time/date/payment method:
  - [activity_repository.dart](file:///Users/alphonsus/Desktop/CaRide/caride/apps/caride/lib/features/profile/data/activity_repository.dart)

### Driver app sync issues
- Driver ride history is still mock (`MockRideHistory.items()`), so it can’t reflect the same rides/receipts:
  - [driver_ride_history_screen.dart](file:///Users/alphonsus/Desktop/CaRide/caride/apps/driver_app/lib/features/profile/driver_ride_history_screen.dart)
- Driver ride detail screen labels “CUSTOMER RATING” but renders `ride.driverRating` (customer’s rating of driver), which is semantically mismatched:
  - [driver_ride_detail_screen.dart](file:///Users/alphonsus/Desktop/CaRide/caride/apps/driver_app/lib/features/rides/driver_ride_detail_screen.dart)

## Approach Options

### Option A (Recommended): “Minimal, ride-derived receipt + one-time rating + real activity lists”
- Customer receipt/rating/activity screens stream `rides/{rideId}` and render only fields that exist today.
- If a field is missing (e.g., vehicle), hide that row rather than inventing placeholder data.
- Driver app replaces mock ride history with Firestore-backed ride history and links into existing ride detail.

### Option B: Add “receipt snapshot” backend fields
- Not chosen for this milestone (you chose minimal/no schema changes).

## Data Sources (No Schema Changes)

All derived from `rides/{rideId}` and existing fields already present in codebases:
- `pickupLabel`, `dropoffLabel`
- `createdAt`, `acceptedAt`, `rideStartedAt`, `completedAt`, `updatedAt`
- `paymentMethod`, `paymentStatus`
- `finalFare`, `amountNaira`, `customerOffer`
- `driverUid`, `driverName`
- `driverRating`, `ratedAt`
- `customerRating`, `customerRatedAt`, `customerRatingComment` (driver app already writes these)

## Proposed Changes (Concrete)

### 1) Customer — Trip Receipt becomes Firestore-backed

**Modify**
- `lib/features/profile/share_receipt_screen.dart`
- `lib/features/profile/trip_details_screen.dart`

**Implementation**
- Update `ShareReceiptScreen` to accept `rideId` (`final String rideId;`) and stream ride:
  - Use `RideRepository.watchRide(rideId)` (already exists).
- Render “Ride Summary” from:
  - Pickup/Dropoff: `ride.pickupLabel`, `ride.dropoffLabel`
  - Date/Time: `ride.createdAt` formatted (fallback: `--`)
  - Driver: `ride.driverName` (fallback: “Driver”)
  - Payment method: `ride.paymentMethod` mapped to friendly label (“cash” → “Cash”, “wallet” → “Wallet”)
- Render “Fare Breakdown” minimally from:
  - Display fare: `ride.finalFare ?? ride.amountNaira ?? ride.customerOffer`
  - Total paid equals display fare
  - If `paymentStatus` exists, show Paid/Unpaid chip; otherwise omit
- Replace current hardcoded snackbar behavior with:
  - Keep the snackbar (no share plugin in scope), but ensure it doesn’t imply fake receipt content.
- Wire `TripDetailsScreen` to pass `ShareReceiptScreen(rideId: ride.id)` instead of const.

### 2) Customer — Rate Driver becomes Firestore-backed + one-time

**Modify**
- `lib/features/profile/rate_driver_screen.dart`
- `lib/features/profile/ride_history_screen.dart`

**Implementation**
- Make `RateDriverScreen` require `rideId` (keep nullable param for backward compatibility if needed, but primary flow passes real `rideId`).
- Stream ride via `RideRepository.watchRide(rideId)` and render:
  - Avatar initial derived from `ride.driverName`
  - Copy updated to CaRide wording (remove “JoyRide”)
  - Payment method summary derived from `ride.paymentMethod`
  - Fare summary derived from same display fare as receipt
- One-time rule:
  - If `ride.driverRating != null` OR `ride.ratedAt != null`, show a read-only “Already rated” state (stars + value) and disable submit.
  - Otherwise allow submit using existing `RideRepository.rateDriver` (already compatible with rules).
- Update `RideHistoryScreen` to call `RateDriverScreen(rideId: item.id)` instead of const.

### 3) Customer — Activity screen removes mock session logic and uses ride truth

**Modify**
- `lib/features/profile/ride_history_screen.dart`
- `lib/features/profile/data/activity_repository.dart`

**Implementation**
- Remove (or fully disable) mock-only logic:
  - `_effectiveTab` special-casing `item.id == 'r1'`
  - `_maybeShowArrivalPrompt` and `_ArrivalDialog` which contain hardcoded destination/metrics
  - `RideFlowSession` usage
- Ensure actions pass real IDs:
  - Cancel ride uses `CancelRideScreen(rideId: item.id)`
  - Rate driver uses `RateDriverScreen(rideId: item.id)`
  - View trip already passes `TripDetailsScreen(rideId: item.id)`
- Make ActivityRepository derive labels from timestamps when present:
  - `dateLabel`: from `createdAt` or `updatedAt` formatted
  - `pickupTimeLabel` / `dropoffTimeLabel`: from `acceptedAt` / `completedAt` if available (otherwise `--:--`)
  - `paymentMethod`: map from stored `paymentMethod` (`cash`/`wallet`) instead of defaulting to “Cash”
- Keep `distanceKm` and amounts from the ride doc, but avoid “fake” fallback values beyond empty-safe defaults.

### 4) Driver app — Replace mock ride history with Firestore ride history

**Modify**
- `apps/driver_app/lib/features/profile/driver_ride_history_screen.dart`

**Implementation**
- Replace `MockRideHistory.items()` with `DriverRideRepository.streamRideHistory()`:
  - Render only completed rides by filtering `ride.status == 'completed'` (or show all with chips).
- Make each card navigable to `DriverRideDetailScreen(rideId: ride.id)`.
- Display fare using the same field priority:
  - `finalFare ?? amountNaira ?? customerOffer`

### 5) Driver app — Fix rating label mismatch in ride detail

**Modify**
- `apps/driver_app/lib/features/rides/driver_ride_detail_screen.dart`

**Implementation**
- Change the “CUSTOMER RATING” section to render `ride.customerRating` (not `ride.driverRating`), because:
  - Driver app writes `customerRating` in `DriverRideRepository.rateCustomer`.
- If `customerRating` isn’t currently parsed into `RideModel`, extend driver `RideModel` to include:
  - `final int? customerRating;`
  - `final String? customerRatingComment;`
  - `final DateTime? customerRatedAt;`
  - Map from Firestore fields already written by driver app:
    - `customerRating`, `customerRatingComment`, `customerRatedAt`

## Assumptions & Decisions
- No changes to Firestore schema are required for receipts (minimal receipt derived from existing ride fields).
- Currency remains NGN for now; we will reuse existing NGN formatting patterns already in the repo (customer uses `_formatNaira`, driver uses `NgnFormat`).
- Share action remains “UI-only snackbar” until a later milestone adds a share plugin.

## Verification (When Executing)

Customer app:
- Run `flutter analyze` in `apps/caride/` and fix all issues.
- Manual checks:
  - Open Trip Details → Share Receipt shows live data for that ride
  - Activity list shows real pickup/dropoff, fare, and date/time derived from ride timestamps
  - Rate Driver shows driver name/initial and prevents re-rating after `driverRating` set

Driver app:
- Run `flutter analyze` in `apps/driver_app/` and fix all issues.
- Manual checks:
  - Driver Ride History shows real rides from Firestore and opens ride details
  - Driver Ride Detail shows correct “Customer Rating” based on `customerRating`

