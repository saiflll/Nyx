#!/bin/bash
# =============================================================================
# INSTALL-DEBIAN.SH — Konfigurasi Debian Bookworm di dalam proot
# Dijalankan DARI DALAM Debian environment
# =============================================================================

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'
log()    { echo -e "${GREEN}[✓]${RESET} $1"; }
warn()   { echo -e "${YELLOW}[!]${RESET} $1"; }
error()  { echo -e "${RED}[✗]${RESET} $1"; exit 1; }
header() { echo -e "\n${CYAN}${BOLD}━━━ $1 ━━━${RESET}\n"; }

# =============================================================================
# FASE 1: Update Debian & install package dasar
# =============================================================================
header "Update Debian Bookworm"

# Set DNS (kadang DNS bermasalah di proot)
echo "nameserver 1.1.1.1" > /etc/resolv.conf
echo "nameserver 8.8.8.8" >> /etc/resolv.conf

export DEBIAN_FRONTEND=noninteractive
apt-get update -y 2>&1 | tail -5
apt-get upgrade -y 2>&1 | tail -5

log "Install package esensial..."
apt-get install -y \
    curl wget git vim nano \
    ca-certificates gnupg \
    sudo procps \
    build-essential \
    python3 python3-pip python3-venv \
    golang \
    net-tools iproute2 \
    logrotate \
    cron \
    jq \
    htop \
    lsof \
    rclone \
    2>/dev/null | tail -5

log "Package dasar terinstall."

# =============================================================================
# FASE 2: Install cloudflared
# =============================================================================
header "Install cloudflared"

if ! command -v cloudflared &>/dev/null; then
    log "Download cloudflared untuk ARM64..."
    ARCH=$(uname -m)
    if [[ "$ARCH" == "aarch64" ]]; then
        CF_ARCH="arm64"
    elif [[ "$ARCH" == "armv7l" ]]; then
        CF_ARCH="arm"
    else
        CF_ARCH="amd64"
    fi

    wget -q "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${CF_ARCH}" \
        -O /usr/local/bin/cloudflared
    chmod +x /usr/local/bin/cloudflared
    log "cloudflared v$(cloudflared --version 2>&1 | head -1) terinstall."
else
    warn "cloudflared sudah ada: $(cloudflared --version 2>&1 | head -1)"
fi

# =============================================================================
# FASE 3: Install llama.cpp (untuk Qwen2.5 lokal)
# =============================================================================
header "Install llama.cpp server"

LLAMA_DIR="/opt/llama.cpp"

if [ ! -f "$LLAMA_DIR/llama-server" ]; then
    mkdir -p "$LLAMA_DIR"
    log "Download llama.cpp release binary untuk ARM64..."

    LLAMA_RELEASE_URL="https://github.com/ggerganov/llama.cpp/releases/latest"
    LLAMA_LATEST=$(curl -sL -o /dev/null -w '%{url_effective}' "$LLAMA_RELEASE_URL" | \
        grep -o 'tag/[^"]*' | head -1 | sed 's/tag\///')

    # Download pre-built binary untuk ARM
    LLAMA_BINARY_URL="https://github.com/ggerganov/llama.cpp/releases/download/${LLAMA_LATEST}/llama-${LLAMA_LATEST}-bin-ubuntu-arm64.zip"

    if wget -q --spider "$LLAMA_BINARY_URL" 2>/dev/null; then
        wget -q "$LLAMA_BINARY_URL" -O /tmp/llama.zip
        cd /tmp && unzip -q llama.zip -d llama_bin
        cp /tmp/llama_bin/build/bin/llama-server "$LLAMA_DIR/" 2>/dev/null || \
        find /tmp/llama_bin -name "llama-server" -exec cp {} "$LLAMA_DIR/" \;
        chmod +x "$LLAMA_DIR/llama-server"
        rm -rf /tmp/llama.zip /tmp/llama_bin
        log "llama-server terinstall di $LLAMA_DIR"
    else
        warn "Binary tidak tersedia, compile dari source (ini akan lama ~15-20 menit)..."
        apt-get install -y cmake 2>/dev/null | tail -3

        git clone --depth 1 https://github.com/ggerganov/llama.cpp.git /tmp/llama_src
        cd /tmp/llama_src
        cmake -B build -DLLAMA_BUILD_SERVER=ON \
            -DCMAKE_BUILD_TYPE=Release \
            -DGGML_NATIVE=OFF 2>&1 | tail -5
        cmake --build build -j$(nproc) --target llama-server 2>&1 | tail -10
        cp build/bin/llama-server "$LLAMA_DIR/"
        chmod +x "$LLAMA_DIR/llama-server"
        rm -rf /tmp/llama_src
        log "llama-server berhasil dikompilasi."
    fi
else
    warn "llama-server sudah ada."
fi

# =============================================================================
# FASE 4: Setup user & direktori
# =============================================================================
header "Setup user dan direktori"

# Buat user server (non-root untuk service)
if ! id "aiserver" &>/dev/null; then
    useradd -m -s /bin/bash aiserver
    echo "aiserver ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
    log "User 'aiserver' dibuat."
fi

# Setup direktori
mkdir -p /opt/myserver/{models,logs/{ai-router,qwen,storage,monitor,system},data,tmp}
chmod -R 755 /opt/myserver
chown -R aiserver:aiserver /opt/myserver

log "Direktori /opt/myserver siap."

# =============================================================================
# FASE 5: Setup cron untuk log cleanup
# =============================================================================
header "Setup cron jobs"

cat > /etc/cron.d/myserver << 'CRON_EOF'
# Log cleanup — setiap 6 jam
0 */6 * * * root /root/myserver/configs/log-management/cleanup.sh >> /opt/myserver/logs/system/cleanup.log 2>&1

# Log rotate — setiap hari jam 2 pagi
0 2 * * * root logrotate /root/myserver/configs/log-management/logrotate.conf

# Cek health semua service — setiap 5 menit
*/5 * * * * aiserver /root/myserver/configs/health-check.sh >> /opt/myserver/logs/system/health.log 2>&1
CRON_EOF

chmod 644 /etc/cron.d/myserver
log "Cron jobs dikonfigurasi."

# =============================================================================
# FASE 6: Install Podman
# =============================================================================
header "Install Podman"

bash /root/myserver/core/install-docker.sh

# =============================================================================
# SELESAI
# =============================================================================
log "Setup Debian selesai!"
echo ""
echo "  Langkah selanjutnya:"
echo "  1. Edit /root/myserver/core/.env"
echo "  2. Jalankan: bash /root/myserver/core/setup-core.sh"
