#!/usr/bin/env bash
# =============================================================================
# fedora.sh — Optimizaciones específicas para Fedora
# =============================================================================
# Linux System Optimizer (LSO)
# Autor: Ricardo Rosero <rrosero2000@gmail.com>
# GitHub: https://github.com/rr-n4p5t3r
# Licencia: GPLv3
# =============================================================================

optimize_fedora() {
    print_step "Aplicando optimizaciones para Fedora..."

    if [[ "$LSO_DRY_RUN" != "true" ]]; then
        lso_tune_dnf_conf /etc/dnf/dnf.conf deltarpm
        log_success "DNF optimizado"
    fi

    local optional=("dnf-makecache.timer" "flatpak-system-helper")
    for svc in "${optional[@]}"; do
        if systemctl is-active --quiet "$svc" 2>/dev/null; then
            if [[ "$LSO_DRY_RUN" != "true" ]]; then
                systemctl stop "$svc" 2>/dev/null || true
                log_info "Detenido: $svc"
            fi
        fi
    done
}
optimize_fedora
