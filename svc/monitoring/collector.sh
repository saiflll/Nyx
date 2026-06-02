#!/bin/bash
# =============================================================================
# collector.sh — Metrics collector untuk monitoring
# =============================================================================

# STYLE GUIDE: snake_case + singkatan

WKT_INTVL="${MONITOR_INTERVAL:-10}"
FL_DT="/data/metrics.json"

ambl_dt() {
    local ts=$(date +%s)

    # CPU
    read -r cpu_line < /host/proc/stat
    cpu_values=($cpu_line)
    total=$((${cpu_values[1]} + ${cpu_values[2]} + ${cpu_values[3]} + ${cpu_values[4]} + ${cpu_values[5]} + ${cpu_values[6]} + ${cpu_values[7]}))
    idle=${cpu_values[4]}

    if [ -f /tmp/cpu_prv ]; then
        read prev_total prev_idle < /tmp/cpu_prv
        dt_total=$((total - prev_total))
        dt_idle=$((idle - prev_idle))
        if [ "$dt_total" -gt 0 ]; then
            cpu_pcn=$(echo "scale=1; (($dt_total - $dt_idle) * 100) / $dt_total" | bc)
        else
            cpu_pcn=0
        fi
    else
        cpu_pcn=0
    fi
    echo "$total $idle" > /tmp/cpu_prv

    # RAM
    ram_tot=$(grep MemTotal /host/proc/meminfo | awk '{print $2}')
    ram_bebas=$(grep MemFree /host/proc/meminfo | awk '{print $2}')
    ram_trsd=$(grep MemAvailable /host/proc/meminfo | awk '{print $2}')
    ram_pakai=$((ram_tot - ram_trsd))
    ram_pcn=$(echo "scale=1; ($ram_pakai * 100) / $ram_tot" | bc)

    # Disk /opt/myserver
    dt_disk=$(df -k /data 2>/dev/null | tail -1)
    disk_tot=$(echo "$dt_disk" | awk '{print $2}')
    disk_pakai=$(echo "$dt_disk" | awk '{print $3}')
    disk_bebas=$(echo "$dt_disk" | awk '{print $4}')
    disk_pcn=$(echo "$dt_disk" | awk '{print $5}' | tr -d '%')

    # Suhu CPU
    suhu_cpu=0
    for zone in /host/sys/class/thermal/thermal_zone*/temp; do
        if [ -f "$zone" ]; then
            tmp=$(cat "$zone" 2>/dev/null || echo "0")
            tmp_c=$((tmp / 1000))
            if [ "$tmp_c" -gt "$suhu_cpu" ] && [ "$tmp_c" -lt 150 ]; then
                suhu_cpu=$tmp_c
            fi
        fi
    done

    # Network
    net_rx=0
    net_tx=0
    while IFS= read -r line; do
        if [[ "$line" =~ wlan0|eth0|rmnet ]]; then
            values=($line)
            rx=$(echo "${values[1]}" | tr -d ':')
            tx="${values[9]}"
            net_rx=$((net_rx + rx))
            net_tx=$((net_tx + tx))
        fi
    done < /host/proc/net/dev

    if [ -f /tmp/net_prv ]; then
        read pr_rx pr_tx < /tmp/net_prv
        dl_rx=$(( (net_rx - pr_rx) / WKT_INTVL ))
        dl_tx=$(( (net_tx - pr_tx) / WKT_INTVL ))
    else
        dl_rx=0; dl_tx=0
    fi
    echo "$net_rx $net_tx" > /tmp/net_prv

    # Log size
    ukrn_log=$(du -sk /app/logs 2>/dev/null | awk '{print $1}')
    log_mb=$((ukrn_log / 1024))

    cat > "$FL_DT" << JSON
{
  "timestamp": $ts,
  "cpu": { "usage_percent": $cpu_pcn, "temp_celsius": $suhu_cpu },
  "memory": { "total_kb": $ram_tot, "used_kb": $ram_pakai, "free_kb": $ram_bebas, "usage_percent": $ram_pcn },
  "disk": { "total_kb": $disk_tot, "used_kb": $disk_pakai, "free_kb": $disk_bebas, "usage_percent": $disk_pcn },
  "network": { "rx_bytes_per_sec": $dl_rx, "tx_bytes_per_sec": $dl_tx },
  "logs": { "total_size_mb": $log_mb, "max_allowed_mb": $((${LOG_MAX_SIZE_GB:-30} * 1024)) }
}
JSON
}

echo "Monitoring collector mlu (intvl: ${WKT_INTVL}s)"
while true; do
    ambl_dt
    sleep "$WKT_INTVL"
done
