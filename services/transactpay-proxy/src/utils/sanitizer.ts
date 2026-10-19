/**
 * Utility to sanitize sensitive cardholder, bank account, and authentication
 * data before writing structured logs.
 */

const SENSITIVE_KEYS = new Set([
  "cardnumber",
  "card_number",
  "cvv",
  "cvc",
  "pin",
  "securitypin",
  "password",
  "otp",
  "authorizationcode",
  "token",
  "secret",
  "api-key",
  "authorization",
  "x-proxy-auth",
]);

export function sanitizeValue(key: string, value: any): any {
  if (value === null || value === undefined) return value;

  const lowerKey = key.toLowerCase();

  // Explicitly sensitive field names
  if (SENSITIVE_KEYS.has(lowerKey)) {
    if (typeof value === "string") {
      if (lowerKey.includes("card") && value.length >= 12) {
        // Mask card number: 4111********1111
        return `${value.slice(0, 4)}********${value.slice(-4)}`;
      }
      if (lowerKey === "accountnumber" || lowerKey === "account_number") {
        return value.length > 4 ? `******${value.slice(-4)}` : "******";
      }
      return "[REDACTED]";
    }
    return "[REDACTED]";
  }

  // Obscure account numbers partially
  if (lowerKey.includes("accountnumber") || lowerKey.includes("account_number")) {
    if (typeof value === "string" && value.length >= 6) {
      return `******${value.slice(-4)}`;
    }
    return "******";
  }

  // Recursive sanitization for nested objects and arrays
  if (Array.isArray(value)) {
    return value.map((item) => (typeof item === "object" ? sanitizeObject(item) : item));
  }

  if (typeof value === "object") {
    return sanitizeObject(value);
  }

  return value;
}

export function sanitizeObject(obj: Record<string, any>): Record<string, any> {
  if (!obj || typeof obj !== "object") return obj;

  const sanitized: Record<string, any> = {};
  for (const [k, v] of Object.entries(obj)) {
    sanitized[k] = sanitizeValue(k, v);
  }
  return sanitized;
}
