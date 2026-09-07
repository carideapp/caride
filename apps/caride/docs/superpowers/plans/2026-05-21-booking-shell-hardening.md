# BookingShell Hardening + Premium Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make BookingShell production-ready by adding lifecycle autopilot (status-driven steps + resume active ride), in-shell cancel flow (callable-only + reasons), and fixed-height sheet polish (per-step heights + subtle motion + haptics).

**Architecture:** Extend `BookingShellController` to become lifecycle-aware once a ride exists (`rideId != null`): it owns a ride stream subscription, derives UI step from `ride.status`, and exposes cancellation eligibility. Home auto-resumes active rides by pushing BookingShell with `rideId` + pickup/dropoff payload. UI polish stays contained to BookingShell files.

**Tech Stack:** Flutter/Dart, Firestore streams, callable Cloud Functions via `RideRepository`, existing `design_system`, `HapticFeedback`, Mapbox.

---

## File Structure (to be created/modified)

**Create**
- `lib/features/ride_booking/booking_shell/widgets/cancel_ride_bottom_sheet.dart` — reasons list + confirm; callable-only cancel
- `lib/features/ride_booking/booking_shell/widgets/booking_end_state.dart` — cancelled/completed terminal panel + back CTA
- `test/booking_shell_autopilot_test.dart` — step derivation + cancel eligibility tests
- `test/booking_shell_resume_payload_test.dart` — controller parsing of `extra` payload with `rideId`

**Modify**
- `lib/features/ride_booking/booking_shell/booking_shell_controller.dart` — rideId parsing, ride stream subscription, status→step mapping, `canCancel`, and helpers
- `lib/features/ride_booking/booking_shell/booking_shell_screen.dart` — per-step heights; haptics; tracking follow gesture disables; cancel button injection
- `lib/features/ride_booking/booking_shell/steps/driver_bids_step.dart` — show Cancel Ride button when eligible
- `lib/features/ride_booking/booking_shell/steps/tracking_step.dart` — show end state UI; show Cancel Ride button when eligible
- `lib/features/home_map/customer_home_screen.dart` — auto-resume active ride into BookingShell with guard

---

## Task 1: Autopilot step derivation + cancel eligibility helpers

**Files:**
- Modify: `lib/features/ride_booking/booking_shell/booking_shell_controller.dart`
- Test: `test/booking_shell_autopilot_test.dart`

- [ ] **Step 1: Add failing tests for status→step mapping + cancel eligibility**

Create `test/booking_shell_autopilot_test.dart`:

```dart
import 'package:caride/core/ride/ride_lifecycle.dart';
import 'package:caride/features/ride_booking/booking_shell/booking_shell_controller.dart';
import 'package:caride/features/ride_booking/booking_shell/models/booking_shell_step.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('status->step mapping: bidding goes to bids', () {
    expect(
      BookingShellController.stepForRideStatus('bidding'),
      BookingShellStep.bids,
    );
  });

  test('status->step mapping: driverEnRoute goes to tracking', () {
    expect(
      BookingShellController.stepForRideStatus('driverEnRoute'),
      BookingShellStep.tracking,
    );
  });

  test('cancel eligibility mirrors lifecycle helper', () {
    for (final s in activeRideStatuses) {
      expect(
        BookingShellController.customerCanCancelStatus(s),
        customerCanCancel(s),
      );
    }
  });
}
```

- [ ] **Step 2: Run tests (expect FAIL: missing static helpers)**

Run:
```bash
flutter test test/booking_shell_autopilot_test.dart
```
Expected: FAIL with missing `stepForRideStatus` / `customerCanCancelStatus`.

- [ ] **Step 3: Implement static helpers in BookingShellController**

In `booking_shell_controller.dart`, add:

