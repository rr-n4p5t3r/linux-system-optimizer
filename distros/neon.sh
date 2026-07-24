#!/usr/bin/env bash
# =============================================================================
# neon.sh — Optimizaciones específicas para KDE Neon
# =============================================================================
# Linux System Optimizer (LSO)
# Autor: Ricardo Rosero <rrosero2000@gmail.com>
# GitHub: https://github.com/rr-n4p5t3r
# Licencia: GPLv3
# =============================================================================

optimize_neon() {
    print_step "Aplicando optimizaciones para KDE Neon..."

    log_info "KDE Plasma latest en Neon detectado"

    if [[ "$LSO_DRY_RUN" != "true" ]]; then
        cat > /etc/apt/apt.conf.d/99lso << 'APTEOF'
APT::Get::Assume-Yes "true";
APT::Get::Fix-Broken "true";
APT::Periodic::AutocleanInterval "7";
Acquire::Queue-Mode "access";
Acquire::Retries "3";
APTEOF
    fi
}
optimize_neon
