#!/usr/bin/env bash
# =============================================================================
# rocky.sh — Optimizaciones específicas para Rocky Linux
# =============================================================================
# Linux System Optimizer (LSO)
# Autor: Ricardo Rosero <rrosero2000@gmail.com>
# GitHub: https://github.com/rr-n4p5t3r
# Licencia: GPLv3
# =============================================================================

optimize_rocky() {
    print_step "Aplicando optimizaciones para Rocky Linux..."

    if [[ "$LSO_DRY_RUN" != "true" ]]; then
        lso_tune_dnf_conf /etc/dnf/dnf.conf
    fi
}
optimize_rocky
