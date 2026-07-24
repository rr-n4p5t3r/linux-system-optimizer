#!/usr/bin/env bash
# =============================================================================
# pacman.sh — Utilidades para Pacman
# =============================================================================
# Linux System Optimizer (LSO)
# Autor: Ricardo Rosero <rrosero2000@gmail.com>
# GitHub: https://github.com/rr-n4p5t3r
# Licencia: GPLv3
# =============================================================================

pacman_update() {
    pacman -Sy --noconfirm 2>/dev/null
}

pacman_upgrade() {
    pacman -Syu --noconfirm 2>/dev/null
}

pacman_autoremove() {
    pacman -Sc --noconfirm 2>/dev/null
}

pacman_clean() {
    paccache -rk3 2>/dev/null
}

pacman_fix() {
    pacman -Qk 2>/dev/null
}
