#!/usr/bin/env bash
# =============================================================================
# almalinux.sh — Optimizaciones específicas para AlmaLinux
# =============================================================================
# Linux System Optimizer (LSO)
# Autor: Ricardo Rosero <rrosero2000@gmail.com>
# GitHub: https://github.com/rr-n4p5t3r
# Licencia: GPLv3
# =============================================================================

optimize_almalinux() {
    print_step "Aplicando optimizaciones para AlmaLinux..."

    if [[ "$LSO_DRY_RUN" != "true" ]]; then
        lso_tune_dnf_conf /etc/dnf/dnf.conf
    fi
}
optimize_almalinux
