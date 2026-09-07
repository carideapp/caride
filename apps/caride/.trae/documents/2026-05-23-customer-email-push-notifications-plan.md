## Summary

Implement customer-facing email + push notifications for CaRide (customer app) with brand-aligned content and full coverage for the requested lifecycle events, while keeping the system scalable and maintainable.

Scope includes:
- Cloud Functions (email templates + triggers + push sender for customers).
- Customer Flutter app (FCM token registration + notification handling + navigation on tap).

Constraints:
- Do not create any test files.
- Do not run `flutter test`.
- Use `flutter analyze` to validate the Flutter code and fix any analyzer issues.

## Current State Analysis (Repo-Audited)

### Email (Cloud Functions)
- Email is already implemented using Resend HTTP API.
  - Template wrapper: [buildEmailHtml](file:///Users/alphonsus/Desktop/CaRide/caride/apps/caride/functions/src/index.ts#L318-L341)
  - Sender: [sendResendEmail](file:///Users/alphonsus/Desktop/CaRide/caride/apps/caride/functions/src/index.ts#L343-L362)
- Existing customer emails:
  - OTP email: [sendOtpEmail](file:///Users/alphonsus/Desktop/CaRide/caride/apps/caride/functions/src/index.ts#L378-L387)
  - Welcome email (very minimal): [sendWelcomeEmail](file:///Users/alphonsus/Desktop/CaRide/caride/apps/caride/functions/src/index.ts#L408-L414)
- Customer Firestore profile is created in `verifyEmailOtp` and includes `email`, but currently has no `fcmToken` field:
  - [verifyEmailOtp provisioning](file:///Users/alphonsus/Desktop/CaRide/caride/apps/caride/functions/src/index.ts#L650-L688)

### Push (Cloud Functions)
- Only driver push exists today; it reads `drivers/{uid}.fcmToken` and sends via FCM:
  - [sendPushToDriver](file:///Users/alphonsus/Desktop/CaRide/caride/apps/caride/functions/src/index.ts#L364-L376)
- No push sender exists for customers.

### Customer App (Flutter)
- No firebase_messaging or local notifications implementation exists today (no token registration, no handlers).
- Routing supports passing a `rideId` payload to BookingShell (path `CustomerRoutePaths.rideSetPrice`):
  - [CustomerRoutePaths](file:///Users/alphonsus/Desktop/CaRide/caride/packages/navigation/lib/customer_route_paths.dart#L35-L41)
  - [BookingShellScreen extra](file:///Users/alphonsus/Desktop/CaRide/caride/apps/caride/lib/router/customer_route_factory.dart#L80-L86)
- iOS already declares background mode for remote notifications:
  - [Info.plist](file:///Users/alphonsus/Desktop/CaRide/caride/apps/caride/ios/Runner/Info.plist#L52-L56)

### Region note (required for correctness)
- Customer Cloud Functions are standardized to `us-east1` and many callables are deployed in that region.
- Customer app currently uses `FirebaseFunctions.instance` in some places (e.g. auth), which may point to the wrong default region unless it uses `instanceFor(region: ...)`.
  - [AuthRepository](file:///Users/alphonsus/Desktop/CaRide/caride/apps/caride/lib/core/auth/auth_repository.dart#L7-L15)

## Intent + Decisions (Locked)

- Email CTAs: no clickable links in emails (content must instruct users to open the app).
- Ride Completed discount code: omit (no promo system yet).
- Extra notifications beyond the required list: do not implement in this milestone; only research/propose.

## Proposed Changes

### A) Cloud Functions: customer email templates + customer push sender + triggers

**File**
- [apps/caride/functions/src/index.ts](file:///Users/alphonsus/Desktop/CaRide/caride/apps/caride/functions/src/index.ts)

#### A1) Add customer push utility
- Add `sendPushToCustomer(customerUid, title, body, data?)`:
  - Reads `customers/{uid}.fcmToken`
  - Sends via `admin.messaging().send(...)`
  - Uses a dedicated channel id for customers (e.g. `caride_customer_alerts`)
  - Uses data payload:
    - `type`: `ride_booked` | `ride_started` | `ride_completed`
    - `rideId`: Firestore ride id

#### A2) Modernize + brand-align customer email templates (no links)
Update existing templates and add new ones, all built via `buildEmailHtml(...)`:

1) **OTP code delivery**
- Update `sendOtpEmail` to include:
  - Strong security framing (“Do not share this code”)
  - Clear expiration (already available via `OTP_TTL_MINUTES`)
  - Help text (support email)

2) **Welcome email**
- Update `sendWelcomeEmail` to include:
  - Brand value proposition (fast, safe, reliable rides)
  - Key “first actions” (set pickup/dropoff, choose ride type, view wallet)
  - No links; “Open the CaRide app to book your first ride”

3) **Payment receipt summary (ride receipt)**
- Add `sendRideReceiptEmail(customerEmail, payload)` with:
  - Ride details: pickupLabel, dropoffLabel, rideType, rideId, driverName (if present), vehicleName (if present)
  - Fare: `finalFare` (or `amountNaira` fallback if missing)
  - Payment method: `wallet` or `cash`
  - Timestamp: completedAt (server timestamp)
  - “Taxes/fees” shown only if such fields exist on the ride doc; otherwise omit (avoid hardcoded tax numbers)

4) **Ride started notification**
- Add `sendRideStartedEmail(customerEmail, payload)` triggered when ride transitions to `rideStarted`.
- Include: driverName + vehicleName if present; pickup/dropoff labels; “Open the app to track your ride live.”

5) **Ride completed confirmation**
- Add `sendRideCompletedEmail(customerEmail, payload)` triggered when ride transitions to `completed`.
- Include: final fare, payment method, completedAt, and a rating prompt (“Open the CaRide app to rate your driver.”)
- Distance: compute a non-hardcoded estimate using haversine between pickup/dropoff lat/lng if available, labeled as “estimated”.

#### A3) Add triggers for the required push + emails (gap-free for requested events)

Add Firestore triggers (region `us-east1`) for customer lifecycle events:

- **Ride order confirmation push**
  - Trigger: `onDocumentCreated("rides/{rideId}")`
  - Condition: only if `status == "requested"`
  - Action: push to customer: “Ride request received”

- **Ride started email + push**
  - Trigger: `onDocumentUpdated("rides/{rideId}")`
  - Condition: `before.status != "rideStarted" && after.status == "rideStarted"`
  - Actions:
    - sendRideStartedEmail(...)
    - sendPushToCustomer(..., type=`ride_started`)

- **Ride completed email + receipt email + push**
  - Trigger: `onDocumentUpdated("rides/{rideId}")`
  - Condition: `before.status != "completed" && after.status == "completed"`
  - Actions:
    - sendRideCompletedEmail(...)
    - sendRideReceiptEmail(...)
    - sendPushToCustomer(..., type=`ride_completed`)

#### A4) Idempotency markers (avoid duplicate sends)
To avoid duplicate emails/push from retried triggers or multiple writes:
- Use a Firestore transaction against the ride doc to set a marker before sending:
  - `customerNotify.rideStartedSentAt`
  - `customerNotify.rideCompletedSentAt`
  - `customerNotify.receiptSentAt`
  - `customerNotify.rideBookedPushSentAt`
  - `customerNotify.rideStartedPushSentAt`
  - `customerNotify.rideCompletedPushSentAt`
- Only send if the marker is missing; if marker exists, return early.

#### A5) Environment requirements
- Resend remains the provider:
  - `RESEND_API_KEY`
  - `RESEND_FROM_EMAIL`
- Push requires FCM to be configured in Firebase project (already used for driver pushes).

### B) Customer App: add FCM registration + foreground notifications + navigation on tap

#### B1) Add dependencies
Update [apps/caride/pubspec.yaml](file:///Users/alphonsus/Desktop/CaRide/caride/apps/caride/pubspec.yaml) to include:
- `firebase_messaging`
- `flutter_local_notifications`

#### B2) Create a notifications module (single responsibility)
Add new files under `apps/caride/lib/core/notifications/`:
- `customer_notifications_controller.dart`
  - Initializes FirebaseMessaging permission + token retrieval.
  - Uploads token to Firestore: `customers/{uid}.fcmToken` + `fcmTokenUpdatedAt`.
  - Subscribes to token refresh to keep it updated.
  - Handles message routing and foreground display.
- `customer_notification_router.dart`
  - Pure mapping from message `data` → app route action.

#### B3) Persist token in Firestore
- Implement `upsertCustomerFcmToken(String uid, String token)`:
  - `customers/{uid}.set({ fcmToken: token, fcmTokenUpdatedAt: serverTimestamp }, merge: true)`
- Call it:
  - On auth state changes (when user signs in)
  - When `FirebaseMessaging.onTokenRefresh` emits a new token

#### B4) Foreground notification display
Because OS does not show push banners while the app is in foreground:
- Use `flutter_local_notifications` to display a local notification for `FirebaseMessaging.onMessage`.
- Create Android notification channel:
  - id: `caride_customer_alerts`
  - importance: high

#### B5) Notification tap navigation (no-dead-ends)
When user taps a push notification:
- For `type = ride_booked | ride_started`:
  - Navigate to BookingShell via `CustomerRoutePaths.rideSetPrice` and pass `extra: { "rideId": "<id>" }`
  - BookingShell already knows how to resume based on ride status.
- For `type = ride_completed`:
  - Navigate to `CustomerRoutePaths.rideHistory` (history is the stable end-state destination).

Implementation location:
- Initialize the controller in [main.dart](file:///Users/alphonsus/Desktop/CaRide/caride/apps/caride/lib/main.dart#L42-L75) after `_router` is created so it can use `_router.router` or `_router.rootNavigatorKey` for navigation.

#### B6) Align Cloud Functions region in the customer app (required for OTP + future notification callables)
Update [AuthRepository](file:///Users/alphonsus/Desktop/CaRide/caride/apps/caride/lib/core/auth/auth_repository.dart#L7-L15) to use:
- `FirebaseFunctions.instanceFor(region: AppEnv.firebaseFunctionsRegion)`
so OTP/welcome and all callables consistently reach the correct deployed region.

## Additional High-Impact Notifications (Research/Propose Only — Not Implemented)

### Email ideas
- **Driver assigned (bid accepted)**: reduces uncertainty, builds trust by surfacing driver identity early.
- **Ride cancelled** (by customer or system): closes the loop; avoids waiting.
- **Wallet top-up success**: builds financial confidence and reduces support tickets.
- **Support ticket reply**: keeps customers engaged without needing app polling.

### Push ideas
- **New bid received** (during bidding): increases conversion; gets customer to compare offers quickly.
- **Driver arriving soon**: reduces no-shows and improves pickup success.
- **Ride cancelled**: immediate clarity; prevents customers waiting.
- **Low wallet balance**: nudges top-up before booking failure.

## Assumptions

- Customer email address is stored and valid on `customers/{uid}.email` (created during OTP verification).
- Customer ride docs contain enough fields for receipts: pickup/dropoff labels, fare fields, timestamps.
- No links in emails is acceptable for compliance and product (push will handle in-app routing).

## Verification

- Customer app only:
  - Run `flutter analyze` in `apps/caride` and resolve issues.
- (Optional but recommended) Cloud Functions:
  - Run `npm run build` in `apps/caride/functions` to ensure TypeScript compiles.

