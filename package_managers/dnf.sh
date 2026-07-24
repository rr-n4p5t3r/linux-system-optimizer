#!/usr/bin/env bash
# =============================================================================
# dnf.sh — Utilidades para DNF
# =============================================================================
# Linux System Optimizer (LSO)
# Autor: Ricardo Rosero <rrosero2000@gmail.com>
# GitHub: https://github.com/rr-n4p5t3r
# Licencia: GPLv3
# =============================================================================

dnf_update() {
    dnf update -y --quiet 2>/dev/null
}

dnf_upgrade() {
    dnf upgrade -y --quiet 2>/dev/null
}

dnf_autoremove() {
    dnf autoremove -y 2>/dev/null
}

dnf_clean() {
    dnf clean all 2>/dev/null
}

dnf_fix() {
    dnf check -y 2>/dev/null
}
