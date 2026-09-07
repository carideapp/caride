# Production migration: `users` → `customers` (Firestore)

Rider profiles and wallet-related data moved from the **`users`** collection **`customers`**. Cloud Functions, security rules, and client apps expect **`customers/{uid}`** (with subcollections such as **`savedCards`**, **`savedAddresses`**, **`paymentMethods`**).

## When to run

Run this **once**, in the same release window as deploying updated rules, functions, and apps. Avoid a long period where some traffic still writes to **`users`** while new code reads **`customers`**.

## What to copy

For each document **`users/{uid}`**:

1. Copy the top-level document to **`customers/{uid}`** with the same fields.
2. Copy subcollections recursively (at minimum **`savedCards`** and any other subcollections you used under **`users`**, e.g. **`savedAddresses`**, **`paymentMethods`**).

Document IDs under the target collection must stay the **same** as Firebase Auth UIDs.

## Options

### A. Firebase Console / Export

Use [Firestore export to Cloud Storage](https://firebase.google.com/docs/firestore/manage-data/export-import), then restore or transform into **`customers`**, or use a one-off script in a trusted environment.

### B. Admin SDK script (example outline)

Run with a service account that has read/write access:

```javascript
const admin = require('firebase-admin');
admin.initializeApp();
const db = admin.firestore();

async function migrateUser(uid) {
  const src = db.collection('users').doc(uid);
  const dest = db.collection('customers').doc(uid);
  const snap = await src.get();
  if (!snap.exists) return;
  await dest.set(snap.data() ?? {}, { merge: false });
  // Copy subcollections in batches as needed (savedCards, etc.).
}

async function migrateAll() {
  const snap = await db.collection('users').get();
  for (const doc of snap.docs) {
    await migrateUser(doc.id);
  }
}
```

Adapt batching, error handling, and subcollection iteration for your data size.

## After migration

- Smoke-test: signup, wallet top-up, and ride completion for a rider.
- Optionally keep **`users`** read-only rules temporarily for rollback; remove once **`customers`** is verified stable.

## Welcome email trigger

`sendWelcomeEmailOnProfileCreate` fires on **`customers/{uid}`** creation only. Existing **`users`** documents will not re-trigger the welcome email unless you recreate those profiles under **`customers`**.
