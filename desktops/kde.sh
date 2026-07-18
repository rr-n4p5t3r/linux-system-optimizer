#!/usr/bin/env bash
# =============================================================================
# kde.sh — Optimizaciones para KDE Plasma
# =============================================================================
# Linux System Optimizer (LSO)
# Autor: Ricardo Rosero <rrosero2000@gmail.com>
# GitHub: https://github.com/rr-n4p5t3r
# Licencia: MIT
# =============================================================================

optimize_kde() {
    print_step "Optimizando KDE Plasma..."

    if [[ "$LSO_DRY_RUN" != "true" ]]; then
        if command -v balooctl &>/dev/null; then
            balooctl suspend 2>/dev/null || true
            balooctl disable 2>/dev/null || true
            log_info "Baloo (indexación) deshabilitado"
        fi

        kwriteconfig5 --file kwinrc --group Compositing --key Enabled false 2>/dev/null || true

        if command -v akonadictl &>/dev/null; then
            akonadictl stop 2>/dev/null || true
            log_info "Akonadi detenido"
        fi

        log_success "KDE Plasma optimizado"
    else
        print_info "[DRY-RUN] Se optimizaría KDE Plasma"
    fi
}
optimize_kde