```dart
static BookingShellStep stepForRideStatus(String status) {
  return switch (status) {
    'requested' || 'bidding' => BookingShellStep.bids,
    'driverEnRoute' || 'rideStarted' => BookingShellStep.tracking,
    'cancelled' || 'completed' => BookingShellStep.tracking,
    _ => BookingShellStep.fromTo,
  };
}

static bool customerCanCancelStatus(String status) {
  return customerCanCancel(status);
}
```

- [ ] **Step 4: Run tests (expect PASS)**

Run:
```bash
flutter test test/booking_shell_autopilot_test.dart
```
Expected: PASS.

---

## Task 2: Controller rideId parsing + ride stream autopilot

**Files:**
- Modify: `lib/features/ride_booking/booking_shell/booking_shell_controller.dart`
- Test: `test/booking_shell_resume_payload_test.dart`

- [ ] **Step 1: Add failing test for parsing `rideId` from `extra`**

Create `test/booking_shell_resume_payload_test.dart`:

```dart
import 'package:caride/features/ride_booking/booking_shell/booking_shell_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('controller reads rideId from extra', () {
    final c = BookingShellController.forTest(
      extra: {
        'rideId': 'ride_123',
        'pickupLabel': 'A',
        'pickupLat': 1.0,
        'pickupLng': 2.0,
        'dropoffLabel': 'B',
        'dropoffLat': 3.0,
        'dropoffLng': 4.0,
      },
    );
    expect(c.rideId, 'ride_123');
  });
}
```

- [ ] **Step 2: Run the test (expect FAIL until controller stores rideId)**

Run:
```bash
flutter test test/booking_shell_resume_payload_test.dart
```
Expected: FAIL (rideId is null).

- [ ] **Step 3: Store `rideId` when present in extra**

In `_initFromExtra`, add:

```dart
final rid = extra['rideId'];
if (rid is String && rid.trim().isNotEmpty) {
  _rideId = rid.trim();
}
```

- [ ] **Step 4: Add ride stream subscription to auto-advance steps**

Add fields:

```dart
StreamSubscription<RideModel?>? _rideSub;
RideModel? _ride;
RideModel? get ride => _ride;
bool get hasRide => _rideId != null;
```

Add method:

```dart
void attachRideStreamIfPossible() {
  final repo = _rideRepository;
  final id = _rideId;
  if (repo == null || id == null) return;
  _rideStream ??= repo.watchRide(id);
  _bidsStream ??= repo.watchBids(id);

  _rideSub ??= _rideStream!.listen((r) {
    if (r == null) return;
    _ride = r;
    final next = stepForRideStatus(r.status);
    if (_step != next) {
      _step = next;
    }
    notifyListeners();
  });
}
```

Call `attachRideStreamIfPossible()`:
- after setting `_rideId` in `_initFromExtra`
- after `requestRide()` sets `_rideId`

- [ ] **Step 5: Ensure controller disposes the subscription**

In `dispose()`:

```dart
_rideSub?.cancel();
```

- [ ] **Step 6: Run tests (expect PASS)**

Run:
```bash
flutter test test/booking_shell_resume_payload_test.dart
```
Expected: PASS.

---

## Task 3: In-shell cancel bottom sheet (reasons + confirm)

**Files:**
- Create: `lib/features/ride_booking/booking_shell/widgets/cancel_ride_bottom_sheet.dart`
- Modify: `lib/features/ride_booking/booking_shell/steps/driver_bids_step.dart`
- Modify: `lib/features/ride_booking/booking_shell/steps/tracking_step.dart`

- [ ] **Step 1: Create CancelRideBottomSheet widget**

Create `lib/features/ride_booking/booking_shell/widgets/cancel_ride_bottom_sheet.dart`:

