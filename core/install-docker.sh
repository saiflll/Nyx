#!/bin/bash
# =============================================================================
# core/install-docker.sh — Install Podman + Podman-Compose di Debian
# (Podman dipilih karena kompatibilitas lebih baik dengan kernel Android)
# =============================================================================
set -euo pipefail

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'
log()    { echo -e "${GREEN}[✓]${RESET} $1"; }
warn()   { echo -e "${YELLOW}[!]${RESET} $1"; }
error()  { echo -e "${RED}[✗]${RESET} $1"; exit 1; }
header() { echo -e "\n${CYAN}${BOLD}━━━ $1 ━━━${RESET}\n"; }

# =============================================================================
# Install Podman
# =============================================================================
header "Install Podman"

export DEBIAN_FRONTEND=noninteractive

# Podman tersedia di Debian Bookworm langsung
apt-get install -y podman podman-compose 2>&1 | tail -5

# Verifikasi
if command -v podman &>/dev/null; then
    log "Podman $(podman --version) terinstall."
else
    error "Podman gagal diinstall."
fi

# =============================================================================
# Konfigurasi Podman untuk Android/proot
# =============================================================================
header "Konfigurasi Podman untuk proot"

mkdir -p /etc/containers

# Konfigurasi storage — pakai vfs driver (lebih compatible dengan Android kernel)
cat > /etc/containers/storage.conf << 'EOF'
[storage]
  driver = "vfs"
  graphRoot = "/opt/myserver/podman-storage"
  runRoot = "/run/containers/storage"

[storage.options]
  size = ""

[storage.options.overlay]
  mountopt = "nodev,metacopy=on"
EOF

# Registries
cat > /etc/containers/registries.conf << 'EOF'
[registries.search]
registries = ['docker.io', 'ghcr.io', 'quay.io']

[registries.insecure]
registries = []

[registries.block]
registries = []
EOF

# Policy
cat > /etc/containers/policy.json << 'EOF'
{
    "default": [{"type": "insecureAcceptAnything"}]
}
EOF

# =============================================================================
# Alias docker -> podman
# =============================================================================
header "Setup alias docker"

cat >> /etc/bash.bashrc << 'EOF'

# Docker -> Podman aliases
alias docker='podman'
alias docker-compose='podman-compose'
export DOCKER_HOST="unix:///run/podman/podman.sock"
EOF

# Buat symlink
ln -sf /usr/bin/podman /usr/local/bin/docker 2>/dev/null || true

# =============================================================================
# Install Podman-Compose jika belum ada
# =============================================================================
header "Install podman-compose"

if ! command -v podman-compose &>/dev/null; then
    pip3 install podman-compose 2>&1 | tail -5
fi

log "podman-compose $(podman-compose --version 2>&1 | head -1) siap."

# =============================================================================
# Test
# =============================================================================
header "Test Podman"

log "Test pull & run hello-world..."
if podman run --rm docker.io/library/hello-world 2>&1 | grep -q "Hello from Docker"; then
    log "Podman berjalan dengan baik!"
else
    warn "Test hello-world gagal, tapi Podman mungkin masih bisa berjalan. Cek kernel support."
fi

echo ""
log "=== Podman siap! ==="
echo ""
echo "  Catatan penting:"
echo "  - Driver storage: VFS (kompatibel dengan kernel Android)"
echo "  - Jalankan 'docker' = sama dengan 'podman'"
echo "  - Compose file: /root/myserver/core/docker-compose.yml"
