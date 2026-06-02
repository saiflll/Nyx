#!/bin/bash
# =============================================================================
# configs/cloudflare/setup-tunnel.sh
# Setup Cloudflare Tunnel (zero-config atau dengan akun)
# =============================================================================
set -euo pipefail

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'
log()    { echo -e "${GREEN}[✓]${RESET} $1"; }
warn()   { echo -e "${YELLOW}[!]${RESET} $1"; }
error()  { echo -e "${RED}[✗]${RESET} $1"; exit 1; }
header() { echo -e "\n${CYAN}${BOLD}━━━ $1 ━━━${RESET}\n"; }

# Verifikasi cloudflared ada
if ! command -v cloudflared &>/dev/null; then
    error "cloudflared tidak ditemukan! Jalankan install-debian.sh terlebih dahulu."
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$(dirname "$(dirname "$SCRIPT_DIR")")/core/.env"

# Source .env jika ada
[ -f "$ENV_FILE" ] && source "$ENV_FILE" || true

TUNNEL_NAME="${SERVER_NAME:-myserver}"
CONFIG_FILE="$SCRIPT_DIR/config.yml"

header "Setup Cloudflare Tunnel"

echo "  Pilih mode tunnel:"
echo "  1. Quick Tunnel (tanpa akun) — URL random, berubah setiap restart"
echo "  2. Named Tunnel (dengan akun Cloudflare) — URL tetap"
echo ""
echo -n "  Pilih [1/2] (default: 1): "
read -r choice
choice="${choice:-1}"

if [ "$choice" = "2" ]; then
    # ─────────────────────────────────────────────────────────────────
    # MODE 2: Named Tunnel dengan akun Cloudflare
    # ─────────────────────────────────────────────────────────────────
    header "Login ke Cloudflare"

    if [ ! -f "$HOME/.cloudflared/cert.pem" ]; then
        warn "Perlu login ke Cloudflare..."
        cloudflared tunnel login
    fi

    log "Membuat tunnel '$TUNNEL_NAME'..."
    if cloudflared tunnel list | grep -q "$TUNNEL_NAME"; then
        warn "Tunnel '$TUNNEL_NAME' sudah ada."
    else
        cloudflared tunnel create "$TUNNEL_NAME"
    fi

    # Ambil tunnel ID
    TUNNEL_ID=$(cloudflared tunnel list --output json | \
        python3 -c "import json,sys; tunnels=json.load(sys.stdin); [print(t['id']) for t in tunnels if t['name']=='$TUNNEL_NAME']" 2>/dev/null | head -1)

    if [ -z "$TUNNEL_ID" ]; then
        error "Gagal mendapatkan tunnel ID."
    fi

    log "Tunnel ID: $TUNNEL_ID"

    # Tanya hostname
    echo ""
    echo "  Domain yang mau digunakan?"
    echo "  Contoh: myserver.yourdomain.com"
    echo -n "  Hostname: "
    read -r HOSTNAME

    if [ -n "$HOSTNAME" ]; then
        log "Routing $HOSTNAME → localhost:80..."
        cloudflared tunnel route dns "$TUNNEL_NAME" "$HOSTNAME" || \
            warn "Gagal set DNS. Set manual di Cloudflare Dashboard."
    fi

    # Buat config file
    cat > "$CONFIG_FILE" << EOF
# Cloudflare Tunnel Config
tunnel: $TUNNEL_ID
credentials-file: $HOME/.cloudflared/$TUNNEL_ID.json

ingress:
  # Web interface utama
  - hostname: ${HOSTNAME:-}
    service: http://localhost:80

  # Catch-all
  - service: http_status:404
EOF

    log "Config tersimpan di $CONFIG_FILE"

    # Update .env
    if [ -f "$ENV_FILE" ]; then
        sed -i "s|CLOUDFLARE_TUNNEL_TOKEN=.*|CLOUDFLARE_TUNNEL_TOKEN=$TUNNEL_ID|" "$ENV_FILE"
        [ -n "${HOSTNAME:-}" ] && \
            sed -i "s|PUBLIC_HOSTNAME=.*|PUBLIC_HOSTNAME=$HOSTNAME|" "$ENV_FILE"
    fi

    echo ""
    log "✅ Named Tunnel siap!"
    log "Start tunnel dengan: cloudflared tunnel --config $CONFIG_FILE run"
    [ -n "${HOSTNAME:-}" ] && log "URL publik: https://$HOSTNAME"

else
    # ─────────────────────────────────────────────────────────────────
    # MODE 1: Quick Tunnel (tanpa akun)
    # ─────────────────────────────────────────────────────────────────
    header "Quick Tunnel (tanpa akun)"

    # Buat script untuk quick tunnel
    cat > "$SCRIPT_DIR/start-quick-tunnel.sh" << 'QUICK_EOF'
#!/bin/bash
# Quick tunnel — URL random setiap restart
LOG_FILE="/opt/myserver/logs/system/tunnel.log"
mkdir -p "$(dirname "$LOG_FILE")"

echo "Starting Cloudflare Quick Tunnel..."
cloudflared tunnel --url http://localhost:80 --no-autoupdate \
    --logfile "$LOG_FILE" &

TUNNEL_PID=$!
sleep 5

# Ambil URL dari log
TUNNEL_URL=$(grep -o 'https://[^"]*trycloudflare\.com[^"]*' "$LOG_FILE" 2>/dev/null | head -1)

if [ -n "$TUNNEL_URL" ]; then
    echo ""
    echo "  ╔══════════════════════════════════════════════════╗"
    echo "  ║  🌐 URL Publik (berubah setiap restart):        ║"
    echo "  ║  $TUNNEL_URL"
    echo "  ╚══════════════════════════════════════════════════╝"
    echo ""

    # Simpan URL ke file untuk referensi
    echo "$TUNNEL_URL" > /opt/myserver/data/current-tunnel-url.txt
fi

echo "Tunnel berjalan (PID: $TUNNEL_PID)"
wait $TUNNEL_PID
QUICK_EOF

    chmod +x "$SCRIPT_DIR/start-quick-tunnel.sh"

    warn "Quick tunnel URL akan berubah setiap restart."
    warn "Untuk URL tetap, buat akun Cloudflare dan jalankan lagi dengan pilihan 2."
    log "Script start quick tunnel: $SCRIPT_DIR/start-quick-tunnel.sh"
fi

echo ""
log "Cloudflare tunnel setup selesai!"
