#!/bin/bash
# =============================================================================
# STOP-SERVER.SH — Stop semua service dengan graceful shutdown
# =============================================================================
set -euo pipefail

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'
BOLD='\033[1m'; RESET='\033[0m'

log()    { echo -e "${GREEN}[✓]${RESET} $1"; }
warn()   { echo -e "${YELLOW}[!]${RESET} $1"; }
header() { echo -e "\n${CYAN}${BOLD}━━━ $1 ━━━${RESET}\n"; }

header "Stopping AI Agent Server"

proot-distro login debian -- bash -c "
    # Stop Cloudflare tunnel
    pkill -f cloudflared 2>/dev/null && echo 'Tunnel stopped' || true

    # Stop semua Docker/Podman services
    cd /root/myserver/core
    podman-compose down

    echo 'All services stopped.'
"

log "Server stopped!"
