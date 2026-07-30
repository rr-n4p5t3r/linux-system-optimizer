#!/usr/bin/env bash
# =============================================================================
# gentoo.sh — Optimizaciones específicas para Gentoo
# =============================================================================
# Linux System Optimizer (LSO)
# Autor: Ricardo Rosero <rrosero2000@gmail.com>
# GitHub: https://github.com/rr-n4p5t3r
# Licencia: GPLv3
# =============================================================================

optimize_gentoo() {
    print_step "Aplicando optimizaciones para Gentoo..."

    local make_conf="/etc/portage/make.conf"

    if [[ -f "$make_conf" ]] && [[ "$LSO_DRY_RUN" != "true" ]]; then
        backup_file "$make_conf" 2>/dev/null || true

        if grep -q "^MAKEOPTS=" "$make_conf" 2>/dev/null; then
            sed -i "s/^MAKEOPTS=.*/MAKEOPTS=\"-j$(nproc)\"/" "$make_conf"
        else
            echo "MAKEOPTS=\"-j$(nproc)\"" >> "$make_conf"
        fi

        log_success "MAKEOPTS ajustado en $make_conf"
    fi
}
optimize_gentoo