```dart
import 'package:caride/core/config/app_config_repository.dart';
import 'package:caride/features/ride_booking/booking_shell/booking_shell_controller.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:shared_widgets/shared_widgets.dart';

class CancelRideBottomSheet extends StatefulWidget {
  const CancelRideBottomSheet({super.key, required this.controller});

  final BookingShellController controller;

  static Future<void> show(
    BuildContext context, {
    required BookingShellController controller,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CancelRideBottomSheet(controller: controller),
    );
  }

  @override
  State<CancelRideBottomSheet> createState() => _CancelRideBottomSheetState();
}

class _CancelRideBottomSheetState extends State<CancelRideBottomSheet> {
  final AppConfigRepository _config = AppConfigRepository();
  String? _reason;
  bool _submitting = false;

  Future<void> _confirm() async {
    final rideId = widget.controller.rideId;
    final reason = _reason;
    if (rideId == null || reason == null) return;
    setState(() => _submitting = true);
    try {
      await widget.controller.cancelRide(reason: reason);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to cancel: ${e.toString()}')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.md,
          right: AppSpacing.md,
          bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.md,
        ),
        child: AppCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: StreamBuilder<List<String>>(
            stream: _config.watchCancelRideReasons(),
            builder: (context, snap) {
              final reasons = snap.data ?? const [];
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Cancel ride', style: theme.textTheme.titleLarge),
                  const SizedBox(height: AppSpacing.sm),
                  Text('Why are you cancelling?', style: theme.textTheme.bodyMedium),
                  const SizedBox(height: AppSpacing.md),
                  if (reasons.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
                      child: Text('No cancellation reasons configured.'),
                    )
                  else
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 320),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: reasons.length,
                        separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.sm),
                        itemBuilder: (context, i) {
                          final r = reasons[i];
                          final selected = _reason == r;
                          return NeumorphicContainer(
                            onTap: () => setState(() => _reason = r),
                            radius: AppRadius.md,
                            padding: const EdgeInsets.all(AppSpacing.sm),
                            child: Row(
                              children: [
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: AppColors.primaryGreen,
                                      width: 2,
                                    ),
                                  ),
                                  child: selected
                                      ? Center(
                                          child: Container(
                                            width: 12,
                                            height: 12,
                                            decoration: const BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: AppColors.primaryGreen,
                                            ),
                                          ),
                                        )
                                      : null,
                                ),
                                const SizedBox(width: AppSpacing.md),
                                Expanded(child: Text(r, style: theme.textTheme.titleMedium)),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: AppSpacing.md),
                  PrimaryButton(
                    label: _submitting ? 'Cancelling...' : 'Confirm cancellation',
                    onPressed: (_reason == null || _submitting) ? null : _confirm,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Add Cancel Ride button into DriverBidsStep**

In `driver_bids_step.dart`, below the list, add a bottom-aligned secondary button:

```dart
final canCancel = controller.ride?.status != null &&
    BookingShellController.customerCanCancelStatus(controller.ride!.status);
...
if (canCancel) ...[
  const SizedBox(height: AppSpacing.sm),
  SecondaryButton(
    label: 'Cancel Ride',
    onPressed: () => CancelRideBottomSheet.show(context, controller: controller),
  ),
]
```

Add import:

```dart
import 'package:caride/features/ride_booking/booking_shell/widgets/cancel_ride_bottom_sheet.dart';
```

- [ ] **Step 3: Add Cancel Ride button into TrackingStep**

Same visibility logic (only if cancelable) and same bottom sheet.

---

## Task 4: Tracking terminal end states (cancelled/completed)

**Files:**
- Create: `lib/features/ride_booking/booking_shell/widgets/booking_end_state.dart`
- Modify: `lib/features/ride_booking/booking_shell/steps/tracking_step.dart`

- [ ] **Step 1: Add BookingEndState widget**

Create `lib/features/ride_booking/booking_shell/widgets/booking_end_state.dart`:

```dart
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:navigation/navigation.dart';

