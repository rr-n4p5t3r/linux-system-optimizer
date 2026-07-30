#!/usr/bin/env bash
# =============================================================================
# xbps.sh — Utilidades para XBPS (Void Linux)
# =============================================================================
# Linux System Optimizer (LSO)
# Autor: Ricardo Rosero <rrosero2000@gmail.com>
# GitHub: https://github.com/rr-n4p5t3r
# Licencia: GPLv3
# =============================================================================

xbps_update() {
    xbps-install -S 2>/dev/null
}

xbps_upgrade() {
    xbps-install -Suy 2>/dev/null
}

xbps_autoremove() {
    xbps-remove -Oy 2>/dev/null
}

xbps_clean() {
    rm -f /var/cache/xbps/*.xbps 2>/dev/null
}

xbps_fix() {
    xbps-pkgdb -a 2>/dev/null
}
