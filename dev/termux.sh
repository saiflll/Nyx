#!/data/data/com.termux/files/usr/bin/bash
# =============================================================================
# DEV/TERMUX.SH — Entry Point: AI Agent Server di Termux (Redmi Note 10S)
# =============================================================================

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/dot/spinner.sh"

header "AI Agent Server — Redmi Note 10S (Termux Phase)"

run_with_spinner "Update Termux packages" "yes | pkg upgrade -y 2>/dev/null || true"
run_with_spinner "Install package dasar" "pkg install -y proot-distro wget curl openssh git termux-services python tsu 2>/dev/null"

if [ ! -d "$HOME/storage" ]; then
    warn "Meminta akses storage Termux..."
    termux-setup-storage
    sleep 3
fi

PROJECT_DIR="$HOME/myserver"
run_with_spinner "Setup direktori project" "mkdir -p $PROJECT_DIR/{core,services,configs,docs,data/{models,logs,db}}"

if proot-distro list | grep -q "debian.*installed"; then
    log "Debian sudah terinstall."
else
    run_with_spinner "Install Debian Bookworm" "proot-distro install debian"
fi

DEBIAN_HOME="/data/data/com.termux/files/usr/var/lib/proot-distro/installed-rootfs/debian/root"
run_with_spinner "Menyalin file project ke Debian" "mkdir -p $DEBIAN_HOME/myserver && cp -r $PROJECT_DIR/. $DEBIAN_HOME/myserver/ 2>/dev/null || true"

header "Setup Debian environment"
log "Menjalankan ubuntu.sh di dalam Debian..."
proot-distro login debian -- bash /root/myserver/dev/ubuntu.sh

run_with_spinner "Setup autostart (termux-boot)" "mkdir -p $HOME/.termux/boot && echo -e '#!/data/data/com.termux/files/usr/bin/bash\nsleep 10\ntermux-wake-lock\ncd $HOME/myserver\nbash dev/dot/start-server.sh >> $HOME/myserver/data/logs/boot.log 2>&1' > $HOME/.termux/boot/start-server.sh && chmod +x $HOME/.termux/boot/start-server.sh"

log "Setup Termux selesai!"
