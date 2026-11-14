#!/usr/bin/env bash
# =============================================================================
# rhel.sh — Optimizaciones específicas para Red Hat Enterprise Linux
# =============================================================================
# Linux System Optimizer (LSO)
# Autor: Ricardo Rosero <rrosero2000@gmail.com>
# GitHub: https://github.com/rr-n4p5t3r
# Licencia: GPLv3
# =============================================================================

optimize_rhel() {
    print_step "Aplicando optimizaciones para RHEL..."

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
optimize_rhel
