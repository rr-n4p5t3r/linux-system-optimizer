#!/usr/bin/env bash
# =============================================================================
# gnome.sh — Optimizaciones para GNOME
# =============================================================================
# Linux System Optimizer (LSO)
# Autor: Ricardo Rosero <rrosero2000@gmail.com>
# GitHub: https://github.com/rr-n4p5t3r
# Licencia: MIT
# =============================================================================

optimize_gnome() {
    print_step "Optimizando GNOME..."

    if [[ "$LSO_DRY_RUN" != "true" ]]; then
        gsettings set org.gnome.desktop.interface enable-animations false 2>/dev/null || true
        gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-timeout 3600 2>/dev/null || true
        gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-timeout 1800 2>/dev/null || true

        if command -v tracker &>/dev/null; then
            tracker reset --hard 2>/dev/null || true
            gsettings set org.freedesktop.Tracker.Miner.Files index-on-battery false 2>/dev/null || true
            log_info "Tracker (indexación) optimizado"
        fi

        log_success "GNOME optimizado"
    else
        print_info "[DRY-RUN] Se optimizaría GNOME"
    fi
}
optimize_gnome
