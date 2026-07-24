#!/usr/bin/env bash
# =============================================================================
# zorin.sh — Optimizaciones específicas para Zorin OS
# =============================================================================
# Linux System Optimizer (LSO)
# Autor: Ricardo Rosero <rrosero2000@gmail.com>
# GitHub: https://github.com/rr-n4p5t3r
# Licencia: GPLv3
# =============================================================================

optimize_zorin() {
    print_step "Aplicando optimizaciones para Zorin OS..."

    log_info "Zorin desktop detectado"

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
optimize_zorin
