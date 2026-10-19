import { Request, Response, NextFunction } from "express";
import { config } from "../config.js";

interface RateLimitBucket {
  count: number;
  resetTime: number;
}

const buckets = new Map<string, RateLimitBucket>();

// Periodically clean up stale buckets every 5 minutes
setInterval(() => {
  const now = Date.now();
  for (const [key, bucket] of buckets.entries()) {
    if (now > bucket.resetTime) {
      buckets.delete(key);
    }
  }
}, 5 * 60 * 1000).unref();

export function rateLimiter(req: Request, res: Response, next: NextFunction): void {
  const ip = req.ip || req.socket.remoteAddress || "unknown";
  const now = Date.now();
  const windowMs = 60 * 1000; // 1 minute window

  let bucket = buckets.get(ip);
  if (!bucket || now > bucket.resetTime) {
    bucket = { count: 1, resetTime: now + windowMs };
    buckets.set(ip, bucket);
  } else {
    bucket.count += 1;
  }

  if (bucket.count > config.rateLimitMaxPerMinute) {
    const retryAfter = Math.ceil((bucket.resetTime - now) / 1000);
    res.setHeader("Retry-After", retryAfter);
    res.status(429).json({
      error: "Too Many Requests: Rate limit exceeded. Please retry shortly.",
      retryAfterSeconds: retryAfter,
      timestamp: new Date().toISOString(),
    });
    return;
  }

  next();
}
