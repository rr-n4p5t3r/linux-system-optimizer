#!/usr/bin/env bash
# =============================================================================
# arch.sh — Optimizaciones específicas para Arch Linux
# =============================================================================
# Linux System Optimizer (LSO)
# Autor: Ricardo Rosero <rrosero2000@gmail.com>
# GitHub: https://github.com/rr-n4p5t3r
# Licencia: GPLv3
# =============================================================================

optimize_arch() {
    print_step "Aplicando optimizaciones para Arch Linux..."

    if [[ "$LSO_DRY_RUN" != "true" ]]; then
        local makepkg_conf="/etc/makepkg.conf"
        if [[ -f "$makepkg_conf" ]]; then
            backup_file "$makepkg_conf" 2>/dev/null || true

            sed -i "s/^#*MAKEFLAGS=.*/MAKEFLAGS="-j$(nproc)"/" "$makepkg_conf"
            sed -i 's/^COMPRESSXZ=.*/COMPRESSXZ=(xz -c -z - --threads=0)/' "$makepkg_conf"

            log_success "makepkg optimizado"
        fi
    fi

    if [[ "$LSO_DRY_RUN" != "true" ]]; then
        mkdir -p /etc/pacman.d/hooks
        cat > /etc/pacman.d/hooks/99lso.hook << 'PACMANEOF'
[Trigger]
Operation = Upgrade
Type = Package
Target = *

[Action]
Description = Limpiando cache antiguo...
When = PostTransaction
Exec = /usr/bin/paccache -rk3
PACMANEOF
        log_success "Hook de pacman configurado"
    fi
}
optimize_arch
