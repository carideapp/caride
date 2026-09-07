# Ride Lifecycle Hardening (Server-Authoritative) — Design

Date: 2026-05-21  
Apps: Customer (`apps/caride`), Driver (`apps/driver_app`)  
Backend: Firebase (Firestore + Cloud Functions v2 + Firestore Rules)

## Summary

Make the ride lifecycle server-authoritative to eliminate:
- stuck ride states
- double assignment
- cancellation conflicts
- customer/driver “active ride” mismatches

All lifecycle mutations are performed by Cloud Functions with Firestore transactions and strict preconditions. Clients become read-only for lifecycle fields and only invoke callables for state transitions.

## Goals / Success Criteria

- A ride can never end up with two different drivers assigned.
- Customer and driver always see the same active ride and status progression in real-time.
- Customer cancellation is enforced consistently:
  - allowed in `requested|bidding|driverEnRoute`
  - blocked in `rideStarted`
- No screen relies on “best-effort client writes” for ride status, driver assignment, or fare finalization.
- Rules prevent direct client writes to protected lifecycle fields.

## Non-Goals

- Adding new ride statuses beyond the current set.
- Changing pricing strategy, commission logic, or wallet charging logic (except where needed to prevent lifecycle inconsistencies).
- Adding new notification flows (can be a follow-up milestone).

## Current State (Observed)

- Customer app directly writes lifecycle fields in places (e.g. accept/cancel).
  - [RideRepository.acceptBid](file:///Users/alphonsus/Desktop/CaRide/caride/apps/caride/lib/features/ride_booking/data/ride_repository.dart#L197-L227)
  - [RideRepository.cancelRide](file:///Users/alphonsus/Desktop/CaRide/caride/apps/caride/lib/features/ride_booking/data/ride_repository.dart#L253-L261)
- Driver app uses callables for lifecycle (start/complete/status updates).
  - [DriverRideRepository.updateRideStatus](file:///Users/alphonsus/Desktop/CaRide/caride/apps/driver_app/lib/features/ride/data/driver_ride_repository.dart#L123-L141)
- Backend already contains key lifecycle callables and transaction logic:
  - `respondToBid` (customer accept/reject/counter)
  - `updateRideStatus` (driver status transitions)
  - `completeRide` (driver completion + wallet/commission logic)
  - File: [functions/src/index.ts](file:///Users/alphonsus/Desktop/CaRide/caride/apps/caride/functions/src/index.ts)

## Lifecycle Model

### Statuses (existing)
- `requested` → `bidding` → `driverEnRoute` → `rideStarted` → `completed`
- Cancellation: `cancelled` (from `requested|bidding|driverEnRoute` only)

### Ownership
- Ride document `rides/{rideId}` is the single source of truth.
- Driver assignment is `rides/{rideId}.driverUid`.
- Live driver position is `driverLocations/{rideId}` (driver-owned via callable).

## Backend Design

### 1) Harden `respondToBid (accept)` as the only “accept bid” entrypoint

**Preconditions (enforced inside a Firestore transaction):**
- Ride exists.
- Caller is the ride customer (`ride.customerUid == auth.uid`).
- Ride status in `requested|bidding`.
- Ride is unassigned (`ride.driverUid` is empty/null).
- Bid exists, is still valid (status is pending, not expired).
- Driver is eligible:
  - driver approval status is `approved` (snapshot is OK)
  - driver presence indicates available: `availabilityState == online`, `isAvailableForRequests == true`, `currentRideId == null`

**Transactional writes:**
- Set ride:
  - `status = driverEnRoute`
  - `driverUid`, `driverName`
  - `finalFare`, `amountNaira`
  - `acceptedAt`, `updatedAt`
  - optionally: `acceptedBidId`
- Set accepted bid → `accepted`
- Ensure `rideMessages/{rideId}` exists and contains both participant UIDs
- Update driver presence:
  - `availabilityState = on_trip`
  - `isAvailableForRequests = false`
  - `currentRideId = rideId`
  - timestamps

**Post-transaction:**
- Mark all other bids under `bids/{rideId}/offers/*` as `rejected` (best-effort). This is not required for correctness but prevents UX confusion and reduces stale data.

### 2) Introduce `cancelRideByCustomer` callable (customer cancellation gate)

**Preconditions:**
- Caller is ride customer.
- Ride status in `requested|bidding|driverEnRoute`.
- If status is `rideStarted` → reject with `failed-precondition`.

**Transactional writes:**
- Set ride:
  - `status = cancelled`
  - `cancelledAt`, `updatedAt`, `cancellationReason`
- If ride has an assigned driver:
  - restore driver presence to online/available
  - clear `currentRideId`
- Optionally: set `cancelledBy = customer` for auditability (non-breaking additive field)

### 3) Anti-stuck reconciliation (scheduled job)

Add a scheduled function that runs periodically and reconciles:

- **Stuck bidding**
  - If ride is `bidding` for > X minutes and all bids are expired/rejected/declined → set ride back to `requested` (or cancel with reason `no_drivers` depending on product preference).
- **Stuck driverEnRoute**
  - If ride is `driverEnRoute` and `driverLocations/{rideId}.updatedAt` is older than Y minutes → cancel as system and restore driver presence.

This gives production resilience even with flaky client connectivity.

## Client App Changes

### Customer app (`apps/caride`)

- Replace direct Firestore writes for lifecycle transitions:
  - Accept bid: call `respondToBid { action: accept }` instead of `RideRepository.acceptBid` transaction write.
  - Cancel ride: call `cancelRideByCustomer` instead of `RideRepository.cancelRide` direct update.
- Add `streamActiveRide()` query to unify “active ride” resolution:
  - `status in ['requested','bidding','driverEnRoute','rideStarted']`
  - `orderBy updatedAt desc`, `limit 1`

### Driver app (`apps/driver_app`)

- Keep using existing callables `updateRideStatus` and `completeRide`.
- Add defensive UI handling for:
  - ride cancelled by customer while en route (driver should see cancellation promptly and be returned to online state)

## Firestore Rules

Update [firestore.rules](file:///Users/alphonsus/Desktop/CaRide/caride/apps/caride/firestore.rules) so:
- Clients cannot update protected lifecycle fields on `rides/{rideId}`:
  - `status`, `driverUid`, `finalFare`, `amountNaira`, `commission*`, etc.
- Allow clients to read rides they are involved in (customerUid or driverUid).
- Allow safe writes (e.g., ratings/comments) if they’re not part of lifecycle control, with explicit field allowlists.

## Error Handling / UX Implications

- If accept/cancel fails due to precondition (already accepted, already started, etc.), customer should see a clear message and auto-refresh ride stream.
- If a customer opens tracking and driver location is missing/stale, show “Waiting for driver location…” and keep map centered on pickup.

## Verification

- Unit-level: simulate function preconditions via tests (where feasible) and validate mapping logic in Dart repositories.
- Manual QA (end-to-end):
  - Two drivers bid; customer accepts one → only one driver gets assigned; other bid is rejected.
  - Customer cancels in driverEnRoute → ride becomes cancelled; driver presence resets to online.
  - Customer attempts cancel in rideStarted → backend rejects; customer UI shows “Cannot cancel after trip starts.”
  - Active ride query returns same ride in both apps, consistently.

