#!/bin/bash
# =============================================================================
# cleanup.sh — Auto-hapus log yang tidak berguna
# Dijalankan setiap 6 jam via cron
#
# LOGIKA:
#   - Hitung total ukuran semua log
#   - Jika > 80% dari LOG_MAX_SIZE_GB (default 30GB):
#     - Cek frekuensi akses setiap file log (via atime)
#     - Hapus yang tidak diakses > LOG_KEEP_DAYS (default 7 hari)
#     - KECUALI file yang sering diakses dalam 24 jam terakhir
#   - Log file yang terkompres dan tidak aktif bisa dihapus lebih agresif
# =============================================================================

LOG_DIR="/opt/myserver/logs"
MAX_GB="${LOG_MAX_SIZE_GB:-30}"
KEEP_DAYS="${LOG_KEEP_DAYS:-7}"
MAX_BYTES=$((MAX_GB * 1024 * 1024 * 1024))
THRESHOLD_PERCENT=80

# --- Logging untuk cleanup sendiri ---
CLEANUP_LOG="$LOG_DIR/system/cleanup.log"
timestamp() { date '+%Y-%m-%d %H:%M:%S'; }
log() { echo "[$(timestamp)] $1" | tee -a "$CLEANUP_LOG"; }

log "=== Log Cleanup dimulai ==="

# =============================================================================
# HITUNG TOTAL UKURAN LOG
# =============================================================================

total_bytes=$(du -sb "$LOG_DIR" 2>/dev/null | awk '{print $1}')
total_gb=$(echo "scale=2; $total_bytes / 1024 / 1024 / 1024" | bc)
usage_percent=$(echo "scale=0; $total_bytes * 100 / $MAX_BYTES" | bc)

log "Total log: ${total_gb}GB / ${MAX_GB}GB (${usage_percent}%)"

# Jika masih di bawah threshold, tidak perlu cleanup
if [ "$usage_percent" -lt "$THRESHOLD_PERCENT" ]; then
    log "Penggunaan log masih aman (< ${THRESHOLD_PERCENT}%), skip cleanup."
    log "=== Cleanup selesai ==="
    exit 0
fi

log "⚠ Penggunaan log mencapai ${usage_percent}%, mulai cleanup..."

# =============================================================================
# FASE 1: Hapus file .gz yang sangat lama (> 3x KEEP_DAYS)
# =============================================================================

AGGRESSIVE_DAYS=$((KEEP_DAYS * 3))
log "Hapus file compressed yang lebih dari ${AGGRESSIVE_DAYS} hari..."

deleted=0
freed=0

while IFS= read -r file; do
    # Cek apakah file diakses dalam aggressive_days terakhir
    last_access=$(stat -c '%X' "$file" 2>/dev/null || echo "0")
    now=$(date +%s)
    age_days=$(( (now - last_access) / 86400 ))

    if [ "$age_days" -gt "$AGGRESSIVE_DAYS" ]; then
        size=$(stat -c '%s' "$file" 2>/dev/null || echo "0")
        freed=$((freed + size))
        deleted=$((deleted + 1))
        log "  Hapus: $file (tidak diakses ${age_days} hari)"
        rm -f "$file"
    fi
done < <(find "$LOG_DIR" -name "*.gz" -o -name "*.log.[0-9]*" 2>/dev/null)

log "Fase 1: Dihapus ${deleted} file (freed: $(echo "scale=2; $freed/1024/1024" | bc)MB)"

# =============================================================================
# FASE 2: Hapus file log biasa yang lebih dari KEEP_DAYS dan tidak aktif
# =============================================================================

log "Cek file log yang tidak aktif (> ${KEEP_DAYS} hari)..."

deleted2=0
freed2=0

while IFS= read -r file; do
    last_access=$(stat -c '%X' "$file" 2>/dev/null || echo "0")
    now=$(date +%s)
    age_days=$(( (now - last_access) / 86400 ))

    # JANGAN hapus jika diakses dalam 24 jam terakhir
    # (mungkin sedang dimonitor atau dianalisis)
    if [ "$age_days" -lt 1 ]; then
        continue
    fi

    # Hapus jika lebih dari KEEP_DAYS dan tidak aktif
    if [ "$age_days" -gt "$KEEP_DAYS" ]; then
        size=$(stat -c '%s' "$file" 2>/dev/null || echo "0")
        freed2=$((freed2 + size))
        deleted2=$((deleted2 + 1))
        log "  Hapus: $file (tidak aktif ${age_days} hari)"
        > "$file"  # Kosongkan tapi jangan hapus (agar proses yang masih write tidak error)
    fi
done < <(find "$LOG_DIR" -name "*.log" -not -name "cleanup.log" 2>/dev/null)

log "Fase 2: Dikosongkan ${deleted2} file (freed: $(echo "scale=2; $freed2/1024/1024" | bc)MB)"

# =============================================================================
# HITUNG ULANG
# =============================================================================

new_total=$(du -sb "$LOG_DIR" 2>/dev/null | awk '{print $1}')
new_gb=$(echo "scale=2; $new_total / 1024 / 1024 / 1024" | bc)
new_percent=$(echo "scale=0; $new_total * 100 / $MAX_BYTES" | bc)

log "Setelah cleanup: ${new_gb}GB / ${MAX_GB}GB (${new_percent}%)"
log "Total freed: $(echo "scale=2; ($total_bytes - $new_total) / 1024 / 1024" | bc)MB"
log "=== Cleanup selesai ==="

# =============================================================================
# FASE 3: Jika MASIH terlalu penuh (> 90%), paksa hapus yang terlama
# =============================================================================

CRITICAL_PERCENT=90
if [ "$new_percent" -gt "$CRITICAL_PERCENT" ]; then
    log "🔴 KRITIS: Log masih ${new_percent}%! Paksa hapus file terlama..."

    # Hapus file terlama sampai di bawah 70%
    TARGET_PERCENT=70
    TARGET_BYTES=$((MAX_BYTES * TARGET_PERCENT / 100))

    while IFS= read -r file; do
        current=$(du -sb "$LOG_DIR" 2>/dev/null | awk '{print $1}')
        if [ "$current" -le "$TARGET_BYTES" ]; then
            break
        fi
        log "  Force hapus: $file"
        rm -f "$file"
    done < <(find "$LOG_DIR" -type f \( -name "*.log" -o -name "*.gz" \) \
        -not -name "cleanup.log" \
        -printf '%T+ %p\n' 2>/dev/null | sort | awk '{print $2}')

    final_total=$(du -sb "$LOG_DIR" 2>/dev/null | awk '{print $1}')
    final_gb=$(echo "scale=2; $final_total / 1024 / 1024 / 1024" | bc)
    log "Setelah force cleanup: ${final_gb}GB"
fi
