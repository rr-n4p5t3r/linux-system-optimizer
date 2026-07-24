#!/usr/bin/env bash
# =============================================================================
# xfce.sh — Optimizaciones para XFCE
# =============================================================================
# Linux System Optimizer (LSO)
# Autor: Ricardo Rosero <rrosero2000@gmail.com>
# GitHub: https://github.com/rr-n4p5t3r
# Licencia: GPLv3
# =============================================================================

optimize_xfce() {
    print_step "Optimizando XFCE..."

    if [[ "$LSO_DRY_RUN" != "true" ]]; then
        xfconf-query -c xfwm4 -p /general/use_compositing -s false 2>/dev/null || true
        xfconf-query -c thunar-volman -p /automount-drives/enabled -s false 2>/dev/null || true

        log_success "XFCE optimizado"
    else
        print_info "[DRY-RUN] Se optimizaría XFCE"
    fi
}
optimize_xfce
