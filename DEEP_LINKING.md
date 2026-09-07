# CaRide Deep Linking — Architecture & Setup Guide

## URL Structure

| URL | Purpose |
|-----|---------|
| https://www.caride.ng/app/referral/{code} | Referral invitation link |
| https://www.caride.ng/app/trip/{code} | Shared trip monitor link |
| caride://app/referral/{code} | Custom scheme fallback |
| caride://app/trip/{code} | Custom scheme fallback |

## How It Works

### App Installed (Android App Links / iOS Universal Links)
1. User taps the link → OS intercepts it directly → CaRide app opens
2. DeepLinkService.init() receives the URI and parses type + code
3. Code is stored in SharedPreferences with a timestamp (48h referral / 24h trip)
4. The app navigates the user to the appropriate screen:
   - **Referral**: code is auto-applied on SignupScreen
   - **Trip**: code is auto-submitted on MonitorTripEntryScreen

### App Not Installed (Fallback Page)
1. User taps the link → browser opens www.caride.ng/app/{type}/{code}
2. AppDeepLinkPage is rendered (React/Vercel)
3. Page detects device (Android/iOS/Desktop)
4. Attempts to open custom scheme caride://app/{type}/{code} (silent, non-blocking)
5. After 2.5 seconds, redirects to Play Store or App Store

### Deferred Deep Linking (Android only)
After a fresh install from the Play Store:
- The referral code is embedded in the Play Store URL as &referrer=utm_source%3Dcaride%26utm_content%3Dreferral_CODE
- The landing page (AppDeepLinkPage) builds this UTM referrer for the Play Store redirect

## Files Changed

### Flutter App (pps/caride/)
- lib/core/services/deep_link_service.dart — Complete rewrite
- lib/features/profile/monitor_trip_entry_screen.dart — Auto-detect pending trip
- lib/features/profile/share_trip_sheet.dart — Add Share Link button

### Admin Dashboard / www.caride.ng (pps/admin_dashboard/)
- ercel.json — Protect .well-known/ from SPA catch-all rewrite
- public/.well-known/assetlinks.json — Correct SHA256 fingerprint
- public/.well-known/apple-app-site-association — Real Team ID + Bundle ID
- src/pages/AppDeepLinkPage.tsx — Branded smart-redirect landing page
- src/App.tsx — Register /app/* routes

### Website (website/)
- public/.well-known/assetlinks.json — Same SHA256 update
- public/.well-known/apple-app-site-association — Same AASA update

## Key Configuration Values

| Setting | Value |
|---------|-------|
| Android Package | com.caride.app |
| Android SHA256 | D3:E6:D3:5C:20:2C:28:E6:6F:42:81:09:4C:8E:1C:7E:D7:1E:38:B2:10:E2:08:D3:56:90:09:2C:6A:42:8B:0A |
| iOS Bundle ID | com.caride.customer.customerApp |
| iOS Team ID | 7J4WCXH9Z4 |
| Deep-link domain | www.caride.ng |

## Testing

### Android App Links
`
adb shell am start -W \
  -a android.intent.action.VIEW \
  -d "https://www.caride.ng/app/referral/TEST123" \
  com.caride.app
`

### Verify assetlinks.json
`
curl -I https://www.caride.ng/.well-known/assetlinks.json
# Must return: Content-Type: application/json
`

### Verify AASA
`
curl -I https://www.caride.ng/.well-known/apple-app-site-association
# Must return: Content-Type: application/json
`

### Google's Verification Tool
Visit: https://digitalassetlinks.googleapis.com/v1/statements:list?source.web.site=https://www.caride.ng&relation=delegate_permission/common.handle_all_urls

## Expiry Policy
- Referral codes: expire 48 hours after receipt
- Trip codes: expire 24 hours after receipt
- Processed codes: remembered for idempotency (capped at 50 entries)
