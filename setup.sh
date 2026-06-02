#!/data/data/com.termux/files/usr/bin/bash
# =============================================================================
# SETUP.SH — Entry Point: AI Agent Server di Termux (Redmi Note 10S)
# =============================================================================
# Prerequisite:
#   - Termux terbaru dari F-Droid (BUKAN Play Store)
#   - Root (KernelSU/Magisk)
#   - Jalankan: bash setup.sh
# =============================================================================

set -euo pipefail

# --- Warna untuk output ---
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

log()    { echo -e "${GREEN}[✓]${RESET} $1"; }
warn()   { echo -e "${YELLOW}[!]${RESET} $1"; }
error()  { echo -e "${RED}[✗]${RESET} $1"; exit 1; }
header() { echo -e "\n${CYAN}${BOLD}━━━ $1 ━━━${RESET}\n"; }

# --- Banner ---
echo -e "${CYAN}${BOLD}"
cat << 'EOF'
  ╔═══════════════════════════════════════════╗
  ║   AI Agent Server — Redmi Note 10S       ║
  ║   Termux + Debian + Podman + TinyLLM     ║
  ╚═══════════════════════════════════════════╝
EOF
echo -e "${RESET}"

# =============================================================================
# FASE 1: Update & install package Termux dasar
# =============================================================================
header "Update Termux packages"

# Backup repo dan set ke default
export DEBIAN_FRONTEND=noninteractive
yes | pkg upgrade -y 2>/dev/null || warn "Ada error saat upgrade, lanjut..."

log "Install package dasar..."
pkg install -y \
    proot-distro \
    wget curl \
    openssh \
    git \
    termux-services \
    python \
    tsu \
    2>/dev/null || error "Gagal install package dasar"

log "Package dasar terinstall."

# =============================================================================
# FASE 2: Setup Termux Storage
# =============================================================================
header "Setup Termux Storage Access"

if [ ! -d "$HOME/storage" ]; then
    warn "Meminta akses storage Termux..."
    termux-setup-storage
    sleep 3
fi
log "Storage siap."

# =============================================================================
# FASE 3: Setup direktori project
# =============================================================================
header "Setup direktori project"

PROJECT_DIR="$HOME/myserver"
mkdir -p "$PROJECT_DIR"/{core,services,configs,docs,data/{models,logs,db}}

# Salin semua file script ke HOME jika dijalankan dari path lain
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ "$SCRIPT_DIR" != "$PROJECT_DIR" ]; then
    log "Menyalin file project ke $PROJECT_DIR..."
    cp -r "$SCRIPT_DIR"/. "$PROJECT_DIR/" 2>/dev/null || true
fi

log "Direktori project: $PROJECT_DIR"

# =============================================================================
# FASE 4: Install proot-distro Debian
# =============================================================================
header "Install Debian Bookworm via proot-distro"

if proot-distro list | grep -q "debian.*installed"; then
    warn "Debian sudah terinstall, skip..."
else
    log "Download & install Debian Bookworm..."
    proot-distro install debian || error "Gagal install Debian"
    log "Debian berhasil diinstall!"
fi

# =============================================================================
# FASE 5: Jalankan script setup di dalam Debian
# =============================================================================
header "Setup Debian environment"

# Salin script ke dalam Debian
DEBIAN_HOME="/data/data/com.termux/files/usr/var/lib/proot-distro/installed-rootfs/debian/root"
mkdir -p "$DEBIAN_HOME/myserver"
cp -r "$PROJECT_DIR"/. "$DEBIAN_HOME/myserver/" 2>/dev/null || true

log "Menjalankan install-debian.sh di dalam Debian..."
proot-distro login debian -- bash /root/myserver/install-debian.sh

# =============================================================================
# FASE 6: Setup Termux Boot (autostart)
# =============================================================================
header "Setup autostart (termux-boot)"

mkdir -p "$HOME/.termux/boot"
cat > "$HOME/.termux/boot/start-server.sh" << 'BOOT_EOF'
#!/data/data/com.termux/files/usr/bin/bash
# Auto-start server saat Android boot
sleep 10  # tunggu sistem stabil
termux-wake-lock  # cegah Termux tidur
cd "$HOME/myserver"
bash start-server.sh >> "$HOME/myserver/data/logs/boot.log" 2>&1
BOOT_EOF
chmod +x "$HOME/.termux/boot/start-server.sh"

log "Autostart dikonfigurasi. Install Termux:Boot dari F-Droid untuk aktifkan."

# =============================================================================
# SELESAI
# =============================================================================
echo -e "\n${GREEN}${BOLD}"
cat << 'EOF'
  ╔═══════════════════════════════════════════╗
  ║   Setup Termux selesai!                  ║
  ║                                          ║
  ║   Next steps:                            ║
  ║   1. Buka core/.env dan isi API keys     ║
  ║   2. Jalankan: bash start-server.sh      ║
  ║   3. Buka URL Cloudflare tunnel          ║
  ╚═══════════════════════════════════════════╝
EOF
echo -e "${RESET}"
