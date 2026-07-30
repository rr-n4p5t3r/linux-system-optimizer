#!/usr/bin/env bash
# =============================================================================
# pkg.sh — Utilidades para pkg (FreeBSD)
# =============================================================================
# Linux System Optimizer (LSO)
# Autor: Ricardo Rosero <rrosero2000@gmail.com>
# GitHub: https://github.com/rr-n4p5t3r
# Licencia: GPLv3
# =============================================================================
# NOTA: soporte experimental. Ver distros/freebsd.sh para el alcance real de
# LSO en FreeBSD — solo estas funciones de paquetes están cubiertas; la
# mayoría de los módulos del core son Linux-específicos y no aplican acá.
# =============================================================================

pkg_update() {
    pkg update 2>/dev/null
}

pkg_upgrade() {
    pkg upgrade -y 2>/dev/null
}

pkg_autoremove() {
    pkg autoremove -y 2>/dev/null
}

pkg_clean() {
    pkg clean -y 2>/dev/null
}

pkg_fix() {
    pkg check -da 2>/dev/null
}
