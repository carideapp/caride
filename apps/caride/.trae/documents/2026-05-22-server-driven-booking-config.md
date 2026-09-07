# Server-Driven Booking Config — Plan

## Summary

Make booking configuration server-driven (Firestore `config/` docs) while keeping ride option images hardcoded in-app. This removes duplicated ride option lists, introduces wallet top-up config, and improves pricing fallbacks without adding tests. Ensure ride type values remain compatible with driver app displays.

## Current State Analysis (Repo Grounding)

### Customer app

- Ride options are duplicated in two places:
  - Hardcoded constant list in [ride_option.dart](file:///Users/alphonsus/Desktop/CaRide/caride/apps/caride/lib/features/ride_booking/booking_shell/models/ride_option.dart#L13-L34)
  - Hardcoded `_rideOptions` list in [choose_ride_screen.dart](file:///Users/alphonsus/Desktop/CaRide/caride/apps/caride/lib/features/ride_booking/choose_ride_screen.dart#L40-L61)
- ChooseRide pricing uses Firestore-backed pricing config, but uses a hardcoded distance fallback:
  - `distKm = route?.distanceKm ?? 5.0` in [_formattedPrice](file:///Users/alphonsus/Desktop/CaRide/caride/apps/caride/lib/features/ride_booking/choose_ride_screen.dart#L151-L162)
  - Similar fallback when pushing next route (`_routeInfo?.distanceKm ?? 5.0`) in [ChooseRideScreen](file:///Users/alphonsus/Desktop/CaRide/caride/apps/caride/lib/features/ride_booking/choose_ride_screen.dart#L397-L433)
- Pricing config is loaded from Firestore `config/ridePricing` with silent fallback to `RidePricingConfig.defaults` when missing:
  - [ride_pricing_repository.dart](file:///Users/alphonsus/Desktop/CaRide/caride/apps/caride/lib/features/ride_booking/data/ride_pricing_repository.dart#L95-L106)
- Wallet top-up screen uses hardcoded quick amounts and min amount:
  - Quick amounts `[5000, 10000, 20000]` and min `100` in [type_amount_screen.dart](file:///Users/alphonsus/Desktop/CaRide/caride/apps/caride/lib/features/profile/type_amount_screen.dart#L146-L193)
- App Firestore config access is centralized in [app_config_repository.dart](file:///Users/alphonsus/Desktop/CaRide/caride/apps/caride/lib/core/config/app_config_repository.dart), but currently only covers `appDefaults` and `cancelRideReasons`.

### Driver app compatibility

- Driver app reads `rideType` from rides and defaults to `'Regular'` if missing:
  - [ride_model.dart](file:///Users/alphonsus/Desktop/CaRide/caride/apps/driver_app/lib/core/models/ride_model.dart#L140-L175)
- Incoming requests UI displays the ride type from ride data (driver app does not “choose ride type”).
- Therefore, maintaining stable ride type strings is the primary sync requirement:
  - `Regular`, `Comfort`, `Luxury`, `Courier`

## Decisions (Locked)

- Ride options are sourced from Firestore, but assets remain hardcoded in-app (map `rideType -> assetPath`).
- Pricing config fallback is always allowed and silent (no warning UI).
- Wallet top-up config falls back to current defaults if missing.
- No new test files and no `flutter test`; verification uses `flutter analyze` only.
- No Figma file available; skip Figma generation.

## Proposed Changes

### 1) Firestore-driven ride options (customer app)

**Firestore**

- Add doc: `config/rideOptions`
- Suggested schema:
  ```json
  {
    "options": [
      { "type": "Regular", "subtitle": "Affordable rides, all to yourself", "enabled": true, "sortOrder": 1 },
      { "type": "Comfort", "subtitle": "Faster pickup with better comfort", "enabled": true, "sortOrder": 2 },
      { "type": "Luxury", "subtitle": "Premium trip experience", "enabled": true, "sortOrder": 3 },
      { "type": "Courier", "subtitle": "Send and receive packages", "enabled": true, "sortOrder": 4 }
    ]
  }
  ```

**Code**

- Add ride options config model + repository:
  - New: `lib/features/ride_booking/data/ride_options_repository.dart`
    - `Stream<List<RideOption>> watchRideOptions()`
    - Reads `config/rideOptions`
    - Filters `enabled == true`
    - Sorts by `sortOrder` (fallback to stable ordering if missing)
    - If doc missing/invalid: fallback to current 4 defaults (same types/subtitles)
- Keep assets hardcoded via a local mapper:
  - New (or placed in same file as repository): `String rideTypeToAssetPath(String type)`
    - Regular → `lib/assets/ride_options/regular.png`
    - Comfort → `lib/assets/ride_options/comfort.png`
    - Luxury → `lib/assets/ride_options/luxury.png`
    - Courier → `lib/assets/ride_options/courier.png`
    - Unknown → default car icon (existing `_rideIcon` logic in ChooseRide can remain as fallback)
- Update RideOption model file to remove duplicated const list:
  - Update: `lib/features/ride_booking/booking_shell/models/ride_option.dart`
    - Keep `RideOption` as a plain model only
    - Remove `rideOptions` const list (the repository now provides this)
- Update BookingShell ride type step to use the repository:
  - Update: `lib/features/ride_booking/booking_shell/steps/ride_type_step.dart`
    - Replace local/hardcoded list usage with `StreamBuilder<List<RideOption>>`
    - Default selection: first option if none selected
    - Persist selection into controller as today
- Update ChooseRideScreen to use the repository:
  - Update: `lib/features/ride_booking/choose_ride_screen.dart`
    - Remove private `_RideOption` and `_rideOptions`
    - Use `StreamBuilder<List<RideOption>>` to render options
    - Keep existing styling/animations
    - Ensure selection index updates remain stable when list changes (by tracking selected `rideType` string rather than raw index)

### 2) Pricing fallbacks tightening (customer app)

- Maintain silent fallback behavior for missing pricing config:
  - `RidePricingConfig.defaults` remains the fallback.
- Reduce “magic distance” fallback usage in ChooseRide:
  - Update: `lib/features/ride_booking/choose_ride_screen.dart`
    - Replace `5.0` fallback with computed approximate distance from pickup/dropoff if route info is unavailable.
    - Implement a small pure function for haversine distance km (no new dependencies).
    - Use this approximate distance for both:
      - display pricing (`_formattedPrice`)
      - passed `priceMin/Max/Suggested` when continuing
- Improve robustness of pricing doc parsing without changing silent fallback policy:
  - Update: `lib/features/ride_booking/data/ride_pricing_repository.dart`
    - If doc exists but required maps are malformed, treat as defaults instead of mixing partial defaults per field (keep behavior silent).

### 3) Firestore-driven wallet top-up config (customer app)

**Firestore**

- Add doc: `config/walletTopUp`
- Suggested schema:
  ```json
  {
    "minAmountNaira": 100,
    "quickAmountsNaira": [5000, 10000, 20000]
  }
  ```

**Code**

- Extend central config repository:
  - Update: `lib/core/config/app_config_repository.dart`
    - Add model `WalletTopUpConfig`
    - Add `Stream<WalletTopUpConfig> watchWalletTopUpConfig()`
    - Fallback defaults: min `100`, quick `[5000, 10000, 20000]`
- Update top-up UI:
  - Update: `lib/features/profile/type_amount_screen.dart`
    - Replace hardcoded quick amounts with stream-provided values
    - Replace hardcoded `amount < 100` with stream-provided min
    - Keep same layout and formatting behavior

### 4) Driver app sync checks (no functional change expected)

- Ensure the ride option `type` values written/used by customer app remain one of:
  - `Regular`, `Comfort`, `Luxury`, `Courier`
- No driver app code change is expected for this milestone because:
  - driver app reads and displays `rideType` from ride documents and already defaults to `Regular`.

## Execution Plan (Implementation Steps)

1) Add `RideOptionsRepository` (customer) and implement Firestore doc parsing + defaults + sorting.
2) Update `RideOption` model file to remove hardcoded list.
3) Update BookingShell `RideTypeStep` to render Firestore-driven ride options and store selection.
4) Update `ChooseRideScreen` to render Firestore-driven ride options and maintain selection by `rideType`.
5) Replace hardcoded distance fallback `5.0 km` with haversine distance computation when no route info is available.
6) Add wallet top-up config model + stream in `AppConfigRepository`.
7) Update `TypeAmountScreen` to use streamed config for quick amounts and min validation.
8) Run `flutter analyze`:
   - `apps/caride`
   - `apps/driver_app` (compat check; should remain clean)
9) Fix any lint/analyzer issues found.

## Firestore Setup Notes (Manual)

- Create/seed these docs in Firestore before QA:
  - `config/rideOptions`
  - `config/walletTopUp`
- If not present, app uses fallbacks (defaults), so the app stays functional even in fresh environments.

## Verification

- Run:
  - `flutter analyze` in `apps/caride`
  - `flutter analyze` in `apps/driver_app`
- Smoke-check (manual):
  - ChooseRide screen shows ride options from Firestore ordering (or defaults if missing).
  - BookingShell Ride Type step shows the same list and assets.
  - Wallet top-up screen quick chips match Firestore config (or defaults).
  - Driver app still displays ride type correctly for incoming requests and history.

