# Ride Lifecycle Hardening (Server-Authoritative) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make ride lifecycle transitions server-authoritative to prevent stuck states, double assignment, cancellation conflicts, and customer/driver active-ride mismatches.

**Architecture:** Cloud Functions enforce all ride status/assignment transitions inside Firestore transactions with explicit preconditions. Flutter clients invoke callables and become read-only for protected lifecycle fields. A scheduled reconciliation job repairs stale/stuck rides.

**Tech Stack:** Firebase Cloud Functions v2 (TypeScript), Firestore, Firestore Rules, Flutter/Dart (customer + driver apps), `cloud_functions`, `cloud_firestore`.

---

## File Map (What changes where)

**Backend**
- Modify: [functions/src/index.ts](file:///Users/alphonsus/Desktop/CaRide/caride/apps/caride/functions/src/index.ts)
- Modify: [firestore.rules](file:///Users/alphonsus/Desktop/CaRide/caride/apps/caride/firestore.rules)

**Customer app**
- Modify: [RideRepository](file:///Users/alphonsus/Desktop/CaRide/caride/apps/caride/lib/features/ride_booking/data/ride_repository.dart)
- Modify: [SelectDriverScreen](file:///Users/alphonsus/Desktop/CaRide/caride/apps/caride/lib/features/ride_booking/select_driver_screen.dart)
- Modify: [CancelRideScreen](file:///Users/alphonsus/Desktop/CaRide/caride/apps/caride/lib/features/profile/cancel_ride_screen.dart)
- Add: `lib/core/ride/ride_lifecycle.dart` (pure helpers for status/cancel rules + tests)
- Add tests: `test/ride_lifecycle_test.dart`

**Driver app**
- Modify (small UX hardening): whichever screen shows active ride state, to handle ride cancelled while en route/start attempt.

---

## Task 1: Add shared lifecycle helpers (pure Dart + tests)

**Files:**
- Create: `apps/caride/lib/core/ride/ride_lifecycle.dart`
- Create: `apps/caride/test/ride_lifecycle_test.dart`

- [ ] **Step 1: Create lifecycle helper**

```dart
// apps/caride/lib/core/ride/ride_lifecycle.dart
const activeRideStatuses = <String>{
  'requested',
  'bidding',
  'driverEnRoute',
  'rideStarted',
};

bool isActiveRideStatus(String status) => activeRideStatuses.contains(status);

bool customerCanCancel(String status) =>
    status == 'requested' || status == 'bidding' || status == 'driverEnRoute';
```

- [ ] **Step 2: Add tests**

```dart
// apps/caride/test/ride_lifecycle_test.dart
import 'package:caride/core/ride/ride_lifecycle.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('customerCanCancel allows until started', () {
    expect(customerCanCancel('requested'), true);
    expect(customerCanCancel('bidding'), true);
    expect(customerCanCancel('driverEnRoute'), true);
    expect(customerCanCancel('rideStarted'), false);
    expect(customerCanCancel('completed'), false);
    expect(customerCanCancel('cancelled'), false);
  });

  test('isActiveRideStatus matches active set', () {
    expect(isActiveRideStatus('requested'), true);
    expect(isActiveRideStatus('rideStarted'), true);
    expect(isActiveRideStatus('completed'), false);
  });
}
```

- [ ] **Step 3: Run tests**

Run: `flutter test test/ride_lifecycle_test.dart`  
Expected: PASS

- [ ] **Step 4: Commit**

```bash
git add apps/caride/lib/core/ride/ride_lifecycle.dart apps/caride/test/ride_lifecycle_test.dart
git commit -m "test: add ride lifecycle helpers"
```

---

## Task 2: Backend — harden accept flow (respondToBid accept)

**Files:**
- Modify: `apps/caride/functions/src/index.ts`

- [ ] **Step 1: Add explicit precondition checks inside the accept transaction**

Update the `action === "accept"` branch in `respondToBid` so it enforces:
- ride.status ∈ `requested|bidding`
- ride.driverUid is empty/null
- bid.status is `pending` and not expired
- driverPresence is available (`online`, `isAvailableForRequests`, `currentRideId == null`)

Concrete sketch (adapt to existing collections already in the file):

```ts
await admin.firestore().runTransaction(async (tx) => {
  const rideSnap = await tx.get(rideRef);
  const bidSnap = await tx.get(bidRef);
  const driverPresenceRef = driverPresenceCollection.doc(bid.driverUid);
  const presenceSnap = await tx.get(driverPresenceRef);

  const ride = rideSnap.data()!;
  const bid = bidSnap.data()!;
  const presence = presenceSnap.data();

  if (!["requested", "bidding"].includes(ride.status)) {
    throw new HttpsError("failed-precondition", "Ride not accepting bids.");
  }
  if (ride.driverUid) {
    throw new HttpsError("failed-precondition", "Ride already assigned.");
  }
  if (bid.status !== "pending") {
    throw new HttpsError("failed-precondition", "Bid not pending.");
  }
  const expiresAt = bid.expiresAt?.toDate?.();
  if (expiresAt && expiresAt.getTime() < Date.now()) {
    throw new HttpsError("failed-precondition", "Bid expired.");
  }
  if (!presence || presence.availabilityState !== "online" || presence.isAvailableForRequests !== true || presence.currentRideId) {
    throw new HttpsError("failed-precondition", "Driver not available.");
  }

  tx.update(rideRef, {
    status: "driverEnRoute",
    driverUid: bid.driverUid,
    driverName: bid.driverName,
    finalFare: bid.offerNaira,
    amountNaira: bid.offerNaira,
    acceptedAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    acceptedBidId: bid.bidId ?? bidRef.id,
  });

  tx.update(bidRef, { status: "accepted", updatedAt: admin.firestore.FieldValue.serverTimestamp() });

  tx.set(admin.firestore().collection("rideMessages").doc(rideId), {
    rideId,
    participantUids: [uid, bid.driverUid],
    peerName: bid.driverName,
    lastMessage: "",
    lastMessageAt: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });

  tx.set(driverPresenceRef, {
    driverUid: bid.driverUid,
    availabilityState: "on_trip",
    isAvailableForRequests: false,
    currentRideId: rideId,
    approvalStatusSnapshot: "approved",
    lastHeartbeatAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });
});
```

- [ ] **Step 2: Post-transaction — reject all other bids (best effort)**

After the transaction, query `bids/{rideId}/offers` and batch-update any non-accepted docs to `rejected`.

```ts
const offersSnap = await admin.firestore().collection("bids").doc(rideId).collection("offers").get();
const batch = admin.firestore().batch();
for (const doc of offersSnap.docs) {
  if (doc.id === bidId) continue;
  batch.update(doc.ref, { status: "rejected", updatedAt: admin.firestore.FieldValue.serverTimestamp() });
}
await batch.commit();
```

- [ ] **Step 3: Deploy smoke test (manual)**

Run locally (or via emulator if used in repo): ensure callable still responds with `{ success: true }` and rejects precondition violations with readable error messages.

- [ ] **Step 4: Commit**

```bash
git add apps/caride/functions/src/index.ts
git commit -m "feat(functions): harden bid accept transaction"
```

---

## Task 3: Backend — add cancelRideByCustomer callable

**Files:**
- Modify: `apps/caride/functions/src/index.ts`

- [ ] **Step 1: Add callable**

Create a new callable:
- Name: `cancelRideByCustomer`
- Preconditions:
  - auth required
  - ride exists
  - `ride.customerUid == auth.uid`
  - `ride.status` ∈ `requested|bidding|driverEnRoute`
  - if `rideStarted` → throw `failed-precondition`
- Transaction:
  - set ride → `cancelled`, timestamps, reason
  - if driverUid exists → restore driverPresence to `online`, `isAvailableForRequests: true`, `currentRideId: null`

Implementation sketch:

```ts
type CancelRideByCustomerPayload = { rideId?: string; reason?: string };

export const cancelRideByCustomer = onCall({ region: "us-east1" }, async (request) => {
  if (!request.auth) throw new HttpsError("unauthenticated", "Must be signed in.");
  const uid = request.auth.uid;
  const payload = request.data as CancelRideByCustomerPayload;
  const rideId = payload.rideId?.trim();
  const reason = payload.reason?.trim();
  if (!rideId) throw new HttpsError("invalid-argument", "Missing rideId.");

  const rideRef = admin.firestore().collection("rides").doc(rideId);
  await admin.firestore().runTransaction(async (tx) => {
    const rideSnap = await tx.get(rideRef);
    if (!rideSnap.exists) throw new HttpsError("not-found", "Ride not found.");
    const ride = rideSnap.data()!;
    if (ride.customerUid !== uid) throw new HttpsError("permission-denied", "Not your ride.");
    if (!["requested", "bidding", "driverEnRoute"].includes(ride.status)) {
      throw new HttpsError("failed-precondition", "Cannot cancel after trip starts.");
    }

    tx.update(rideRef, {
      status: "cancelled",
      ...(reason ? { cancellationReason: reason } : {}),
      cancelledAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      cancelledBy: "customer",
    });

    if (ride.driverUid) {
      tx.set(driverPresenceCollection.doc(ride.driverUid), {
        availabilityState: "online",
        isAvailableForRequests: true,
        currentRideId: null,
        lastHeartbeatAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });
    }
  });

  return { success: true };
});
```

- [ ] **Step 2: Commit**

```bash
git add apps/caride/functions/src/index.ts
git commit -m "feat(functions): add cancelRideByCustomer callable"
```

---

## Task 4: Backend — scheduled reconciliation for stuck rides

**Files:**
- Modify: `apps/caride/functions/src/index.ts`

- [ ] **Step 1: Add scheduled job**

Add `onSchedule` handler (region `us-east1`) that:
- Finds rides in `bidding` older than X minutes (e.g. 10)
- For each ride:
  - checks offers subcollection for any `pending` and not expired
  - if none, set ride back to `requested` (or cancel with reason `no_drivers`)
- Finds rides in `driverEnRoute` older than Y minutes (e.g. 20) with stale `driverLocations/{rideId}.updatedAt`
  - cancel as `cancelled` with reason `driver_location_stale`
  - restore driverPresence

Implementation sketch (use small batch sizes and logs, avoid heavy scans):

```ts
export const reconcileStuckRides = onSchedule({ schedule: "every 5 minutes", region: "us-east1" }, async () => {
  const now = Date.now();
  const biddingSnap = await admin.firestore().collection("rides")
    .where("status", "==", "bidding")
    .orderBy("updatedAt", "asc")
    .limit(50)
    .get();

  for (const doc of biddingSnap.docs) {
    const ride = doc.data();
    const updatedAt = ride.updatedAt?.toDate?.()?.getTime?.() ?? 0;
    if (now - updatedAt < 10 * 60_000) continue;
    const offers = await admin.firestore().collection("bids").doc(doc.id).collection("offers").get();
    const hasLive = offers.docs.some((d) => {
      const v = d.data();
      if (v.status !== "pending") return false;
      const exp = v.expiresAt?.toDate?.()?.getTime?.() ?? 0;
      return exp > now;
    });
    if (!hasLive) {
      await doc.ref.update({ status: "requested", updatedAt: admin.firestore.FieldValue.serverTimestamp() });
    }
  }
});
```

- [ ] **Step 2: Commit**

```bash
git add apps/caride/functions/src/index.ts
git commit -m "feat(functions): reconcile stuck ride states"
```

---

## Task 5: Firestore Rules — prevent bypass writes

**Files:**
- Modify: `apps/caride/firestore.rules`

- [ ] **Step 1: Add a protected-field allowlist/denylist for rides**

Goal: block client updates to lifecycle fields like:
- `status`, `driverUid`, `driverName`, `finalFare`, `amountNaira`, `acceptedAt`, `cancelledAt`, `completedAt`, `commission*`, etc.

Implementation approach:
- Allow customers/drivers to read involved rides.
- Allow only specific update cases (e.g., ratings) by checking changed keys.

Sketch:

```rules
function changedKeys() {
  return request.resource.data.diff(resource.data).changedKeys();
}

function rideProtectedKeys() {
  return [
    "status","driverUid","driverName","finalFare","amountNaira",
    "acceptedAt","cancelledAt","completedAt","rideStartedAt",
    "commissionNaira","commissionRate","commissionPercent","driverNet",
    "acceptedBidId","cancelledBy"
  ];
}

allow update: if isSignedIn()
  && isRideParticipant(resource.data)
  && changedKeys().hasOnly(["driverRating","ratedAt","updatedAt"]);
```

Adapt to existing helper functions and the current rules structure.

- [ ] **Step 2: Commit**

```bash
git add apps/caride/firestore.rules
git commit -m "security(rules): block client writes to ride lifecycle fields"
```

---

## Task 6: Customer app — move accept/cancel to callables + unify active ride query

**Files:**
- Modify: [ride_repository.dart](file:///Users/alphonsus/Desktop/CaRide/caride/apps/caride/lib/features/ride_booking/data/ride_repository.dart)
- Modify: [select_driver_screen.dart](file:///Users/alphonsus/Desktop/CaRide/caride/apps/caride/lib/features/ride_booking/select_driver_screen.dart)
- Modify: [cancel_ride_screen.dart](file:///Users/alphonsus/Desktop/CaRide/caride/apps/caride/lib/features/profile/cancel_ride_screen.dart)

- [ ] **Step 1: Add FirebaseFunctions dependency to RideRepository**

```dart
import 'package:cloud_functions/cloud_functions.dart';

class RideRepository {
  RideRepository({FirebaseFirestore? firestore, FirebaseAuth? auth, FirebaseFunctions? functions})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance,
        _functions = functions ?? FirebaseFunctions.instanceFor(region: 'us-east1');

  final FirebaseFunctions _functions;
}
```

- [ ] **Step 2: Replace acceptBid() with callable invocation**

```dart
Future<void> acceptBid({required String rideId, required DriverBid bid}) async {
  if (_uid == null) throw Exception('Not signed in.');
  final callable = _functions.httpsCallable('respondToBid');
  await callable.call<Map<dynamic, dynamic>>({
    'rideId': rideId,
    'bidId': bid.bidId,
    'action': 'accept',
  });
}
```

- [ ] **Step 3: Replace cancelRide() with cancelRideByCustomer callable**

```dart
Future<void> cancelRide(String rideId, {String? reason}) async {
  final callable = _functions.httpsCallable('cancelRideByCustomer');
  await callable.call<Map<dynamic, dynamic>>({
    'rideId': rideId,
    if (reason != null) 'reason': reason,
  });
}
```

- [ ] **Step 4: Add streamActiveRide()**

```dart
Stream<RideModel?> streamActiveRide() {
  if (_uid == null) return Stream.value(null);
  return _ridesCol
      .where('customerUid', isEqualTo: _uid)
      .where('status', whereIn: ['requested','bidding','driverEnRoute','rideStarted'])
      .orderBy('updatedAt', descending: true)
      .limit(1)
      .snapshots()
      .map((snap) => snap.docs.isEmpty ? null : RideModel.fromDoc(snap.docs.first));
}
```

- [ ] **Step 5: Update SelectDriverScreen + CancelRideScreen callers**

No behavioral change, but now all cancels/accepts go through callables.

- [ ] **Step 6: Commit**

```bash
git add apps/caride/lib/features/ride_booking/data/ride_repository.dart \
       apps/caride/lib/features/ride_booking/select_driver_screen.dart \
       apps/caride/lib/features/profile/cancel_ride_screen.dart
git commit -m "feat(customer): make accept/cancel server-authoritative"
```

---

## Task 7: Driver app — handle cancel while en route

**Files:**
- Modify: `apps/driver_app/lib/features/home/driver_home_screen.dart` (or the screen that reacts to assigned ride)

- [ ] **Step 1: Ensure driver UI reacts to ride.status == cancelled**

When streaming assigned ride:
- if ride becomes `cancelled`, show a clear message and return to idle/online state.
- ensure no “Start ride” actions are presented.

- [ ] **Step 2: Commit**

```bash
git add apps/driver_app/lib/features/home/driver_home_screen.dart
git commit -m "feat(driver): handle ride cancelled by customer"
```

---

## Task 8: End-to-end verification checklist

- [ ] **Step 1: Customer accept → single assignment**
  - Two drivers bid.
  - Customer accepts one.
  - Expected:
    - `rides/{rideId}.driverUid` set once
    - accepted bid status = accepted
    - all other bids status = rejected
    - driver presence set to `on_trip`

- [ ] **Step 2: Customer cancel before started**
  - cancel in `requested|bidding|driverEnRoute`
  - expected ride.status = cancelled and driver presence reset if assigned

- [ ] **Step 3: Customer cancel after started**
  - attempt cancel in `rideStarted`
  - expected function returns `failed-precondition`
  - customer UI shows a clear message

- [ ] **Step 4: Active ride mismatch**
  - customer active ride stream and driver assigned ride stream show consistent rides/statuses

---

## Plan Self-Review

- Spec coverage: Tasks 2–4 implement backend authoritative lifecycle + reconciliation, Task 5 blocks bypass, Task 6 updates customer app, Task 7 updates driver UX, Task 8 verifies all “all list” cases.
- Placeholder scan: no TODO/TBD; all tasks specify concrete files/steps/snippets.
- Type consistency: uses existing statuses already present in both apps and functions (`requested`, `bidding`, `driverEnRoute`, `rideStarted`, `completed`, `cancelled`).

