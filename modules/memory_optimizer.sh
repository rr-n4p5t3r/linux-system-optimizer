#!/usr/bin/env bash
# =============================================================================
# memory_optimizer.sh — Optimización de memoria RAM
# =============================================================================

optimize_memory() {
    print_header "OPTIMIZACIÓN DE MEMORIA"

    local ram_before ram_after
    ram_before=$(free -m | awk '/^Mem:/{print $3}')

    # --- Limpiar cachés del kernel ---
    print_step "Limpiando cachés del kernel..."
    if [[ "$LSO_DRY_RUN" != "true" ]]; then
        sync
        echo 3 > /proc/sys/vm/drop_caches 2>/dev/null && \
            log_success "Cachés del kernel liberadas" || \
            log_warn "No se pudieron liberar cachés del kernel (requiere root)"
    else
        print_info "[DRY-RUN] Se limpiarían cachés del kernel"
    fi

    # --- Optimizar swappiness ---
    if [[ "${LSO_SWAP_OPTIMIZE:-true}" == "true" ]]; then
        print_step "Ajustando swappiness..."
        local current_swappiness=""
        current_swappiness=$(cat /proc/sys/vm/swappiness 2>/dev/null || echo "60")
        local target_swappiness="${LSO_SWAPPINESS:-10}"

        echo -e "  ${C_DIM}Actual:${C_RESET} ${C_CYAN}${current_swappiness}${C_RESET}"
        echo -e "  ${C_DIM}Objetivo:${C_RESET} ${C_CYAN}${target_swappiness}${C_RESET}"

        if [[ "$LSO_DRY_RUN" != "true" ]]; then
            if [[ "$LSO_AUTO_BACKUP" == "true" ]]; then
                backup_file /etc/sysctl.conf 2>/dev/null || true
            fi

            sysctl -w "vm.swappiness=${target_swappiness}" &>/dev/null

            # Persistir
            if grep -q "^vm.swappiness" /etc/sysctl.conf 2>/dev/null; then
                sed -i "s/^vm.swappiness=.*/vm.swappiness=${target_swappiness}/" /etc/sysctl.conf
            else
                echo "vm.swappiness=${target_swappiness}" >> /etc/sysctl.conf
            fi

            log_success "Swappiness ajustado a ${target_swappiness}"
        else
            print_info "[DRY-RUN] Se ajustaría swappiness a ${target_swappiness}"
        fi
    fi

    # --- Optimizar vfs_cache_pressure ---
    print_step "Ajustando vfs_cache_pressure..."
    local target_pressure=50
    if [[ "$LSO_DRY_RUN" != "true" ]]; then
        sysctl -w "vm.vfs_cache_pressure=${target_pressure}" &>/dev/null
        if grep -q "^vm.vfs_cache_pressure" /etc/sysctl.conf 2>/dev/null; then
            sed -i "s/^vm.vfs_cache_pressure=.*/vm.vfs_cache_pressure=${target_pressure}/" /etc/sysctl.conf
        else
            echo "vm.vfs_cache_pressure=${target_pressure}" >> /etc/sysctl.conf
        fi
        log_success "vfs_cache_pressure ajustado a ${target_pressure}"
    else
        print_info "[DRY-RUN] Se ajustaría vfs_cache_pressure a ${target_pressure}"
    fi

    # --- Limpiar buffers ---
    print_step "Sincronizando y limpiando buffers..."
    if [[ "$LSO_DRY_RUN" != "true" ]]; then
        sync
        echo 1 > /proc/sys/vm/drop_caches 2>/dev/null || true
    fi

    # --- Reportar resultado ---
    ram_after=$(free -m | awk '/^Mem:/{print $3}')
    local freed=$((ram_before - ram_after))

    if [[ "$freed" -gt 0 ]]; then
        print_success "Memoria liberada: ${freed}MB"
    else
        print_info "Memoria ya estaba optimizada"
    fi
}

optimize_memory
