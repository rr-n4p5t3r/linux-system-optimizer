#!/usr/bin/env bash
# =============================================================================
# freebsd.sh — Soporte EXPERIMENTAL para FreeBSD
# =============================================================================
# Linux System Optimizer (LSO)
# Autor: Ricardo Rosero <rrosero2000@gmail.com>
# GitHub: https://github.com/rr-n4p5t3r
# Licencia: GPLv3
# =============================================================================
# FreeBSD NO es una distribución de Linux — es otro sistema operativo (kernel
# BSD, sin systemd, sin /proc ni /sys). LSO detecta FreeBSD y soporta el
# gestor de paquetes `pkg` (ver package_managers/pkg.sh), pero la gran
# mayoría de los módulos del core son Linux-específicos y NO funcionan acá:
# service_manager, swap, zram, journal_optimizer, memory_optimizer y
# security dependen de systemctl, /proc o /sys. Este script se limita a
# información y ajustes que sí son válidos en FreeBSD. No ejecutes perfiles
# completos (`lso optimize`) en FreeBSD todavía — usa `lso detect` y
# `lso module package_optimizer` como mucho.
# =============================================================================

optimize_freebsd() {
    print_step "Verificando FreeBSD (soporte experimental)..."
    print_warn "Muchos módulos de LSO son Linux-específicos y no aplican en FreeBSD"

    local bsd_version
    bsd_version=$(uname -r 2>/dev/null || echo "desconocida")
    log_info "Versión de FreeBSD: ${bsd_version}"

    if command -v pkg &>/dev/null; then
        local pkg_count
        pkg_count=$(pkg info 2>/dev/null | wc -l)
        log_info "Paquetes instalados (pkg): ${pkg_count}"
    fi

    print_success "Verificación de FreeBSD completada"
}
optimize_freebsd