class BookingEndState extends StatelessWidget {
  const BookingEndState({
    super.key,
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.titleLarge),
        const SizedBox(height: AppSpacing.sm),
        Text(subtitle, style: theme.textTheme.bodyMedium),
        const Spacer(),
        PrimaryButton(
          label: 'Back to Home',
          onPressed: () => context.go(CustomerRoutePaths.home),
        ),
      ],
    );
  }
}
```

- [ ] **Step 2: Render end state for cancelled/completed inside TrackingStep**

At the top of `TrackingStep` after `ride` is available:

```dart
if (ride.status == 'cancelled') {
  return const BookingEndState(
    title: 'Ride cancelled',
    subtitle: 'This trip has been cancelled.',
  );
}
if (ride.status == 'completed') {
  return const BookingEndState(
    title: 'Trip completed',
    subtitle: 'Thanks for riding with CaRide.',
  );
}
```

Add import:

```dart
import 'package:caride/features/ride_booking/booking_shell/widgets/booking_end_state.dart';
```

---

## Task 5: Per-step fixed sheet heights + haptics

**Files:**
- Modify: `lib/features/ride_booking/booking_shell/booking_shell_screen.dart`

- [ ] **Step 1: Add height mapping helper**

In `_BookingShellScreenState`, add:

```dart
double _sheetHeightForStep(BookingShellStep step) {
  return switch (step) {
    BookingShellStep.fromTo => 460,
    BookingShellStep.rideType => 420,
    BookingShellStep.fare => 360,
    BookingShellStep.bids => 460,
    BookingShellStep.tracking => 420,
  };
}
```

Replace:

```dart
height: 340,
```

With:

```dart
height: _sheetHeightForStep(_c.step),
```

- [ ] **Step 2: Add selection haptics on step changes**

In controller step changes (`goTo`, autopilot step changes), keep logic-only; trigger haptics in the screen by detecting step changes:
- store `_lastStep` in state
- when `_c.step` changes, call:

```dart
HapticFeedback.selectionClick();
```

- [ ] **Step 3: Add light impact haptics on request/accept/cancel**

Add `HapticFeedback.lightImpact()`:
- after Request Ride success (in `FareStep` right after `await controller.requestRide`)
- after Accept bid tap (in `DriverBidsStep` before/after calling controller)
- after Cancel confirm (in cancel bottom sheet after confirm success)

---

## Task 6: Resume active ride from Home into BookingShell

**Files:**
- Modify: `lib/features/home_map/customer_home_screen.dart`

- [ ] **Step 1: Add a ride repo + subscription with guard**

Add fields:

```dart
final RideRepository _rideRepository = RideRepository();
StreamSubscription? _activeRideSub;
String? _redirectedRideId;
```

In `dispose()` cancel subscription:

```dart
_activeRideSub?.cancel();
```

In `initState()` after other init logic:

```dart
_activeRideSub = _rideRepository.streamActiveRide().listen((ride) {
  if (!mounted) return;
  if (ride == null) return;
  if (_redirectedRideId == ride.id) return;
  _redirectedRideId = ride.id;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!mounted) return;
    context.push(
      CustomerRoutePaths.rideSetPrice,
      extra: {
        'rideId': ride.id,
        'pickupLabel': ride.pickupLabel,
        'pickupLat': ride.pickupLat,
        'pickupLng': ride.pickupLng,
        'dropoffLabel': ride.dropoffLabel,
        'dropoffLat': ride.dropoffLat,
        'dropoffLng': ride.dropoffLng,
      },
    );
  });
});
```

Make sure imports exist:

```dart
import 'dart:async';
import 'package:caride/features/ride_booking/data/ride_repository.dart';
import 'package:navigation/navigation.dart';
```

- [ ] **Step 2: Run analyzer**

Run:
```bash
flutter analyze
```
Expected: clean.

---

## Task 7: Full verification

- [ ] **Step 1: Run all tests**

Run:
```bash
flutter test
```
Expected: PASS.

- [ ] **Step 2: Manual smoke (local)**

Run:
```bash
flutter run
```
Check:
- Create a ride in BookingShell → returns to app → immediately resumes into BookingShell.
- Cancel from Bids/Tracking only when allowed; end state shows Back to Home.
- Step changes feel stable and the sheet height matches the step content.

