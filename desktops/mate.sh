#!/usr/bin/env bash
# =============================================================================
# mate.sh — Optimizaciones para MATE
# =============================================================================
# Linux System Optimizer (LSO)
# Autor: Ricardo Rosero <rrosero2000@gmail.com>
# GitHub: https://github.com/rr-n4p5t3r
# Licencia: MIT
# =============================================================================

optimize_mate() {
    print_step "Optimizando MATE..."

    if [[ "$LSO_DRY_RUN" != "true" ]]; then
        gsettings set org.mate.interface enable-animations false 2>/dev/null || true

        if command -v tracker &>/dev/null; then
            tracker reset --hard 2>/dev/null || true
        fi

        log_success "MATE optimizado"
    else
        print_info "[DRY-RUN] Se optimizaría MATE"
    fi
}
optimize_mate
