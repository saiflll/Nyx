#!/bin/bash
# =============================================================================
# svc/qwen_local/start.sh — Start llama.cpp server untuk Qwen2.5
# =============================================================================
set -e

MODEL_DIR="/models"
MODEL_FILE="${QWEN_MODEL_FILE:-Qwen2.5-1.5B-Instruct-Q4_K_M.gguf}"
MODEL_PATH="$MODEL_DIR/$MODEL_FILE"
PORT="${QWEN_PORT:-11434}"
THREADS="${QWEN_THREADS:-4}"
CTX="${QWEN_MAX_CTX:-4096}"

# Cari llama-server binary
LLAMA_BIN=""
for bin_path in /usr/local/bin/llama-server /opt/llama.cpp/llama-server /app/llama-server; do
    if [ -x "$bin_path" ]; then
        LLAMA_BIN="$bin_path"
        break
    fi
done

if [ -z "$LLAMA_BIN" ]; then
    echo "ERROR: llama-server binary tidak ditemukan!"
    echo "Jalankan install-debian.sh untuk menginstallnya."
    exit 1
fi

if [ ! -f "$MODEL_PATH" ]; then
    echo "ERROR: Model tidak ditemukan di $MODEL_PATH"
    echo "Jalankan: bash /root/myserver/svc/qwen_local/download-model.sh"
    exit 1
fi

echo "================================"
echo "  Qwen2.5 Local AI Server"
echo "  Model: $MODEL_FILE"
echo "  Port:  $PORT"
echo "  Threads: $THREADS"
echo "  Context: $CTX tokens"
echo "================================"
echo ""

exec "$LLAMA_BIN" \
    --model "$MODEL_PATH" \
    --host 0.0.0.0 \
    --port "$PORT" \
    --threads "$THREADS" \
    --ctx-size "$CTX" \
    --n-predict -1 \
    --temp "${QWEN_TEMP:-0.1}" \
    --repeat-penalty 1.1 \
    --log-disable \
    --api-key "${QWEN_ACCESS_SECRET:-}" \
    2>&1 | tee /app/logs/qwen.log
