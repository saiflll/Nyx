#!/bin/bash
# =============================================================================
# svc/qwen_local/download-model.sh
# Download model Qwen2.5 dari HuggingFace
# =============================================================================
set -e

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; RESET='\033[0m'
log()   { echo -e "${GREEN}[✓]${RESET} $1"; }
warn()  { echo -e "${YELLOW}[!]${RESET} $1"; }
error() { echo -e "${RED}[✗]${RESET} $1"; exit 1; }

MODEL_SIZE="${1:-1.5B}"   # Argument: 1.5B atau 3B
MODEL_DIR="/opt/myserver/models"
mkdir -p "$MODEL_DIR"

if [ "$MODEL_SIZE" = "3B" ]; then
    MODEL_FILE="Qwen2.5-3B-Instruct-Q4_K_M.gguf"
    MODEL_URL="https://huggingface.co/Qwen/Qwen2.5-3B-Instruct-GGUF/resolve/main/qwen2.5-3b-instruct-q4_k_m.gguf"
    SIZE_HINT="~2.0GB"
else
    MODEL_FILE="Qwen2.5-1.5B-Instruct-Q4_K_M.gguf"
    MODEL_URL="https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/qwen2.5-1.5b-instruct-q4_k_m.gguf"
    SIZE_HINT="~1.2GB"
fi

TARGET="$MODEL_DIR/$MODEL_FILE"

if [ -f "$TARGET" ]; then
    warn "Model $MODEL_FILE sudah ada di $TARGET"
    echo "  Hapus dulu jika mau download ulang: rm $TARGET"
    exit 0
fi

log "Download Qwen2.5-${MODEL_SIZE} ($SIZE_HINT)..."
log "URL: $MODEL_URL"
echo ""

# Resume download jika terputus (-c flag)
wget \
    --progress=bar:force \
    --retry-connrefused \
    --tries=10 \
    --waitretry=5 \
    -c \
    "$MODEL_URL" \
    -O "$TARGET"

log "Download selesai: $TARGET"
log "Ukuran: $(du -sh "$TARGET" | cut -f1)"
