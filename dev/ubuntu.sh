#!/bin/bash
# =============================================================================
# DEV/UBUNTU.SH — Konfigurasi Debian Bookworm di dalam proot
# =============================================================================

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/dot/spinner.sh"

header "Update Debian Bookworm"

# Set DNS
echo "nameserver 1.1.1.1" > /etc/resolv.conf
echo "nameserver 8.8.8.8" >> /etc/resolv.conf
export DEBIAN_FRONTEND=noninteractive

run_with_spinner "Update apt package list" "apt-get update -y"
run_with_spinner "Upgrade Debian packages" "apt-get upgrade -y"
run_with_spinner "Install package esensial" "apt-get install -y curl wget git vim nano ca-certificates gnupg sudo procps build-essential python3 python3-pip python3-venv golang net-tools iproute2 logrotate cron jq htop lsof rclone"

header "Install cloudflared"
if ! command -v cloudflared &>/dev/null; then
    run_with_spinner "Download cloudflared ARM64" "wget -q https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64 -O /usr/local/bin/cloudflared && chmod +x /usr/local/bin/cloudflared"
else
    log "cloudflared sudah terinstall."
fi

header "Install llama.cpp server"
LLAMA_DIR="/opt/llama.cpp"
if [ ! -f "$LLAMA_DIR/llama-server" ]; then
    run_with_spinner "Download llama-server (ARM64)" "mkdir -p $LLAMA_DIR && LLAMA_LATEST=\$(curl -sL -o /dev/null -w '%{url_effective}' https://github.com/ggerganov/llama.cpp/releases/latest | grep -o 'tag/[^\"*]*' | head -1 | sed 's/tag\///') && wget -q https://github.com/ggerganov/llama.cpp/releases/download/\${LLAMA_LATEST}/llama-\${LLAMA_LATEST}-bin-ubuntu-arm64.zip -O /tmp/llama.zip && cd /tmp && unzip -q llama.zip -d llama_bin && cp /tmp/llama_bin/build/bin/llama-server $LLAMA_DIR/ || find /tmp/llama_bin -name 'llama-server' -exec cp {} $LLAMA_DIR/ \\; && chmod +x $LLAMA_DIR/llama-server && rm -rf /tmp/llama.zip /tmp/llama_bin"
else
    log "llama-server sudah ada."
fi

header "Setup user dan direktori"
if ! id "aiserver" &>/dev/null; then
    run_with_spinner "Buat user aiserver" "useradd -m -s /bin/bash aiserver && echo 'aiserver ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers"
fi
run_with_spinner "Setup direktori /opt/myserver" "mkdir -p /opt/myserver/{models,logs/{ai-router,qwen,storage,monitor,system},data,tmp} && chmod -R 755 /opt/myserver && chown -R aiserver:aiserver /opt/myserver"

header "Setup cron jobs"
run_with_spinner "Konfigurasi cron" "echo -e '0 */6 * * * root /root/myserver/configs/log-management/cleanup.sh >> /opt/myserver/logs/system/cleanup.log 2>&1\n0 2 * * * root logrotate /root/myserver/configs/log-management/logrotate.conf\n*/5 * * * * aiserver /root/myserver/configs/health-check.sh >> /opt/myserver/logs/system/health.log 2>&1' > /etc/cron.d/myserver && chmod 644 /etc/cron.d/myserver"

header "Install Podman"
run_with_spinner "Install Docker/Podman env" "bash /root/myserver/core/install-docker.sh"

log "Setup Ubuntu/Debian selesai! Jalankan bash dev/dot/start-server.sh"
