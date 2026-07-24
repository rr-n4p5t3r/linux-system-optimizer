#!/usr/bin/env bash
# =============================================================================
# colors.sh — Utilidades de colores y formato para LSO
# =============================================================================
# Linux System Optimizer (LSO)
# Autor: Ricardo Rosero <rrosero2000@gmail.com>
# GitHub: https://github.com/rr-n4p5t3r
# Licencia: GPLv3
# =============================================================================


# --- Códigos de color ANSI ---
# Paleta completa expuesta como utilidad para módulos y plugins de terceros;
# no todos los colores se consumen dentro del propio core.
readonly C_RESET='\033[0m'
readonly C_BOLD='\033[1m'
readonly C_DIM='\033[2m'
readonly C_RED='\033[0;31m'
readonly C_GREEN='\033[0;32m'
readonly C_YELLOW='\033[0;33m'
readonly C_BLUE='\033[0;34m'
# shellcheck disable=SC2034
readonly C_MAGENTA='\033[0;35m'
readonly C_CYAN='\033[0;36m'
readonly C_WHITE='\033[0;37m'
# shellcheck disable=SC2034
readonly C_BG_RED='\033[41m'
# shellcheck disable=SC2034
readonly C_BG_GREEN='\033[42m'
# shellcheck disable=SC2034
readonly C_BG_YELLOW='\033[43m'

# --- Funciones de impresión con color ---
print_header()  { echo -e "${C_BOLD}${C_BLUE}\n=== $1 ===${C_RESET}"; }
print_success() { echo -e "${C_GREEN}✓ $1${C_RESET}"; }
print_error()   { echo -e "${C_RED}✗ $1${C_RESET}" >&2; }
print_warn()    { echo -e "${C_YELLOW}⚠ $1${C_RESET}"; }
print_info()    { echo -e "${C_CYAN}ℹ $1${C_RESET}"; }
print_step()    { echo -e "${C_BOLD}${C_WHITE}→ $1${C_RESET}"; }
print_debug()   { [[ "${LSO_DEBUG:-0}" == "1" ]] && echo -e "${C_DIM}[DEBUG] $1${C_RESET}"; }

# --- Barras de progreso ---
progress_bar() {
    local current=$1 total=$2 width=${3:-40}
    local percent=$((current * 100 / total))
    local filled=$((current * width / total))
    local empty=$((width - filled))
    printf "\r${C_CYAN}["
    printf "%${filled}s" | tr ' ' '█'
    printf "%${empty}s" | tr ' ' '░'
    printf "]${C_RESET} %3d%%" "$percent"
    [[ "$current" -eq "$total" ]] && echo
}
