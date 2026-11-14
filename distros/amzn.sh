#!/usr/bin/env bash
# =============================================================================
# amzn.sh — Optimizaciones específicas para Amazon Linux
# =============================================================================
# Linux System Optimizer (LSO)
# Autor: Ricardo Rosero <rrosero2000@gmail.com>
# GitHub: https://github.com/rr-n4p5t3r
# Licencia: GPLv3
# =============================================================================

optimize_amzn() {
    print_step "Aplicando optimizaciones para Amazon Linux..."

    if [[ "$LSO_DRY_RUN" != "true" ]]; then
        lso_tune_dnf_conf /etc/dnf/dnf.conf deltarpm
        log_success "DNF optimizado"
    fi

    if systemctl is-active --quiet "dnf-makecache.timer" 2>/dev/null; then
        if [[ "$LSO_DRY_RUN" != "true" ]]; then
            systemctl stop "dnf-makecache.timer" 2>/dev/null || true
            log_info "Detenido: dnf-makecache.timer"
        fi
    fi
}
optimize_amzn
