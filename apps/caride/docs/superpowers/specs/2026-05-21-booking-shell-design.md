# BookingShell (Premium, Minimal) — Design

Date: 2026-05-21  
App: Customer (`apps/caride`)  
Goal scope: Booking flow (Home → Choose Ride → Offer Fare → Select Driver → Track) consolidated into one screen

## Summary

Create a single **BookingShell** screen: a full-screen Mapbox map with a bottom sheet that animates between booking steps. This replaces multi-screen navigation for the booking flow while keeping existing backend/repositories and the existing `design_system` UI foundation. Motion is subtle (premium feel) with minimal visual noise.

## Goals / Success Criteria

- Booking flow is completed end-to-end inside a single screen (sheet step transitions).
- Premium + minimal UI:
  - no heavy shadows
  - subtle gradients only on primary CTAs
  - clean information hierarchy
- Uses existing `design_system` (AppCard, PrimaryButton, etc.).
- Uses existing Mapbox and route overlay work (pins + polyline) with no regressions.
- Works with server-authoritative lifecycle:
  - accept bid via callable
  - cancel via callable
- Handles missing Mapbox token with graceful fallback (placeholder background + functional sheet).

## Non-Goals

- Redesign of profile or wallet flows.
- Turn-by-turn in-app navigation (external maps remain preferred).
- Large design-system rewrite.

## Current State (Grounded)

Booking is distributed across multiple screens and navigation steps:
- Home map and destination selection: [customer_home_screen.dart](file:///Users/alphonsus/Desktop/CaRide/caride/apps/caride/lib/features/home_map/customer_home_screen.dart)
- Ride option + map placeholder → now MapWidget + route overlay: [choose_ride_screen.dart](file:///Users/alphonsus/Desktop/CaRide/caride/apps/caride/lib/features/ride_booking/choose_ride_screen.dart)
- Fare offering: [offer_fare_screen.dart](file:///Users/alphonsus/Desktop/CaRide/caride/apps/caride/lib/features/ride_booking/offer_fare_screen.dart)
- Driver bids: [select_driver_screen.dart](file:///Users/alphonsus/Desktop/CaRide/caride/apps/caride/lib/features/ride_booking/select_driver_screen.dart)
- Tracking: [driver_tracking_screen.dart](file:///Users/alphonsus/Desktop/CaRide/caride/apps/caride/lib/features/profile/driver_tracking_screen.dart)

Already implemented building blocks:
- Route overlay (pins + polyline + camera fit): [mapbox_route_overlay.dart](file:///Users/alphonsus/Desktop/CaRide/caride/apps/caride/lib/core/maps/mapbox_route_overlay.dart)
- Directions route geometry fetch: [ride_pricing_repository.dart](file:///Users/alphonsus/Desktop/CaRide/caride/apps/caride/lib/features/ride_booking/data/ride_pricing_repository.dart)
- Server-authoritative accept/cancel: [ride_repository.dart](file:///Users/alphonsus/Desktop/CaRide/caride/apps/caride/lib/features/ride_booking/data/ride_repository.dart)

## UX Structure

### Single Screen: `BookingShellScreen`

**Layout**
- Background: Mapbox `MapWidget` if token exists; else `map_placeholder.jpeg`.
- Top bar:
  - Back/Close (returns to home)
  - Recenter button (fits route or driver depending on step)
- Bottom sheet:
  - Rounded top corners, minimal surface
  - Step indicator (dots or small segmented progress)
  - Step content swaps with `AnimatedSwitcher` (fade + slide) for premium motion

### Steps (bottom sheet)

1) **From / To**
   - Search + Recent + Saved
   - Sets `fromPlace` and `toPlace`
   - As selections change: pins update; once both exist, route line draws + camera fits.

2) **Ride Type**
   - Regular / Comfort / Luxury / Courier selection
   - Shows route summary (distance, duration)

3) **Fare**
   - Suggest a fare (based on pricing config + route metrics)
   - Allow customer offer input
   - CTA: “Request Ride”

4) **Driver Bids**
   - Streams bids for the created rideId
   - Accept / Counter / Reject
   - CTA: Accept triggers server callable

5) **Tracking**
   - Embed/Reuse existing tracking UI behavior:
     - show driver name/phone/chat
     - show moving car icon + pins
   - If ride completes/cancels, show an exit CTA.

## State Management

### `BookingShellController` (ChangeNotifier)

Responsibilities:
- Holds booking step + selections + computed route + ride lifecycle state.
- Orchestrates calls to repositories and caches results to avoid flicker.

Key state:
- `step` (enum: fromTo, rideType, fare, bids, tracking)
- `fromPlace`, `toPlace`
- `routeLine` (`List<Position>?`)
- `routeInfo` (distance/duration)
- `pricingConfig`
- `selectedRideType`
- `customerOffer`
- `rideId`
- live streams:
  - ride doc stream (`watchRide`)
  - bids stream (`watchBids`)
  - driver location stream (only in tracking)

## Data Flow / Backend Integration

- `From/To`:
  - Use existing MapboxSearchService + recent/saved sources.
- Route line:
  - `RidePricingRepository.getRouteLine` (geojson)
  - `MapboxRouteOverlay` draws polyline + pins + camera fit.
- Price estimation:
  - reuse existing pricing logic/config and routeInfo where available.
- Ride request:
  - `RideRepository.createRideRequest(...)` → sets `rideId`
- Bids:
  - `RideRepository.watchBids(rideId)` → list
  - accept:
    - `RideRepository.acceptBid(...)` → callable `respondToBid accept`
  - counter/reject:
    - keep existing behavior (ensure it remains allowed by rules; adjust if needed)
- Tracking:
  - `RideRepository.watchRide(rideId)` drives status changes
  - `DriverLocationRepository.watchRideDriverLocation(rideId)` drives map car position

## Error Handling

- Missing Mapbox token: fallback placeholder image; sheet remains fully functional.
- Route fetch failure: show pins only + non-blocking banner (“Route unavailable”).
- Accept/cancel precondition errors (already assigned, already started):
  - surface a readable snackbar + refresh streams.
- Network disconnect:
  - keep last-known UI state and show “Reconnecting…” in bids/tracking steps.

## Implementation Notes (Design Constraints)

- Use existing `design_system` components for all cards/buttons.
- Keep the screen responsive without requiring ScreenUtil.
- Avoid heavy shadows; prefer spacing and typography.
- Subtle motion only:
  - `AnimatedSwitcher` for step changes
  - small progress indicator animation

## Acceptance Checklist

- User can complete: From/To → Ride Type → Fare → Request → Accept bid → Track driver, all inside BookingShell.
- Route polyline visible in From/To + Ride Type + Fare steps and matches currently selected places.
- Accept/cancel uses callables and never writes lifecycle fields directly.
- No analyzer issues in customer app after migration.

