#!/usr/bin/env bash
# =============================================================================
# opensuse.sh — Optimizaciones específicas para openSUSE
# =============================================================================
# Linux System Optimizer (LSO)
# Autor: Ricardo Rosero <rrosero2000@gmail.com>
# GitHub: https://github.com/rr-n4p5t3r
# Licencia: MIT
# =============================================================================

optimize_opensuse() {
    print_step "Aplicando optimizaciones para openSUSE..."

    if [[ "$LSO_DRY_RUN" != "true" ]]; then
        mkdir -p /etc/zypp/zypp.conf.d
        cat > /etc/zypp/zypp.conf.d/99lso.conf << 'ZYPPEOF'
[main]
download.use_deltarpm = true
commit.downloadInAdvance = true
solver.onlyRequires = true
rpm.install.excludedocs = yes
ZYPPEOF
        log_success "Zypper optimizado"
    fi
}
optimize_opensuse
