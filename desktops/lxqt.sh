#!/usr/bin/env bash
# =============================================================================
# lxqt.sh — Optimizaciones para LXQt
# =============================================================================
# Linux System Optimizer (LSO)
# Autor: Ricardo Rosero <rrosero2000@gmail.com>
# GitHub: https://github.com/rr-n4p5t3r
# Licencia: GPLv3
# =============================================================================

optimize_lxqt() {
    print_step "Optimizando LXQt..."

    log_info "LXQt es un escritorio ligero — optimizaciones mínimas necesarias"

    if [[ "$LSO_DRY_RUN" != "true" ]]; then
        if command -v picom &>/dev/null; then
            killall picom 2>/dev/null || true
            log_info "Picom (compositor) detenido"
        fi
    fi
}
optimize_lxqt
