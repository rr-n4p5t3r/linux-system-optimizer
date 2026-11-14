#!/usr/bin/env bash
# network_optimizer.sh — Optimización de red
optimize_network() {
    print_header "OPTIMIZACIÓN DE RED"

    # --- TCP BBR (si el kernel lo soporta) ---
    if [[ "${LSO_NETWORK_OPTIMIZE_TCP:-true}" == "true" ]]; then
        print_step "Verificando algoritmo de congestión TCP..."
        local current_cc=""
        current_cc=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || echo "unknown")
        echo -e "  ${C_DIM}Actual:${C_RESET} ${C_CYAN}${current_cc}${C_RESET}"

        if [[ "$current_cc" != "bbr" ]]; then
            if modprobe tcp_bbr 2>/dev/null; then
                if [[ "$LSO_DRY_RUN" != "true" ]]; then
                    sysctl -w net.ipv4.tcp_congestion_control=bbr 2>/dev/null && \
                        log_success "TCP BBR activado" || \
                        log_warn "No se pudo activar BBR"
                else
                    print_info "[DRY-RUN] Se activaría TCP BBR"
                fi
            else
                log_warn "Kernel no soporta BBR"
            fi
        else
            log_info "TCP BBR ya está activo"
        fi
    fi

    # --- Buffer sizes ---
    print_step "Optimizando buffers de red..."
    if [[ "$LSO_DRY_RUN" != "true" ]]; then
        sysctl -w net.core.rmem_max=134217728 2>/dev/null || true
        sysctl -w net.core.wmem_max=134217728 2>/dev/null || true
        sysctl -w net.ipv4.tcp_rmem="4096 87380 134217728" 2>/dev/null || true
        sysctl -w net.ipv4.tcp_wmem="4096 65536 134217728" 2>/dev/null || true
        log_success "Buffers de red optimizados"
    else
        print_info "[DRY-RUN] Se optimizarían buffers de red"
    fi

    # --- DNS ---
    if [[ "${LSO_NETWORK_DNS_OPTIMIZE:-false}" == "true" ]]; then
        print_step "Verificando resolución DNS..."
        # Solo informativo, no modificamos resolv.conf sin consentimiento
        local current_dns=""
        current_dns=$(grep "^nameserver" /etc/resolv.conf 2>/dev/null | head -3 || echo "No disponible")
        echo -e "  ${C_DIM}DNS actual:${C_RESET}"
        echo "$current_dns" | sed 's/^/    /'
    fi

    print_success "Optimización de red completada"
}
optimize_network
