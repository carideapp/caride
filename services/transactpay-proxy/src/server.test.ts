import test from "node:test";
import assert from "node:assert/strict";
import { validateEndpoint } from "./utils/validator.js";
import { sanitizeValue, sanitizeObject } from "./utils/sanitizer.js";

test("validateEndpoint permits whitelisted TransactPay paths and methods", () => {
  assert.equal(validateEndpoint("/payment/order/create", "POST").allowed, true);
  assert.equal(validateEndpoint("/payment/order/pay", "POST").allowed, true);
  assert.equal(validateEndpoint("/payment/create", "POST").allowed, true);
  assert.equal(validateEndpoint("/payment/order/status", "POST").allowed, true);
  assert.equal(validateEndpoint("/payment/banks", "GET").allowed, true);
  assert.equal(validateEndpoint("/payout/name-enquiry", "POST").allowed, true);
  assert.equal(validateEndpoint("/payout/initiate", "POST").allowed, true);
});

test("validateEndpoint rejects non-whitelisted paths (anti-open-proxy)", () => {
  assert.equal(validateEndpoint("/random/path", "POST").allowed, false);
  assert.equal(validateEndpoint("/admin/keys", "GET").allowed, false);
  assert.equal(validateEndpoint("https://google.com", "GET").allowed, false);
  assert.equal(validateEndpoint("/etc/passwd", "GET").allowed, false);
});

test("validateEndpoint rejects disallowed methods for valid paths", () => {
  // /payment/banks only permits GET
  const banksPost = validateEndpoint("/payment/banks", "POST");
  assert.equal(banksPost.allowed, false);
  assert.equal(banksPost.statusCode, 405);

  // /payout/initiate only permits POST
  const payoutGet = validateEndpoint("/payout/initiate", "GET");
  assert.equal(payoutGet.allowed, false);
  assert.equal(payoutGet.statusCode, 405);
});

test("sanitizeValue correctly redacts card numbers and sensitive credentials", () => {
  assert.equal(sanitizeValue("cardNumber", "4111222233334444"), "4111********4444");
  assert.equal(sanitizeValue("cvv", "123"), "[REDACTED]");
  assert.equal(sanitizeValue("pin", "9876"), "[REDACTED]");
  assert.equal(sanitizeValue("otp", "123456"), "[REDACTED]");
  assert.equal(sanitizeValue("accountNumber", "0123456789"), "******6789");
  assert.equal(sanitizeValue("api-key", "secret-key-12345"), "[REDACTED]");
});

test("sanitizeObject recursively redacts objects", () => {
  const input = {
    amount: 5000,
    cardNumber: "5500112233445566",
    nested: {
      cvv: "999",
      bank: "058",
    },
  };
  const sanitized = sanitizeObject(input);
  assert.equal(sanitized.amount, 5000);
  assert.equal(sanitized.cardNumber, "5500********5566");
  assert.equal(sanitized.nested.cvv, "[REDACTED]");
  assert.equal(sanitized.nested.bank, "058");
});
