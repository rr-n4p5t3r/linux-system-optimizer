#!/usr/bin/env bash
# =============================================================================
# fedora.sh — Optimizaciones específicas para Fedora
# =============================================================================
# Linux System Optimizer (LSO)
# Autor: Ricardo Rosero <rrosero2000@gmail.com>
# GitHub: https://github.com/rr-n4p5t3r
# Licencia: MIT
# =============================================================================

optimize_fedora() {
    print_step "Aplicando optimizaciones para Fedora..."

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

    local optional=("dnf-makecache.timer" "flatpak-system-helper")
    for svc in "${optional[@]}"; do
        if systemctl is-active --quiet "$svc" 2>/dev/null; then
            if [[ "$LSO_DRY_RUN" != "true" ]]; then
                systemctl stop "$svc" 2>/dev/null || true
                log_info "Detenido: $svc"
            fi
        fi
    done
}
optimize_fedora
