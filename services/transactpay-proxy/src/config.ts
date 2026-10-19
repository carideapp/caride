import dotenv from "dotenv";

dotenv.config();

export interface AppConfig {
  port: number;
  nodeEnv: string;
  proxyAuthToken: string;
  transactpayUpstreamHost: string;
  transactpayUpstreamProtocol: string;
  upstreamTimeoutMs: number;
  rateLimitMaxPerMinute: number;
  transactpayPublicKey?: string;
  transactpaySecretKey?: string;
  vpsStaticIpv4?: string;
}

const requiredEnv = (key: string, fallback?: string): string => {
  const value = process.env[key] || fallback;
  if (!value) {
    if (process.env.NODE_ENV === "production") {
      throw new Error(`[CRITICAL CONFIG ERROR] Missing required environment variable: ${key}`);
    }
    console.warn(`[CONFIG WARNING] Missing ${key}, falling back to placeholder for development.`);
    return "dev_placeholder_secret_token";
  }
  return value;
};

export const config: AppConfig = {
  port: parseInt(process.env.PORT || "3000", 10),
  nodeEnv: process.env.NODE_ENV || "development",
  proxyAuthToken: requiredEnv("PROXY_AUTH_TOKEN"),
  transactpayUpstreamHost: process.env.TRANSACTPAY_UPSTREAM_HOST || "payment-api-service.transactpay.ai",
  transactpayUpstreamProtocol: process.env.TRANSACTPAY_UPSTREAM_PROTOCOL || "https:",
  upstreamTimeoutMs: parseInt(process.env.UPSTREAM_TIMEOUT_MS || "30000", 10),
  rateLimitMaxPerMinute: parseInt(process.env.RATE_LIMIT_MAX_PER_MINUTE || "120", 10),
  transactpayPublicKey: process.env.TRANSACTPAY_PUBLIC_KEY,
  transactpaySecretKey: process.env.TRANSACTPAY_SECRET_KEY,
  vpsStaticIpv4: process.env.VPS_STATIC_IPV4,
};
