## Summary

Optimize the Cloud Functions bundle (compiled output at `functions/lib/index.js`, source at `functions/src/index.ts`) to reduce Gen2 region quota risk and ensure every function is deployed to an explicit, appropriate region.

Primary goals:
- Prevent “CPU quota / max instances” region quota issues during deployment and scaling.
- Make regions explicit for all functions (no implicit defaults).
- Keep the code fully functional and consistent with the existing architecture (Firebase Functions v2).

Constraints:
- Planning only in this document; implementation happens after approval.

## Current State (Repo-Audited)

### Source of truth
- `functions/lib/index.js` is compiled output (TypeScript build artifact).
- `functions/src/index.ts` is the correct place to implement changes; `npm run build` regenerates `lib/index.js`.
- Functions entrypoint is `lib/index.js` per [package.json](file:///Users/alphonsus/Desktop/CaRide/caride/apps/caride/functions/package.json#L1-L12).

### Global options (quota-relevant)
- `setGlobalOptions({ cpu: 1, memory: "256MiB", maxInstances: 20 })` is currently set globally.
  - In Gen2, `maxInstances` contributes to per-region “max CPU” quota calculations across services, which can trigger deployment failures when many functions exist.

### Region coverage gaps
Most `onCall` functions already explicitly set `region: "us-east1"`.
However these triggers currently rely on the shorthand signature and have **no explicit region**, so they deploy to the default region:
- `onDriverDocumentCreated` / `onDriverDocumentUpdated`
- `onVehicleReviewCreated` / `onVehicleReviewUpdated`
- `sendWelcomeEmailOnProfileCreate` (customers welcome email)
- `notifyDriverApprovalStatus`
- Scheduled functions (`onSchedule`) also do not specify region.
  - `reconcileStuckRides`
  - `takeWeeklyWalletSnapshot`

## Decisions (Locked)

- Region strategy: **Split (recommended)**.
  - Keep callables + Firestore triggers in **us-east1**.
  - Move scheduled jobs to **us-west1** to spread CPU quota risk.

## Proposed Changes

### A) Do not edit `lib/index.js` directly (optimize via TS source)

**Why**
- `lib/index.js` is overwritten by `npm run build` (tsc).
- Manual edits will be lost and can create source/build drift.

**Action**
- Apply all changes in `functions/src/index.ts`.
- Regenerate `functions/lib/index.js` with `npm run build`.

### B) Quota-safe defaults (global options)

**File**
- [functions/src/index.ts](file:///Users/alphonsus/Desktop/CaRide/caride/apps/caride/functions/src/index.ts)

**Change**
- Reduce global `maxInstances` and CPU so that the sum of (services × maxInstances × cpu) stays under the region quota.

**Recommended settings**
- `cpu: 0.25`
- `memory: "256MiB"`
- `maxInstances: 2`

**Reasoning**
- Example: ~30 functions × 2 instances × 0.25 vCPU = 15 vCPU total max, safely under a typical 20 vCPU regional quota.
- Lower maxInstances reduces deployment-time quota pressure and limits worst-case scaling bursts.

**Overrides (only where needed)**
- For latency-sensitive, high-traffic callables (OTP, payments, ride actions), set per-function `maxInstances: 5` (still bounded).
- For scheduled jobs: `maxInstances: 1`.

### C) Make regions explicit for all Firestore triggers (us-east1)

Convert shorthand triggers to options-object form with explicit region and (when appropriate) `maxInstances` override.

Targets:
- `onDriverDocumentCreated`
- `onDriverDocumentUpdated`
- `onVehicleReviewCreated`
- `onVehicleReviewUpdated`
- `sendWelcomeEmailOnProfileCreate`
- `notifyDriverApprovalStatus`

Pattern:
- From:
  - `onDocumentCreated("path", handler)`
- To:
  - `onDocumentCreated({ document: "path", region: "us-east1", maxInstances: 2 }, handler)`

### D) Move scheduled jobs to us-west1 (and limit instances)

Targets:
- `reconcileStuckRides`
- `takeWeeklyWalletSnapshot`

Change:
- Add `region: "us-west1"` and `maxInstances: 1` to each `onSchedule` options object.

Notes:
- Schedules are backend jobs; user-facing latency is not critical.
- Moving schedules off us-east1 reduces the chance of us-east1 quota exhaustion affecting core app flows.

### E) Region consistency helpers (no magic/default regions)

Introduce constants in `src/index.ts` for readability and correctness:
- `const REGION_PRIMARY = "us-east1";`
- `const REGION_SCHEDULE = "us-west1";`

Use them in all function declarations so region drift can’t happen accidentally.

## Verification

After implementation:
- `npm run build` in `apps/caride/functions` (ensures TypeScript compiles and `lib/index.js` matches source).
- Optional sanity scan: grep `region:` to confirm every exported function has an explicit region, except where intentionally global.

