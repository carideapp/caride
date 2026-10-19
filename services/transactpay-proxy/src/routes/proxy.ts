import { Router, Request, Response } from "express";
import https from "node:https";
import http from "node:http";
import { config } from "../config.js";
import { validateEndpoint } from "../utils/validator.js";

export const proxyRouter = Router();

// Keep-alive agent for low-latency outbound requests from VPS to TransactPay
const httpsAgent = new https.Agent({
  keepAlive: true,
  maxSockets: 50,
  timeout: config.upstreamTimeoutMs,
});

const httpAgent = new http.Agent({
  keepAlive: true,
  maxSockets: 50,
  timeout: config.upstreamTimeoutMs,
});

proxyRouter.all("*", async (req: Request, res: Response) => {
  const method = req.method.toUpperCase();
  const path = req.originalUrl || req.url;

  // 1. Strict Whitelist Validation (Anti-Open-Proxy Protection)
  const validation = validateEndpoint(path, method);
  if (!validation.allowed) {
    res.status(validation.statusCode || 403).json({
      error: validation.reason,
      endpoint: path,
      method,
      timestamp: new Date().toISOString(),
    });
    return;
  }

  // 2. Prepare Upstream Request Headers
  const upstreamHeaders: Record<string, string> = {
    host: config.transactpayUpstreamHost,
    "user-agent": "CaRide-TransactPay-Proxy/1.0",
    "content-type": (req.headers["content-type"] as string) || "application/json",
  };

  // Forward TransactPay specific headers if sent by Firebase
  const headerKeysToForward = [
    "api-key",
    "authorization",
    "encryption",
    "x-use-secret-key",
    "idempotency-key",
  ];

  for (const key of headerKeysToForward) {
    const value = req.headers[key];
    if (value && typeof value === "string") {
      upstreamHeaders[key] = value;
    }
  }

  // Fallback injection if api-key header was not supplied by client
  if (!upstreamHeaders["api-key"]) {
    const useSecret = req.headers["x-use-secret-key"] === "true" || path.includes("/payout/initiate");
    const fallbackKey = useSecret ? config.transactpaySecretKey : config.transactpayPublicKey;
    if (fallbackKey) {
      upstreamHeaders["api-key"] = fallbackKey;
      upstreamHeaders["authorization"] = `Bearer ${fallbackKey}`;
      upstreamHeaders["encryption"] = "RSA";
    }
  }

  // 3. Serialize Body
  let bodyBuffer: Buffer | undefined;
  if (req.body && Object.keys(req.body).length > 0) {
    const bodyStr = typeof req.body === "string" ? req.body : JSON.stringify(req.body);
    bodyBuffer = Buffer.from(bodyStr, "utf8");
    upstreamHeaders["content-length"] = bodyBuffer.length.toString();
  }

  // 4. Dispatch Upstream Request to TransactPay
  const isHttps = config.transactpayUpstreamProtocol === "https:";
  const clientModule = isHttps ? https : http;
  const agent = isHttps ? httpsAgent : httpAgent;

  let isHandled = false;

  const upstreamReq = clientModule.request(
    {
      protocol: config.transactpayUpstreamProtocol,
      hostname: config.transactpayUpstreamHost,
      port: isHttps ? 443 : 80,
      path,
      method,
      headers: upstreamHeaders,
      agent,
      timeout: config.upstreamTimeoutMs,
    },
    (upstreamRes) => {
      if (isHandled) return;
      isHandled = true;

      // Forward status code
      res.status(upstreamRes.statusCode || 200);

      // Forward content type and essential headers
      if (upstreamRes.headers["content-type"]) {
        res.setHeader("Content-Type", upstreamRes.headers["content-type"]);
      }

      // Pipe the upstream stream directly back to Firebase
      upstreamRes.pipe(res);
    }
  );

  // Handle client disconnect
  req.on("close", () => {
    if (!isHandled) {
      upstreamReq.destroy(new Error("Client connection closed prematurely"));
    }
  });

  // Handle request timeouts
  upstreamReq.on("timeout", () => {
    if (isHandled) return;
    isHandled = true;
    upstreamReq.destroy();
    res.status(504).json({
      error: `Upstream TransactPay timeout after ${config.upstreamTimeoutMs}ms`,
      endpoint: path,
      timestamp: new Date().toISOString(),
    });
  });

  // Handle network / socket errors
  upstreamReq.on("error", (err: any) => {
    if (isHandled) return;
    isHandled = true;
    res.status(502).json({
      error: `Bad Gateway: Error communicating with TransactPay upstream (${err.message})`,
      endpoint: path,
      timestamp: new Date().toISOString(),
    });
  });

  // Send body if present
  if (bodyBuffer) {
    upstreamReq.write(bodyBuffer);
  }
  upstreamReq.end();
});
