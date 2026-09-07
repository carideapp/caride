# BookingShell — Hardening + Premium Polish (Milestone)

Date: 2026-05-21  
App: Customer (`apps/caride`)  
Scope: BookingShell production hardening + premium UX polish

## Summary

Harden BookingShell into a production-grade “single booking surface” by adding lifecycle autopilot (status-driven steps + resume active rides), in-shell cancellation (callable-only + reasons), and fixed-height sheet polish (per-step heights + subtle motion + haptics).

## Goals / Success Criteria

- BookingShell automatically stays in sync with server-authoritative ride lifecycle.
- Customer can leave and re-open the app and immediately resume the active ride inside BookingShell at the correct step.
- Customer can cancel an eligible ride from inside BookingShell using callable-only cancellation and Firestore-configured reasons.
- Bottom sheet remains fixed-height (not draggable) but is tuned per step for a premium feel.
- Subtle haptics are added for key actions without becoming noisy.
- `flutter analyze` clean; `flutter test` passes.

## Non-Goals

- Adding new payment methods (wallet/card selection) beyond existing behavior.
- Adding counter-offers in bids (accept/reject remains the scope for now).
- Introducing in-app turn-by-turn navigation.

## Current State (Grounded)

- Booking flow is consolidated into BookingShell:
  - [booking_shell_screen.dart](file:///Users/alphonsus/Desktop/CaRide/caride/apps/caride/lib/features/ride_booking/booking_shell/booking_shell_screen.dart)
  - Controller: [booking_shell_controller.dart](file:///Users/alphonsus/Desktop/CaRide/caride/apps/caride/lib/features/ride_booking/booking_shell/booking_shell_controller.dart)
  - Steps: From/To, Ride Type, Fare, Bids, Tracking
- Server-authoritative ride lifecycle exists:
  - Customer accept bid via callable `respondToBid`
  - Customer cancel via callable `cancelRideByCustomer`
  - Client repo helpers: [ride_repository.dart](file:///Users/alphonsus/Desktop/CaRide/caride/apps/caride/lib/features/ride_booking/data/ride_repository.dart)
  - Shared lifecycle helpers: [ride_lifecycle.dart](file:///Users/alphonsus/Desktop/CaRide/caride/apps/caride/lib/core/ride/ride_lifecycle.dart)
- Cancel reasons are in Firestore config:
  - [app_config_repository.dart](file:///Users/alphonsus/Desktop/CaRide/caride/apps/caride/lib/core/config/app_config_repository.dart)

## Approach Options

### Option A — Autopilot Controller (Recommended)

Make `BookingShellController` lifecycle-aware:
- Owns `rideId` and `rideStream` once a ride exists
- Derives the correct BookingShell step from live `ride.status`
- Exposes `canCancel` based on lifecycle rules
- Enables a Home-level “resume active ride” redirect into BookingShell

Why:
- Keeps UI simple and resilient
- Prevents desync (UI step ≠ server status)
- Makes “resume” behavior consistent across app entry points

### Option B — UI-driven Transitions

Each step manually pushes the next step and conditionally polls ride status.

Why not:
- More fragile; easy to break when backend behavior changes
- Higher risk of stuck sheets or incorrect step transitions

## Design

### 1) Lifecycle Autopilot (Status-driven Steps)

**Rule:** once a ride exists (`rideId != null`), BookingShell no longer relies on manual step progression. It derives the UI step from the ride status stream.

Mapping:
- `requested`, `bidding` → `BookingShellStep.bids`
- `driverEnRoute`, `rideStarted` → `BookingShellStep.tracking`
- `cancelled`, `completed` → `BookingShellStep.tracking` with an “end state” layout (see below)
- Otherwise fall back to current step (defensive default)

Behavior:
- If user is still in pre-request steps (`fromTo`, `rideType`, `fare`) and presses “Request Ride”, controller sets `rideId` and immediately starts listening to `watchRide(rideId)`.
- If server updates ride status (e.g., bidding → driverEnRoute), controller updates step automatically.
- If ride is cancelled/completed, sheet displays a clear terminal state and offers an exit CTA back to Home.

### 2) Resume Active Ride on App Open

**Goal:** If customer has an active ride (`requested|bidding|driverEnRoute|rideStarted`), the app should resume directly into BookingShell at the correct step.

Implementation shape:
- Home (or customer app shell) listens to `RideRepository.streamActiveRide()`.
- If it emits a non-null ride and the current route is not already BookingShell, navigate to `CustomerRoutePaths.rideSetPrice` with `extra` containing:
  - pickup label/lat/lng
  - dropoff label/lat/lng
  - `rideId`
- BookingShell smart-start detects `rideId` and immediately enters lifecycle-driven mode.

Constraints:
- Avoid navigation loops by guarding with a local “already redirected for this rideId” flag in the Home screen.
- If Mapbox token missing, sheet still functions (map placeholder background).

### 3) In-shell Cancel Flow (Callable-only + Reasons)

**Where:** Bottom sheet secondary action button in:
- Bids step
- Tracking step

**When:** Visible only if `customerCanCancel(ride.status)` is true.

Flow:
- Tap “Cancel Ride” → open reason selector (existing cancel reasons stream).
- Confirm → call `RideRepository.cancelRide(rideId, reason: selected)` (callable-only).
- On success, lifecycle stream transitions to `cancelled`; terminal state UI shows:
  - Title: “Ride cancelled”
  - Subtext: summary
  - CTA: “Back to Home”

Error handling:
- If callable returns precondition failure (already started), show a readable snackbar and refresh UI (status stream will converge).

### 4) Fixed-height Sheet Polish (Per-step Heights)

Keep fixed-height design (no draggable), but tune height by step:
- `fromTo`: tallest (search + lists)
- `rideType`: medium
- `fare`: shorter
- `bids`: tall
- `tracking`: medium

Implementation:
- Define `double sheetHeightForStep(BookingShellStep step)` on the screen or a small helper file.
- Apply height in the sheet container.

### 5) Subtle Motion + Haptics

Motion:
- Keep `AnimatedSwitcher` for step content.
- Optionally animate height changes per step only if it remains smooth (no layout thrash).

Haptics (subtle):
- Step changes: `SelectionClick` (or equivalent)
- Request ride / accept bid / cancel confirm: light impact

## Testing / Verification

- Unit tests:
  - step derivation from status
  - resume payload parsing (extra map) + rideId handling
  - cancel visibility logic via `customerCanCancel`
- Integration sanity:
  - `flutter analyze`
  - `flutter test`
  - manual: create ride → bids → accept → tracking; background/foreground app; verify resume; cancel before started.

