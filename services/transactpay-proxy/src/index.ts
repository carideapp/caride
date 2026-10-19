import { createApp } from "./server.js";
import { config } from "./config.js";

const app = createApp();

const server = app.listen(config.port, () => {
  console.log(`=======================================================`);
  console.log(`🚀 CaRide TransactPay Static IP Proxy Service Started`);
  console.log(`=======================================================`);
  console.log(`Port:             ${config.port}`);
  console.log(`Environment:      ${config.nodeEnv}`);
  console.log(`Upstream Host:    ${config.transactpayUpstreamHost}`);
  console.log(`Timeout:          ${config.upstreamTimeoutMs}ms`);
  console.log(`Rate Limit:       ${config.rateLimitMaxPerMinute} req/min`);
  console.log(`VPS Static IPv4:  ${config.vpsStaticIpv4 || "(Not configured - check via /vps-ip)"}`);
  console.log(`Proxy Auth:       Configured (${config.proxyAuthToken.length} chars)`);
  console.log(`Health Check:     http://localhost:${config.port}/health`);
  console.log(`=======================================================`);
});

// Graceful termination handling
function handleShutdown(signal: string) {
  console.log(`\nReceived ${signal}. Shutting down proxy server gracefully...`);
  server.close(() => {
    console.log("HTTP server closed. Exiting process.");
    process.exit(0);
  });

  // Force shutdown after 10 seconds if hanging connections
  setTimeout(() => {
    console.error("Could not close connections in time, forcefully shutting down");
    process.exit(1);
  }, 10000).unref();
}

process.on("SIGINT", () => handleShutdown("SIGINT"));
process.on("SIGTERM", () => handleShutdown("SIGTERM"));
