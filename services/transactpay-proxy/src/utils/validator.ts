/**
 * Route & Method Whitelisting Validator.
 * Prevents this service from ever acting as an open proxy by strictly
 * validating allowed TransactPay paths and HTTP methods.
 */

export interface WhitelistRule {
  path: string;
  methods: string[];
}

export const ALLOWED_ENDPOINTS: Record<string, string[]> = {
  "/payment/order/create": ["POST"],
  "/payment/order/pay": ["POST"],
  "/payment/create": ["POST"],
  "/payment/order/status": ["POST"],
  "/payment/banks": ["GET"],
  "/payout/name-enquiry": ["POST"],
  "/payout/initiate": ["POST"],
};

export interface ValidationResult {
  allowed: boolean;
  reason?: string;
  statusCode?: number;
}

export function validateEndpoint(path: string, method: string): ValidationResult {
  // Normalize path (strip query params and trailing slash)
  const cleanPath = path.split("?")[0].replace(/\/+$/, "") || "/";
  const normalizedMethod = method.toUpperCase();

  const allowedMethods = ALLOWED_ENDPOINTS[cleanPath];

  if (!allowedMethods) {
    return {
      allowed: false,
      reason: `Forbidden: Path '${cleanPath}' is not an authorized TransactPay endpoint on this proxy.`,
      statusCode: 403,
    };
  }

  if (!allowedMethods.includes(normalizedMethod)) {
    return {
      allowed: false,
      reason: `Method '${normalizedMethod}' is not permitted for endpoint '${cleanPath}'. Allowed: ${allowedMethods.join(", ")}`,
      statusCode: 405,
    };
  }

  return { allowed: true };
}
