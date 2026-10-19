import { Request, Response, NextFunction } from "express";
import crypto from "node:crypto";
import { sanitizeObject } from "../utils/sanitizer.js";

export function requestLogger(req: Request, res: Response, next: NextFunction): void {
  const startTime = Date.now();
  const requestId = (req.headers["x-request-id"] as string) || crypto.randomUUID();

  // Attach requestId to response headers
  res.setHeader("X-Request-Id", requestId);

  res.on("finish", () => {
    const duration = Date.now() - startTime;
    const clientIp = req.headers["x-forwarded-for"] || req.socket.remoteAddress;

    const logEntry = {
      timestamp: new Date().toISOString(),
      requestId,
      method: req.method,
      path: req.originalUrl || req.url,
      statusCode: res.statusCode,
      durationMs: duration,
      clientIp,
      query: sanitizeObject(req.query),
      userAgent: req.headers["user-agent"],
    };

    if (res.statusCode >= 500) {
      console.error("[ERROR]", JSON.stringify(logEntry));
    } else if (res.statusCode >= 400) {
      console.warn("[WARN]", JSON.stringify(logEntry));
    } else {
      console.log("[INFO]", JSON.stringify(logEntry));
    }
  });

  next();
}
