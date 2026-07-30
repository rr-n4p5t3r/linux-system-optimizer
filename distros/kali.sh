#!/usr/bin/env bash
# =============================================================================
# kali.sh — Optimizaciones específicas para Kali Linux
# =============================================================================
# Linux System Optimizer (LSO)
# Autor: Ricardo Rosero <rrosero2000@gmail.com>
# GitHub: https://github.com/rr-n4p5t3r
# Licencia: GPLv3
# =============================================================================
# Kali es una distro orientada a pentesting: a propósito no se toca ningún
# servicio (muchas herramientas de seguridad dependen de daemons que en
# cualquier otra distro se considerarían "opcionales"). Solo se aplica el
# mismo ajuste de rendimiento de APT que ya usa debian.sh, ya que Kali es
# Debian-based.
# =============================================================================

optimize_kali() {
    print_step "Aplicando optimizaciones para Kali Linux..."

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
optimize_kali
