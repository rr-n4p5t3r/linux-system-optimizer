#!/usr/bin/env bash
# =============================================================================
# slackware.sh — Optimizaciones específicas para Slackware
# =============================================================================
# Linux System Optimizer (LSO)
# Autor: Ricardo Rosero <rrosero2000@gmail.com>
# GitHub: https://github.com/rr-n4p5t3r
# Licencia: GPLv3
# =============================================================================
# Slackware no usa systemd (init scripts en /etc/rc.d) — a propósito no se
# llama a systemctl acá, y los ajustes son mínimos y conservadores.
# =============================================================================

optimize_slackware() {
    print_step "Aplicando optimizaciones para Slackware..."

    local enabled=0
    local disabled=0
    for rc in /etc/rc.d/rc.*; do
        [[ -f "$rc" ]] || continue
        [[ -x "$rc" ]] && ((enabled++)) || ((disabled++))
    done

    log_info "Scripts de arranque en /etc/rc.d: ${enabled} habilitados, ${disabled} deshabilitados"
    print_success "Verificación de Slackware completada"
}
optimize_slackware
