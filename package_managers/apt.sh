#!/usr/bin/env bash
# =============================================================================
# apt.sh — Utilidades para APT
# =============================================================================
# Linux System Optimizer (LSO)
# Autor: Ricardo Rosero <rrosero2000@gmail.com>
# GitHub: https://github.com/rr-n4p5t3r
# Licencia: MIT
# =============================================================================

apt_update() {
    apt-get update -qq 2>/dev/null
}

apt_upgrade() {
    apt-get upgrade -y -qq 2>/dev/null
}

apt_autoremove() {
    apt-get autoremove -y 2>/dev/null
}

apt_clean() {
    apt-get clean 2>/dev/null
    apt-get autoclean 2>/dev/null
}

apt_fix() {
    apt-get --fix-broken install -y 2>/dev/null
    dpkg --configure -a 2>/dev/null
}
