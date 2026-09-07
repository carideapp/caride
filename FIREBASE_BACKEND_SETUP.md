# CaRide Firebase Backend Setup

## 1) App Identity
- Android package id / namespace: `com.caride.app`
- Keep this same id in Firebase Android app registration.

## 2) Customer App Runtime Defines
Run customer app with secure build-time values:

```bash
flutter run -t apps/customer_app/lib/main.dart \
  --dart-define=FIREBASE_PROJECT_ID=your-project-id \
  --dart-define=FIREBASE_MESSAGING_SENDER_ID=your-sender-id \
  --dart-define=FIREBASE_STORAGE_BUCKET=your-bucket \
  --dart-define=FIREBASE_ANDROID_API_KEY=your-api-key \
  --dart-define=FIREBASE_ANDROID_APP_ID=your-android-app-id \
  --dart-define=MAPBOX_ACCESS_TOKEN=your-mapbox-token
```

## 3) Android Local Properties
Add this key to `apps/customer_app/android/local.properties`:

```properties
MAPBOX_ACCESS_TOKEN=your-mapbox-token
```

The token is injected into Android resources as `@string/mapbox_access_token`.

## 4) Cloud Functions (OTP + Welcome Email)
From repository root:

```bash
cd functions
npm install
```

Create `functions/.env` from `.env.example` with:
- `GMAIL_USER`
- `GMAIL_APP_PASSWORD`
- `OTP_FROM_EMAIL` (optional, defaults to `GMAIL_USER`)

Build:

```bash
npm run build
```

Deploy backend resources:

```bash
firebase deploy --only functions,firestore:rules,firestore:indexes,database,storage
```

## 5) Security + Production Checklist
- Firestore/RTDB/Storage rules are deny-by-default and scoped to auth identity.
- OTP uses hashed codes, expiry, and max attempt limits.
- Ride state writes should stay server-authoritative (Cloud Functions).
- Enable:
  - Cloud Logging alerts for `requestEmailOtp` and `verifyEmailOtp` failures.
  - Crashlytics in Flutter app (next increment).
  - Analytics for auth funnel, booking funnel, and chat delivery metrics.

## 6) Emulator Validation
Use local emulators before production deploy:

```bash
firebase emulators:start
```

In app run:

```bash
--dart-define=ENABLE_FIREBASE_EMULATOR=true
```

Then validate:
- Sign up OTP request and verification.
- Login OTP request and verification.
- Users profile provisioning under `users/{uid}`.
- Chat thread/message read-write access for authenticated users.
- Activity stream loads rides by `customerUid`.
