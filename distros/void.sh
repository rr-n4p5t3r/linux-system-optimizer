#!/usr/bin/env bash
# =============================================================================
# void.sh — Optimizaciones específicas para Void Linux
# =============================================================================
# Linux System Optimizer (LSO)
# Autor: Ricardo Rosero <rrosero2000@gmail.com>
# GitHub: https://github.com/rr-n4p5t3r
# Licencia: GPLv3
# =============================================================================
# Void usa runit, no systemd — a propósito no se llama a systemctl acá.
# =============================================================================

optimize_void() {
    print_step "Aplicando optimizaciones para Void Linux..."

    if [[ -d /var/cache/xbps ]]; then
        local cache_size=""
        cache_size=$(du -sh /var/cache/xbps 2>/dev/null | cut -f1)
        echo -e "  ${C_DIM}Caché de xbps:${C_RESET} ${C_CYAN}${cache_size:-N/A}${C_RESET}"
    fi

    if [[ -d /etc/runit/runsvdir/default ]]; then
        local svc_count=""
        svc_count=$(find /etc/runit/runsvdir/default -maxdepth 1 -type l 2>/dev/null | wc -l)
        log_info "Servicios runit activos: ${svc_count}"
    fi

    log_success "Verificación de Void Linux completada"
}
optimize_void
