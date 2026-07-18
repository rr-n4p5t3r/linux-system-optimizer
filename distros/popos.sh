#!/usr/bin/env bash
# =============================================================================
# popos.sh — Optimizaciones específicas para Pop!_OS
# =============================================================================
# Linux System Optimizer (LSO)
# Autor: Ricardo Rosero <rrosero2000@gmail.com>
# GitHub: https://github.com/rr-n4p5t3r
# Licencia: MIT
# =============================================================================

optimize_popos() {
    print_step "Aplicando optimizaciones para Pop!_OS..."

    if [[ -d /boot/efi/loader ]]; then
        log_info "Systemd-boot detectado"
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

    if [[ "$LSO_GPU" == *"NVIDIA"* ]] || [[ "$LSO_GPU" == *"nvidia"* ]]; then
        log_info "GPU NVIDIA detectada — Pop!_OS tiene drivers optimizados"
    fi
}
optimize_popos
