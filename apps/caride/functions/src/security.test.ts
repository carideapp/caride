import {
  determineNextLockoutStage,
  durationToMilliseconds,
  sanitizeIp,
  isIpAllowlisted,
  DEFAULT_SECURITY_POLICY,
  AccountLockoutPolicy,
} from "./security";

function assert(condition: boolean, message: string) {
  if (!condition) {
    throw new Error(`Assertion failed: ${message}`);
  }
}

console.log("=== RUNNING SECURITY CENTER UNIT TESTS ===");

// ─── Test 1: Duration to Milliseconds ──────────────────────────────────────────
assert(durationToMilliseconds(5, "minutes") === 5 * 60 * 1000, "5 minutes in ms");
assert(durationToMilliseconds(24, "hours") === 24 * 60 * 60 * 1000, "24 hours in ms");
assert(durationToMilliseconds(7, "days") === 7 * 24 * 60 * 60 * 1000, "7 days in ms");
assert(durationToMilliseconds(30, "seconds") === 30 * 1000, "30 seconds in ms");
assert(durationToMilliseconds(0, "hours") === 0, "0 hours is 0 ms");
console.log("✓ Test 1: Duration conversion passed");

// ─── Test 2: IP Sanitization and Normalization ────────────────────────────────
assert(sanitizeIp(" 192.168.1.1 ") === "192.168.1.1", "Trim whitespace");
assert(sanitizeIp("::ffff:10.0.0.1") === "10.0.0.1", "Remove IPv6 mapped prefix");
assert(sanitizeIp("197.210.45.1, 10.0.0.2") === "197.210.45.1", "Extract first x-forwarded-for IP");
assert(sanitizeIp(null) === "127.0.0.1", "Null fallback");
console.log("✓ Test 2: IP sanitization passed");

// ─── Test 3: IP Allowlist Matching ────────────────────────────────────────────
const allowlist = ["192.168.1.50", "10.0.*", "172.16.0.1"];
assert(isIpAllowlisted("192.168.1.50", allowlist) === true, "Exact IP allowlisted");
assert(isIpAllowlisted("10.0.4.99", allowlist) === true, "Wildcard allowlisted");
assert(isIpAllowlisted("192.168.1.51", allowlist) === false, "Disallowed IP rejected");
assert(isIpAllowlisted("127.0.0.1", allowlist) === true, "Localhost always allowlisted");
console.log("✓ Test 3: IP allowlist matching passed");

// ─── Test 4: Progressive Lockout Stage Progression ────────────────────────────
const policy = DEFAULT_SECURITY_POLICY.accountLockout;

// Attempt 1 & 2: No lockout triggered
const res1 = determineNextLockoutStage(policy, 1, 0);
assert(!res1.isLockoutTriggered, "Attempt 1 does not trigger lock");
const res2 = determineNextLockoutStage(policy, 2, 0);
assert(!res2.isLockoutTriggered, "Attempt 2 does not trigger lock");

// Attempt 3: Stage 1 triggers (3 attempts, 5 min)
const res3 = determineNextLockoutStage(policy, 3, 0);
assert(res3.isLockoutTriggered && res3.stage?.name === "Stage 1", "Attempt 3 triggers Stage 1");
assert(res3.stage?.durationValue === 5 && res3.stage?.isManualUnlock === false, "Stage 1 duration is 5m");

// While at stage 1 (attempts 3, 4, 5): Does not advance to stage 2 until threshold 6 (3 + 3)
const res4 = determineNextLockoutStage(policy, 5, 1);
assert(!res4.isLockoutTriggered, "Attempt 5 does not trigger Stage 2 (needs 6)");

// Attempt 6 (3 + 3): Stage 2 triggers (30 min)
const res6 = determineNextLockoutStage(policy, 6, 1);
assert(res6.isLockoutTriggered && res6.stage?.name === "Stage 2", "Attempt 6 triggers Stage 2");
assert(res6.stage?.durationValue === 30, "Stage 2 duration is 30m");

// Attempt 9 (3 + 3 + 3): Stage 3 triggers (24 hours)
const res9 = determineNextLockoutStage(policy, 9, 2);
assert(res9.isLockoutTriggered && res9.stage?.name === "Stage 3", "Attempt 9 triggers Stage 3");
assert(res9.stage?.durationValue === 24 && res9.stage?.durationUnit === "hours", "Stage 3 duration is 24h");

// Attempt 12 (3 + 3 + 3 + 3): Stage 4 triggers (MANUAL UNLOCK)
const res12 = determineNextLockoutStage(policy, 12, 3);
assert(res12.isLockoutTriggered && res12.stage?.name === "Stage 4", "Attempt 12 triggers Stage 4");
assert(res12.stage?.isManualUnlock === true, "Stage 4 requires manual admin unlock");
console.log("✓ Test 4: Progressive lockout escalation passed");

// ─── Test 5: Dynamic Custom Stages Configuration ──────────────────────────────
const customPolicy: AccountLockoutPolicy = {
  enabled: true,
  progressiveLockoutEnabled: true,
  targetAccountTypes: ["customer", "driver"],
  stages: [
    { id: "c1", name: "Custom 1", order: 1, attemptsRequired: 2, durationValue: 10, durationUnit: "minutes", isManualUnlock: false, enabled: true },
    { id: "c2", name: "Custom 2", order: 2, attemptsRequired: 4, durationValue: 0, durationUnit: "hours", isManualUnlock: true, enabled: true },
  ],
  counterResetPolicy: { resetOnSuccessfulLogin: true, inactivityWindowMinutes: 30 },
  independentPerRole: false,
};

// Attempt 2 triggers Custom 1
const cRes1 = determineNextLockoutStage(customPolicy, 2, 0);
assert(cRes1.isLockoutTriggered && cRes1.stage?.name === "Custom 1", "Custom stage 1 triggers at 2 attempts");

// Attempt 6 (2 + 4) triggers Custom 2 (Manual)
const cRes2 = determineNextLockoutStage(customPolicy, 6, 1);
assert(cRes2.isLockoutTriggered && cRes2.stage?.isManualUnlock === true, "Custom stage 2 triggers manual lock at 6 attempts");
console.log("✓ Test 5: Dynamic custom stages policy passed");

// ─── Test 6: Non-Progressive Single Stage Mode ─────────────────────────────────
const nonProgPolicy: AccountLockoutPolicy = {
  ...customPolicy,
  progressiveLockoutEnabled: false,
};
const npRes = determineNextLockoutStage(nonProgPolicy, 2, 0);
assert(npRes.isLockoutTriggered && npRes.stage?.name === "Custom 1", "Non-progressive mode triggers on base stage");
console.log("✓ Test 6: Non-progressive mode passed");

console.log("\nALL 6 SECURITY TEST SUITES PASSED CLEANLY!");
