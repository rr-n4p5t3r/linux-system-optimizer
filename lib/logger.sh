#!/usr/bin/env bash
# =============================================================================
# logger.sh — Sistema de logging para LSO
# =============================================================================
# Linux System Optimizer (LSO)
# Autor: Ricardo Rosero <rrosero2000@gmail.com>
# GitHub: https://github.com/rr-n4p5t3r
# Licencia: MIT
# =============================================================================


LSO_LOG_DIR="${LSO_BASE_DIR}/logs"
LSO_LOG_FILE=""
LSO_MAX_LOG_AGE_DAYS=30

init_logger() {
    if [[ ! -d "$LSO_LOG_DIR" ]]; then
        mkdir -p "$LSO_LOG_DIR" 2>/dev/null || {
            LSO_LOG_DIR="/tmp/lso-logs"
            mkdir -p "$LSO_LOG_DIR"
        }
    fi

    if [[ ! -w "$LSO_LOG_DIR" ]]; then
        LSO_LOG_DIR="/tmp/lso-logs"
        mkdir -p "$LSO_LOG_DIR"
    fi

    LSO_LOG_FILE="${LSO_LOG_DIR}/lso-$(date +%Y%m%d-%H%M%S).log"

    if ! touch "$LSO_LOG_FILE" 2>/dev/null; then
        LSO_LOG_FILE="/dev/null"
        return 0
    fi

    log_write "INFO" "=== Linux System Optimizer iniciado ==="
    log_write "INFO" "Autor: Ricardo Rosero <rrosero2000@gmail.com>"
    log_write "INFO" "GitHub: https://github.com/rr-n4p5t3r"
    log_write "INFO" "PID: $$ | Usuario: $(whoami) | Fecha: $(date)"
    log_write "INFO" "Directorio base: ${LSO_BASE_DIR}"
}

log_write() {
    local level="$1" msg="$2"
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $msg" >> "$LSO_LOG_FILE" 2>/dev/null || true
}

log_info()    { log_write "INFO"    "$1"; print_info "$1"; }
log_success() { log_write "SUCCESS" "$1"; print_success "$1"; }
log_warn()    { log_write "WARN"    "$1"; print_warn "$1"; }
log_error()   { log_write "ERROR"   "$1"; print_error "$1"; }
log_debug()   { log_write "DEBUG"   "$1"; print_debug "$1"; }

rotate_logs() {
    [[ "$LSO_LOG_DIR" == "/dev/null" ]] && return 0
    [[ ! -d "$LSO_LOG_DIR" ]] && return 0
    find "$LSO_LOG_DIR" -name "lso-*.log" -type f -mtime +"$LSO_MAX_LOG_AGE_DAYS" -delete 2>/dev/null || true
    log_debug "Logs antiguos rotados (>${LSO_MAX_LOG_AGE_DAYS} días)"
}
