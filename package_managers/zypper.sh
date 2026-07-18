#!/usr/bin/env bash
# =============================================================================
# zypper.sh — Utilidades para Zypper
# =============================================================================
# Linux System Optimizer (LSO)
# Autor: Ricardo Rosero <rrosero2000@gmail.com>
# GitHub: https://github.com/rr-n4p5t3r
# Licencia: MIT
# =============================================================================

zypper_update() {
    zypper --quiet ref 2>/dev/null
}

zypper_upgrade() {
    zypper --non-interactive up 2>/dev/null
}

zypper_autoremove() {
    zypper --non-interactive rm $(zypper --quiet packages --unneeded | awk '{print $3}') 2>/dev/null || true
}

zypper_clean() {
    zypper clean 2>/dev/null
}

zypper_fix() {
    zypper verify 2>/dev/null
}
