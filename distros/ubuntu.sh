#!/usr/bin/env bash
# =============================================================================
# ubuntu.sh — Optimizaciones específicas para Ubuntu
# =============================================================================
# Linux System Optimizer (LSO)
# Autor: Ricardo Rosero <rrosero2000@gmail.com>
# GitHub: https://github.com/rr-n4p5t3r
# Licencia: GPLv3
# =============================================================================

optimize_ubuntu() {
    print_step "Aplicando optimizaciones para Ubuntu..."

    if ! snap list 2>/dev/null | grep -q .; then
        for svc in "snapd" "snapd.socket" "snapd.seeded"; do
            if systemctl is-active --quiet "$svc" 2>/dev/null; then
                if [[ "$LSO_DRY_RUN" != "true" ]]; then
                    systemctl stop "$svc" 2>/dev/null || true
                    systemctl disable "$svc" 2>/dev/null || true
                    log_info "Snap deshabilitado: $svc"
                fi
            fi
        done
    fi

    if [[ "$LSO_DRY_RUN" != "true" ]]; then
        cat > /etc/apt/apt.conf.d/99lso << 'APTEOF'
APT::Get::Assume-Yes "true";
APT::Get::Fix-Broken "true";
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Download-Upgradeable-Packages "1";
APT::Periodic::AutocleanInterval "7";
Acquire::Queue-Mode "access";
Acquire::Retries "3";
APTEOF
        log_success "APT optimizado para Ubuntu"
    fi
}
optimize_ubuntu
