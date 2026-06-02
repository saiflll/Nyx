#!/bin/bash
# =============================================================================
# SPINNER.SH — Animasi Loading dengan output wrapping
# =============================================================================

# Definisi warna
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

log()    { echo -e "${GREEN}[✓]${RESET} $1"; }
warn()   { echo -e "${YELLOW}[!]${RESET} $1"; }
error()  { echo -e "${RED}[✗]${RESET} $1"; exit 1; }
header() { echo -e "\n${CYAN}${BOLD}━━━ $1 ━━━${RESET}\n"; }

start_spinner() {
    local msg="$1"
    # Menjalankan command pembungkus di background agar kita bisa menganimasi spinner
    # Spinners symbols
    local spin='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local charwidth=3

    local i=0
    tput sc # Save cursor position
    while kill -0 $2 2>/dev/null; do
        local i=$(((i + charwidth) % ${#spin}))
        tput rc # Restore cursor
        printf "\e[?25l${CYAN}[ %s ]${RESET} %s" "${spin:$i:$charwidth}" "$msg"
        sleep .1
    done
    tput rc
    printf "\e[?25h" # Show cursor
}

# Fungsi pembungkus untuk menjalankan command dengan animasi spinner
run_with_spinner() {
    local msg="$1"
    shift
    local cmd="$@"

    echo -e "${YELLOW}>> Memulai: ${msg}${RESET}"
    
    # Jalankan di background, gabungkan stdout dan stderr
    # Gunakan fmt atau fold untuk membungkus log agar tidak melebar
    eval "$cmd" 2>&1 | fold -w 80 | while read -r line; do
        echo -e "   \033[90m$line\033[0m"
    done &
    local pid=$!

    start_spinner "$msg" $pid
    wait $pid
    local exit_code=$?

    if [ $exit_code -eq 0 ]; then
        echo -e "${GREEN}[ ✓ ]${RESET} $msg ... Selesai!"
    else
        echo -e "${RED}[ ✗ ]${RESET} $msg ... Gagal! (Kode: $exit_code)"
        exit $exit_code
    fi
}
