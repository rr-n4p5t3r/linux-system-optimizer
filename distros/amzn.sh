#!/usr/bin/env bash
# =============================================================================
# amzn.sh — Optimizaciones específicas para Amazon Linux
# =============================================================================
# Linux System Optimizer (LSO)
# Autor: Ricardo Rosero <rrosero2000@gmail.com>
# GitHub: https://github.com/rr-n4p5t3r
# Licencia: GPLv3
# =============================================================================

optimize_amzn() {
    print_step "Aplicando optimizaciones para Amazon Linux..."

    if [[ "$LSO_DRY_RUN" != "true" ]]; then
        mkdir -p /etc/dnf
        cat > /etc/dnf/dnf.conf << 'DNFEOF'
[main]
gpgcheck=1
installonly_limit=3
clean_requirements_on_remove=True
best=False
skip_if_unavailable=True
fastestmirror=True
max_parallel_downloads=10
deltarpm=True
DNFEOF
        log_success "DNF optimizado"
    fi

    if systemctl is-active --quiet "dnf-makecache.timer" 2>/dev/null; then
        if [[ "$LSO_DRY_RUN" != "true" ]]; then
            systemctl stop "dnf-makecache.timer" 2>/dev/null || true
            log_info "Detenido: dnf-makecache.timer"
        fi
    fi
}
optimize_amzn
