#!/usr/bin/env bash
# =============================================================================
# nobara.sh — Optimizaciones específicas para Nobara
# =============================================================================
# Linux System Optimizer (LSO)
# Autor: Ricardo Rosero <rrosero2000@gmail.com>
# GitHub: https://github.com/rr-n4p5t3r
# Licencia: MIT
# =============================================================================

optimize_nobara() {
    print_step "Aplicando optimizaciones para Nobara..."

    log_info "Nobara ya incluye optimizaciones de gaming por defecto"

    if command -v gamemoded &>/dev/null; then
        log_info "Gamemode detectado — ya configurado para gaming"
    fi

    source "${LSO_BASE_DIR}/distros/fedora.sh" 2>/dev/null || true
}
optimize_nobara
