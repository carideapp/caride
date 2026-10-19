import { Request, Response, NextFunction } from "express";
import crypto from "node:crypto";
import { config } from "../config.js";

/**
 * Validates that incoming requests originate from authorized callers (e.g. Firebase Cloud Functions)
 * using a shared secret token.
 */
export function requireProxyAuth(req: Request, res: Response, next: NextFunction): void {
  const authHeader = req.headers["authorization"];
  const proxyAuthHeader = req.headers["x-proxy-auth"];

  let token: string | undefined;

  if (typeof proxyAuthHeader === "string" && proxyAuthHeader.trim().length > 0) {
    token = proxyAuthHeader.trim();
  } else if (typeof authHeader === "string" && authHeader.startsWith("Bearer ")) {
    token = authHeader.slice(7).trim();
  }

  if (!token) {
    res.status(401).json({
      error: "Unauthorized: Missing authentication token in 'x-proxy-auth' or 'Authorization: Bearer <token>' header.",
      timestamp: new Date().toISOString(),
    });
    return;
  }

  // Timing-safe token comparison
  const expectedBuffer = Buffer.from(config.proxyAuthToken, "utf8");
  const actualBuffer = Buffer.from(token, "utf8");

  if (expectedBuffer.length !== actualBuffer.length || !crypto.timingSafeEqual(expectedBuffer, actualBuffer)) {
    res.status(401).json({
      error: "Unauthorized: Invalid proxy authentication token.",
      timestamp: new Date().toISOString(),
    });
    return;
  }

  next();
}
