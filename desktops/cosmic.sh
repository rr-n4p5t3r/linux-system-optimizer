#!/usr/bin/env bash
# =============================================================================
# cosmic.sh — Optimizaciones para COSMIC (System76)
# =============================================================================
# Linux System Optimizer (LSO)
# Autor: Ricardo Rosero <rrosero2000@gmail.com>
# GitHub: https://github.com/rr-n4p5t3r
# Licencia: MIT
# =============================================================================

optimize_cosmic() {
    print_step "Optimizando COSMIC..."

    log_info "COSMIC desktop detectado — optimizaciones limitadas por ahora"

    if [[ "$LSO_DRY_RUN" != "true" ]]; then
        if systemctl is-active --quiet pop-shell 2>/dev/null; then
            log_info "Pop-shell tiling activo"
        fi
    fi
}
optimize_cosmic
