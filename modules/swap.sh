#!/usr/bin/env bash
# swap.sh — Gestión y optimización de swap
optimize_swap() {
    print_header "OPTIMIZACIÓN DE SWAP"

    # --- Verificar swap existente ---
    local swap_total
    swap_total=$(free -m | awk '/^Swap:/{print $2}')
    local swap_used
    swap_used=$(free -m | awk '/^Swap:/{print $3}')

    echo -e "  ${C_DIM}Swap total:${C_RESET} ${C_CYAN}${swap_total}MB${C_RESET}"
    echo -e "  ${C_DIM}Swap usado:${C_RESET} ${C_CYAN}${swap_used}MB${C_RESET}"

    # --- Ajustar swappiness ---
    if [[ "${LSO_SWAP_OPTIMIZE:-true}" == "true" ]]; then
        print_step "Ajustando swappiness..."
        local target="${LSO_SWAPPINESS:-10}"

        if [[ "$LSO_DRY_RUN" != "true" ]]; then
            sysctl -w "vm.swappiness=${target}" &>/dev/null

            if grep -q "^vm.swappiness" /etc/sysctl.conf 2>/dev/null; then
                sed -i "s/^vm.swappiness=.*/vm.swappiness=${target}/" /etc/sysctl.conf
            else
                echo "vm.swappiness=${target}" >> /etc/sysctl.conf
            fi

            log_success "Swappiness ajustado a ${target}"
        fi
    fi

    # --- Verificar si hay swap file en SSD ---
    if [[ "$LSO_DISK_TYPE" == "SSD" ]] || [[ "$LSO_DISK_TYPE" == "NVMe" ]]; then
        print_step "Disco SSD detectado — swap file es preferible a partición"

        if swapon --show=NAME,TYPE 2>/dev/null | grep -q "partition"; then
            log_info "Tienes swap en partición. Considera migrar a swap file para mejor rendimiento en SSD"
        fi
    fi

    # --- vm.vfs_cache_pressure ---
    print_step "Ajustando vfs_cache_pressure..."
    if [[ "$LSO_DRY_RUN" != "true" ]]; then
        sysctl -w vm.vfs_cache_pressure=50 &>/dev/null

        if grep -q "^vm.vfs_cache_pressure" /etc/sysctl.conf 2>/dev/null; then
            sed -i 's/^vm.vfs_cache_pressure=.*/vm.vfs_cache_pressure=50/' /etc/sysctl.conf
        else
            echo "vm.vfs_cache_pressure=50" >> /etc/sysctl.conf
        fi

        log_success "vfs_cache_pressure ajustado a 50"
    fi

    print_success "Optimización de swap completada"
}
optimize_swap
