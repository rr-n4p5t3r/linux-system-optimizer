#!/usr/bin/env bash
# =============================================================================
# manjaro.sh — Optimizaciones específicas para Manjaro
# =============================================================================
# Linux System Optimizer (LSO)
# Autor: Ricardo Rosero <rrosero2000@gmail.com>
# GitHub: https://github.com/rr-n4p5t3r
# Licencia: MIT
# =============================================================================

optimize_manjaro() {
    print_step "Aplicando optimizaciones para Manjaro..."

    if [[ "$LSO_DRY_RUN" != "true" ]]; then
        local makepkg_conf="/etc/makepkg.conf"
        if [[ -f "$makepkg_conf" ]]; then
            backup_file "$makepkg_conf" 2>/dev/null || true

            sed -i "s/^#*MAKEFLAGS=.*/MAKEFLAGS="-j$(nproc)"/" "$makepkg_conf"
            sed -i 's/^COMPRESSXZ=.*/COMPRESSXZ=(xz -c -z - --threads=0)/' "$makepkg_conf"

            log_success "makepkg optimizado"
        fi

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

    local optional=("pamac-tray" "pamac-mirrorlist" "manjaro-hello")
    for svc in "${optional[@]}"; do
        if systemctl is-active --quiet "$svc" 2>/dev/null; then
            if [[ "$LSO_DRY_RUN" != "true" ]]; then
                systemctl stop "$svc" 2>/dev/null || true
                log_info "Detenido: $svc"
            fi
        fi
    done
}
optimize_manjaro
