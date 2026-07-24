#!/usr/bin/env bash
# =============================================================================
# debian.sh — Optimizaciones específicas para Debian
# =============================================================================
# Linux System Optimizer (LSO)
# Autor: Ricardo Rosero <rrosero2000@gmail.com>
# GitHub: https://github.com/rr-n4p5t3r
# Licencia: GPLv3
# =============================================================================

optimize_debian() {
    print_step "Aplicando optimizaciones para Debian..."

    local optional=("exim4" "rpcbind" "nfs-common")
    for svc in "${optional[@]}"; do
        if systemctl is-active --quiet "$svc" 2>/dev/null; then
            if [[ "$LSO_DRY_RUN" != "true" ]]; then
                systemctl stop "$svc" 2>/dev/null || true
                systemctl disable "$svc" 2>/dev/null || true
                log_info "Servicio deshabilitado: $svc"
            fi
        fi
    done

    if [[ -f /etc/apt/apt.conf.d/99local ]]; then
        log_info "APT ya optimizado"
    else
        if [[ "$LSO_DRY_RUN" != "true" ]]; then
            cat > /etc/apt/apt.conf.d/99local << 'APTEOF'
APT::Get::Assume-Yes "true";
APT::Get::Fix-Broken "true";
APT::Periodic::AutocleanInterval "7";
Acquire::Queue-Mode "access";
Acquire::Retries "3";
APTEOF
            log_success "APT optimizado"
        fi
    fi
}
optimize_debian
