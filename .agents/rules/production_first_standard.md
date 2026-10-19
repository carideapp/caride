# Rule: Production-First Implementation Standard

## Non-Negotiable Invariants:
1. **Always Implement for Full Production, Never for Testing/Mocks**:
   - Every feature request must be built as a full production-ready solution from the very beginning.
   - Never implement client-only mock fallbacks, synthetic generators, or demo shortcuts when a real backend system is expected.

2. **End-to-End Payment & Gateway Workflows**:
   - For all payment gateway integrations (TransactPay, etc.):
     - Implement the real API endpoints on the backend/proxy.
     - Build the **live HTTP Webhook handler** to process asynchronous events (e.g. real-money bank transfer deposits, credit notifications) with cryptographic signature validation.
     - Implement atomic database transactions (e.g., Firestore `FieldValue.increment`, idempotency receipt check, wallet transaction ledger record, email receipt).
   - Ensure the server-side Cloud Function is written, exported, and ready to deploy (`firebase deploy --only functions`).

3. **Zero Placeholder Fallbacks**:
   - If an integration requires backend provisioning, build the Cloud Function and proxy routes directly instead of returning a simulated local response.
