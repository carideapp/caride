import { Router, Request, Response } from "express";
import { config } from "../config.js";

export const healthRouter = Router();

healthRouter.get("/", (_req: Request, res: Response) => {
  res.json({
    service: "caride-transactpay-proxy",
    status: "ok",
    version: "1.0.0",
    uptimeSeconds: Math.floor(process.uptime()),
    timestamp: new Date().toISOString(),
  });
});

healthRouter.get("/health", (_req: Request, res: Response) => {
  res.json({
    status: "healthy",
    uptimeSeconds: Math.floor(process.uptime()),
    timestamp: new Date().toISOString(),
  });
});

healthRouter.get("/vps-ip", async (_req: Request, res: Response) => {
  try {
    // Probe external IP check to verify outbound static IPv4
    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), 4000);
    const ipRes = await fetch("https://api.ipify.org?format=json", { signal: controller.signal });
    clearTimeout(timeout);

    const data = (await ipRes.json()) as { ip?: string };
    res.json({
      configuredStaticIp: config.vpsStaticIpv4 || "not_explicitly_set",
      detectedOutboundIp: data.ip || "unknown",
      match: Boolean(config.vpsStaticIpv4 && config.vpsStaticIpv4 === data.ip),
      timestamp: new Date().toISOString(),
    });
  } catch (err: any) {
    res.json({
      configuredStaticIp: config.vpsStaticIpv4 || "not_explicitly_set",
      detectedOutboundIp: "probe_failed",
      error: err.message,
      timestamp: new Date().toISOString(),
    });
  }
});
