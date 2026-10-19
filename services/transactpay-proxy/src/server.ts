import express, { Express } from "express";
import helmet from "helmet";
import cors from "cors";
import { requestLogger } from "./middleware/logger.js";
import { rateLimiter } from "./middleware/rateLimit.js";
import { requireProxyAuth } from "./middleware/auth.js";
import { healthRouter } from "./routes/health.js";
import { proxyRouter } from "./routes/proxy.js";

export function createApp(): Express {
  const app = express();

  // Trust reverse proxy (Caddy / Nginx / Cloudflare) to obtain client IP
  app.set("trust proxy", 1);

  // Security Headers
  app.use(helmet());

  // CORS (disabled/restricted)
  app.use(cors({ origin: false }));

  // Request Body Parsers (1MB limit to prevent memory exhaustion)
  app.use(express.json({ limit: "1mb" }));
  app.use(express.urlencoded({ extended: true, limit: "1mb" }));

  // Structured Audit Logging
  app.use(requestLogger);

  // Rate Limiting
  app.use(rateLimiter);

  // Public Health and IP Diagnostics routes (unauthenticated)
  app.use("/", healthRouter);

  // Authenticated Proxy Pipeline (Protected by X-Proxy-Auth token & strict whitelist)
  app.use(requireProxyAuth);
  app.use(proxyRouter);

  // Global 404 Fallback
  app.use((req, res) => {
    res.status(404).json({
      error: `Not Found: Cannot ${req.method} ${req.originalUrl}`,
      timestamp: new Date().toISOString(),
    });
  });

  return app;
}
