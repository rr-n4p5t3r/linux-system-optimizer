#!/usr/bin/env bash
# =============================================================================
# slackpkg.sh — Utilidades para slackpkg (Slackware)
# =============================================================================
# Linux System Optimizer (LSO)
# Autor: Ricardo Rosero <rrosero2000@gmail.com>
# GitHub: https://github.com/rr-n4p5t3r
# Licencia: GPLv3
# =============================================================================

slackpkg_update() {
    slackpkg -batch=on -default_answer=y update 2>/dev/null
}

slackpkg_upgrade() {
    slackpkg -batch=on -default_answer=y upgrade-all 2>/dev/null
}

# Slackware no rastrea dependencias como apt/dnf/pacman, así que no existe un
# "autoremove" real. clean-system es lo más cercano: quita paquetes instalados
# que ya no están en el set oficial de paquetes.
slackpkg_autoremove() {
    log_warn "Slackware no rastrea dependencias; usando clean-system como equivalente aproximado"
    slackpkg -batch=on -default_answer=y clean-system 2>/dev/null
}

slackpkg_clean() {
    rm -f /var/slackpkg/*.t?z 2>/dev/null
}

slackpkg_fix() {
    log_info "slackpkg no tiene un comando de verificación/reparación equivalente"
}
