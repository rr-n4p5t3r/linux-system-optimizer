#!/usr/bin/env bash
# =============================================================================
# mxlinux.sh — Optimizaciones específicas para MX Linux
# =============================================================================
# Linux System Optimizer (LSO)
# Autor: Ricardo Rosero <rrosero2000@gmail.com>
# GitHub: https://github.com/rr-n4p5t3r
# Licencia: MIT
# =============================================================================

optimize_mxlinux() {
    print_step "Aplicando optimizaciones para MX Linux..."

    if [[ -d /run/systemd/system ]]; then
        log_info "Systemd detectado en MX Linux"
    else
        log_info "SysVinit detectado — optimizaciones limitadas"
    fi

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
optimize_mxlinux
