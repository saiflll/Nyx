#!/bin/bash
# =============================================================================
# START-SERVER.SH — Start semua service AI Agent Server
# =============================================================================
set -euo pipefail

CYAN='\033[0;36m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
RED='\033[0;31m'; BOLD='\033[1m'; RESET='\033[0m'
log()    { echo -e "${GREEN}[✓]${RESET} $1"; }
warn()   { echo -e "${YELLOW}[!]${RESET} $1"; }
error()  { echo -e "${RED}[✗]${RESET} $1"; }
header() { echo -e "\n${CYAN}${BOLD}━━━ $1 ━━━${RESET}\n"; }

echo -e "${CYAN}${BOLD}"
echo "  ╔══════════════════════════════════╗"
echo "  ║  Starting AI Agent Server...    ║"
echo "  ╚══════════════════════════════════╝"
echo -e "${RESET}"

# =============================================================================
# Start Debian proot dan jalankan server di dalamnya
# =============================================================================
header "Boot Debian + Services"

proot-distro login debian -- bash -c "
    set -e

    # Start Podman daemon
    if ! podman ps &>/dev/null; then
        echo 'Starting Podman...'
        podman system service --time=0 unix:///run/podman/podman.sock &
        sleep 2
    fi

    # Start cron
    service cron start 2>/dev/null || true

    # Start semua Docker services
    cd /root/myserver/core
    podman-compose up -d

    # Start Cloudflare tunnel
    if [ -f /root/myserver/configs/cloudflare/config.yml ]; then
        cloudflared tunnel --config /root/myserver/configs/cloudflare/config.yml run &
        echo 'Cloudflare tunnel started'
    else
        # Mode quick tunnel (tanpa akun)
        cloudflared tunnel --url http://localhost:3000 --no-autoupdate &>/opt/myserver/logs/system/tunnel.log &
        sleep 3
        TUNNEL_URL=\$(grep -o 'https://[^\"]*trycloudflare[^\"]*' /opt/myserver/logs/system/tunnel.log | head -1)
        echo \"\"
        echo '  ╔══════════════════════════════════════════════╗'
        echo \"  ║  Public URL: \$TUNNEL_URL \"
        echo '  ╚══════════════════════════════════════════════╝'
    fi

    echo ''
    echo 'Services status:'
    podman-compose ps
"

log "Server started!"
