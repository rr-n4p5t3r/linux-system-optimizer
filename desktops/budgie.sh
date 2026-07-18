#!/usr/bin/env bash
# =============================================================================
# budgie.sh — Optimizaciones para Budgie
# =============================================================================
# Linux System Optimizer (LSO)
# Autor: Ricardo Rosero <rrosero2000@gmail.com>
# GitHub: https://github.com/rr-n4p5t3r
# Licencia: MIT
# =============================================================================

optimize_budgie() {
    print_step "Optimizando Budgie..."

    if [[ "$LSO_DRY_RUN" != "true" ]]; then
        gsettings set org.gnome.desktop.interface enable-animations false 2>/dev/null || true

        if command -v tracker &>/dev/null; then
            tracker reset --hard 2>/dev/null || true
        fi

        log_success "Budgie optimizado"
    else
        print_info "[DRY-RUN] Se optimizaría Budgie"
    fi
}
optimize_budgie
