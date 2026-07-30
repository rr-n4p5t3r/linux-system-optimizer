#!/usr/bin/env bash
# =============================================================================
# portage.sh — Utilidades para Portage (Gentoo)
# =============================================================================
# Linux System Optimizer (LSO)
# Autor: Ricardo Rosero <rrosero2000@gmail.com>
# GitHub: https://github.com/rr-n4p5t3r
# Licencia: GPLv3
# =============================================================================

portage_update() {
    emerge --sync 2>/dev/null
}

portage_upgrade() {
    emerge -uDN @world 2>/dev/null
}

portage_autoremove() {
    emerge --depclean 2>/dev/null
}

portage_clean() {
    if command -v eclean-dist &>/dev/null; then
        eclean-dist 2>/dev/null
    fi
}

portage_fix() {
    if command -v revdep-rebuild &>/dev/null; then
        revdep-rebuild 2>/dev/null
    fi
}
