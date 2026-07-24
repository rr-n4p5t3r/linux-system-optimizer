#!/usr/bin/env bash
# =============================================================================
# rocky.sh — Optimizaciones específicas para Rocky Linux
# =============================================================================
# Linux System Optimizer (LSO)
# Autor: Ricardo Rosero <rrosero2000@gmail.com>
# GitHub: https://github.com/rr-n4p5t3r
# Licencia: GPLv3
# =============================================================================

optimize_rocky() {
    print_step "Aplicando optimizaciones para Rocky Linux..."

    if [[ "$LSO_DRY_RUN" != "true" ]]; then
        cat > /etc/dnf/dnf.conf << 'DNFEOF'
[main]
gpgcheck=1
installonly_limit=3
clean_requirements_on_remove=True
best=False
skip_if_unavailable=True
fastestmirror=True
max_parallel_downloads=10
DNFEOF
    fi
}
optimize_rocky
