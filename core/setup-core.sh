#!/bin/bash
# =============================================================================
# core/setup-core.sh — Setup awal setelah Debian + Podman siap
# Dijalankan SATU KALI setelah install selesai
# =============================================================================
set -euo pipefail

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'
log()    { echo -e "${GREEN}[✓]${RESET} $1"; }
warn()   { echo -e "${YELLOW}[!]${RESET} $1"; }
error()  { echo -e "${RED}[✗]${RESET} $1"; exit 1; }
prompt() { echo -e "\n${YELLOW}[?]${RESET} $1"; }
header() { echo -e "\n${CYAN}${BOLD}━━━ $1 ━━━${RESET}\n"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

# =============================================================================
# FASE 1: Setup .env
# =============================================================================
header "Setup environment variables"

ENV_FILE="$SCRIPT_DIR/.env"
ENV_TEMPLATE="$SCRIPT_DIR/.env.template"

if [ ! -f "$ENV_FILE" ]; then
    cp "$ENV_TEMPLATE" "$ENV_FILE"
    warn "File .env dibuat dari template."
    warn "PENTING: Edit $ENV_FILE dan isi semua API keys sebelum lanjut!"
    echo ""
    prompt "Sudah isi .env? (y/N)"
    read -r confirm
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "Silakan edit: nano $ENV_FILE"
        echo "Lalu jalankan lagi: bash $SCRIPT_DIR/setup-core.sh"
        exit 0
    fi
fi

# Source .env
set -a; source "$ENV_FILE"; set +a
log ".env loaded."

# =============================================================================
# FASE 2: Generate secrets jika masih pakai nilai default
# =============================================================================
header "Generate secrets"

# Fungsi untuk generate random secret
gen_secret() { openssl rand -hex 32 2>/dev/null || head -c 32 /dev/urandom | base64; }

if grep -q "GANTI_INI" "$ENV_FILE"; then
    warn "Mengganti placeholder secrets dengan nilai random..."
    ROUTER_SECRET=$(gen_secret)
    QWEN_SECRET=$(gen_secret)
    JWT_SECRET=$(gen_secret)

    sed -i "s/AI_ROUTER_SECRET=.*/AI_ROUTER_SECRET=$ROUTER_SECRET/" "$ENV_FILE"
    sed -i "s/QWEN_ACCESS_SECRET=.*/QWEN_ACCESS_SECRET=$QWEN_SECRET/" "$ENV_FILE"
    sed -i "s/JWT_SECRET=.*/JWT_SECRET=$JWT_SECRET/" "$ENV_FILE"
    log "Secrets di-generate secara otomatis."
fi

# =============================================================================
# FASE 3: Download model Qwen2.5
# =============================================================================
header "Download model Qwen2.5"

MODEL_DIR="/opt/myserver/models"
MODEL_SIZE="${QWEN_MODEL_SIZE:-1.5B}"

if [ "$MODEL_SIZE" = "3B" ]; then
    MODEL_FILE="Qwen2.5-3B-Instruct-Q4_K_M.gguf"
    MODEL_URL="https://huggingface.co/Qwen/Qwen2.5-3B-Instruct-GGUF/resolve/main/qwen2.5-3b-instruct-q4_k_m.gguf"
    EXPECTED_SIZE_GB=2.0
else
    MODEL_FILE="Qwen2.5-1.5B-Instruct-Q4_K_M.gguf"
    MODEL_URL="https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/qwen2.5-1.5b-instruct-q4_k_m.gguf"
    EXPECTED_SIZE_GB=1.2
fi

if [ -f "$MODEL_DIR/$MODEL_FILE" ]; then
    log "Model $MODEL_FILE sudah ada, skip download."
else
    # Cek apakah ada cukup space
    FREE_SPACE_GB=$(df -BG "$MODEL_DIR" | tail -1 | awk '{gsub("G",""); print $4}')
    if (( FREE_SPACE_GB < EXPECTED_SIZE_GB + 1 )); then
        error "Storage tidak cukup! Butuh ~${EXPECTED_SIZE_GB}GB, tersedia ${FREE_SPACE_GB}GB"
    fi

    log "Download $MODEL_FILE (~${EXPECTED_SIZE_GB}GB)..."
    log "Ini bisa memakan waktu 10-30 menit tergantung koneksi..."

    wget --progress=bar:force \
        --retry-connrefused \
        --tries=5 \
        -c \
        "$MODEL_URL" \
        -O "$MODEL_DIR/$MODEL_FILE" || error "Download model gagal"

    log "Model $MODEL_FILE berhasil didownload!"
fi

# Update .env dengan nama model
sed -i "s/QWEN_MODEL_FILE=.*/QWEN_MODEL_FILE=$MODEL_FILE/" "$ENV_FILE" 2>/dev/null || \
    echo "QWEN_MODEL_FILE=$MODEL_FILE" >> "$ENV_FILE"

# =============================================================================
# FASE 4: Setup rclone untuk cloud storage
# =============================================================================
header "Setup rclone Cloud Storage"

mkdir -p /root/.config/rclone

if [ ! -f /root/.config/rclone/rclone.conf ] || [ ! -s /root/.config/rclone/rclone.conf ]; then
    warn "Konfigurasi rclone belum ada."
    echo ""
    echo "  Jalankan 'rclone config' secara manual untuk setup:"
    echo ""
    echo "  1. Google Drive:  ketik 'n', nama: gdrive, provider: Google Drive"
    echo "  2. MEGA:          ketik 'n', nama: mega, provider: Mega"
    echo "  3. Dropbox:       ketik 'n', nama: dropbox, provider: Dropbox"
    echo "  4. Terabox:       ketik 'n', nama: terabox, provider: WebDAV"
    echo ""
    prompt "Mau jalankan rclone config sekarang? (y/N)"
    read -r run_rclone
    if [[ "$run_rclone" =~ ^[Yy]$ ]]; then
        rclone config
    else
        warn "Skip rclone config. Jalankan 'rclone config' nanti sebelum pakai storage manager."
    fi
fi

# =============================================================================
# FASE 5: Setup Cloudflare Tunnel
# =============================================================================
header "Setup Cloudflare Tunnel"

bash "$ROOT_DIR/configs/cloudflare/setup-tunnel.sh"

# =============================================================================
# FASE 6: Build semua Docker images
# =============================================================================
header "Build Docker images"

cd "$SCRIPT_DIR"
log "Building semua services (ini bisa lama pertama kali)..."
podman-compose build --no-cache 2>&1 | while IFS= read -r line; do
    echo "  $line"
done

log "Semua images berhasil di-build!"

# =============================================================================
# FASE 7: Start semua services
# =============================================================================
header "Starting semua services"

podman-compose up -d

sleep 5
echo ""
log "Status services:"
podman-compose ps

# =============================================================================
# SELESAI
# =============================================================================
echo -e "\n${GREEN}${BOLD}"
echo "  ╔════════════════════════════════════════════╗"
echo "  ║   Setup selesai! Server siap digunakan.  ║"
echo "  ╚════════════════════════════════════════════╝"
echo -e "${RESET}"

# Tampilkan URL akses
if [ -n "${PUBLIC_HOSTNAME:-}" ]; then
    echo "  🌐 Akses via: https://$PUBLIC_HOSTNAME"
fi
echo "  📊 Local: http://localhost:${WEB_PORT:-3000}"
echo ""
echo "  Perintah berguna:"
echo "  - Lihat status:  podman-compose ps"
echo "  - Lihat log:     podman-compose logs -f [service]"
echo "  - Stop server:   bash $ROOT_DIR/stop-server.sh"
