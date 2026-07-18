#!/usr/bin/env bash
# =============================================================================
# cinnamon.sh — Optimizaciones para Cinnamon
# =============================================================================
# Linux System Optimizer (LSO)
# Autor: Ricardo Rosero <rrosero2000@gmail.com>
# GitHub: https://github.com/rr-n4p5t3r
# Licencia: MIT
# =============================================================================

optimize_cinnamon() {
    print_step "Optimizando Cinnamon..."

    if [[ "$LSO_DRY_RUN" != "true" ]]; then
        gsettings set org.cinnamon.muffin unredirect-fullscreen-windows true 2>/dev/null || true
        gsettings set org.cinnamon.desktop.interface enable-animations false 2>/dev/null || true

        if command -v tracker &>/dev/null; then
            tracker reset --hard 2>/dev/null || true
        fi

        log_success "Cinnamon optimizado"
    else
        print_info "[DRY-RUN] Se optimizaría Cinnamon"
    fi
}
optimize_cinnamon
