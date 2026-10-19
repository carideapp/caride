#!/usr/bin/env bash
# ==============================================================================
# CaRide TransactPay Static IP Proxy - Automated VPS Deployment Script
# Target OS: Ubuntu 22.04 / 24.04 LTS, Debian 12
# ==============================================================================

set -euo pipefail

echo "=========================================================="
echo "  CaRide TransactPay Static IP Proxy - VPS Setup Script   "
echo "=========================================================="

# 1. Detect Outbound Static IPv4 Address
STATIC_IP=$(curl -4 -s --max-time 5 https://ifconfig.me || curl -4 -s --max-time 5 https://api.ipify.org || echo "UNKNOWN")

echo ""
echo ">>> [STATIC IP DETECTED]"
echo ">>> Public IPv4 Address: ${STATIC_IP}"
echo ">>> Submit THIS IP address to TransactPay Support for whitelisting!"
echo ""

# 2. Update System Packages
echo ">>> Updating apt repositories..."
sudo apt-get update -y && sudo apt-get upgrade -y
sudo apt-get install -y curl ufw git openssl jq

# 3. Configure UFW Firewall
echo ">>> Hardening UFW firewall..."
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 22/tcp comment 'SSH'
sudo ufw allow 80/tcp comment 'HTTP (for ACME challenge)'
sudo ufw allow 443/tcp comment 'HTTPS (Secure Proxy)'
# Explicitly block port 3000 from public interface so callers must use HTTPS
sudo ufw deny 3000/tcp comment 'Block direct Node port from internet'
echo "y" | sudo ufw enable
sudo ufw status verbose

# 4. Install Docker & Docker Compose if not present
if ! command -v docker &> /dev/null; then
    echo ">>> Installing Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    rm -f get-docker.sh
    sudo systemctl enable --now docker
fi

# 5. Prepare Configuration (.env)
if [ ! -f .env ]; then
    echo ">>> Creating .env file from template..."
    cp .env.example .env

    # Generate cryptographically secure random token (64 hex characters)
    RANDOM_TOKEN=$(openssl rand -hex 32)
    sed -i "s/your_secure_random_proxy_token_here_change_in_production/${RANDOM_TOKEN}/g" .env
    sed -i "s/VPS_STATIC_IPV4=127.0.0.1/VPS_STATIC_IPV4=${STATIC_IP}/g" .env
    echo ">>> Generated secure PROXY_AUTH_TOKEN: ${RANDOM_TOKEN}"
fi

# 6. Prompt for Domain if needed
echo ""
echo "Enter the domain name pointing to ${STATIC_IP} (e.g. proxy.caride.ng or press Enter to use IP directly):"
read -r USER_DOMAIN

if [ -n "${USER_DOMAIN}" ]; then
    sed -i "s/proxy.caride.ng/${USER_DOMAIN}/g" deploy/caddy/Caddyfile
    echo ">>> Updated Caddyfile with domain: ${USER_DOMAIN}"
fi

# 7. Build and Start Services
echo ">>> Building and starting TransactPay Proxy with Caddy SSL..."
sudo docker compose down --remove-orphans || true
sudo docker compose build --no-cache
sudo docker compose up -d

echo ""
echo "=========================================================="
echo "  DEPLOYMENT SUCCESSFUL!                                  "
echo "=========================================================="
echo "VPS Static IP:     ${STATIC_IP}  <-- Give this to TransactPay!"
echo "Service Status:    Running in Docker"
echo "Check Health:      curl http://localhost:3000/health"
echo "Check Logs:        sudo docker compose logs -f"
echo "=========================================================="
