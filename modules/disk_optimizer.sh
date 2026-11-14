#!/usr/bin/env bash
# disk_optimizer.sh — Optimización de disco
optimize_disk() {
    print_header "OPTIMIZACIÓN DE DISCO"

    # --- fstrim para SSD/NVMe ---
    if [[ "$LSO_DISK_TYPE" == "SSD" ]] || [[ "$LSO_DISK_TYPE" == "NVMe" ]]; then
        print_step "Ejecutando TRIM..."
        if [[ "$LSO_DRY_RUN" != "true" ]]; then
            fstrim -av / 2>/dev/null && \
                log_success "TRIM completado" || \
                log_warn "TRIM no disponible"
        else
            print_info "[DRY-RUN] Se ejecutaría fstrim"
        fi
    fi

    # --- Verificar fragmentación (solo HDD) ---
    if [[ "$LSO_DISK_TYPE" == "HDD" ]]; then
        print_step "Verificando fragmentación..."
        if command -v e4defrag &>/dev/null; then
            local frag=""
            frag=$(e4defrag -c / 2>/dev/null | grep -oP '\d+(?=%)' | head -1 || echo "0")
            echo -e "  ${C_DIM}Fragmentación:${C_RESET} ${C_CYAN}${frag}%${C_RESET}"

            if [[ "$frag" -gt 20 ]]; then
                if [[ "$LSO_DRY_RUN" != "true" ]]; then
                    if confirm "La fragmentación es alta. ¿Deseas desfragmentar?"; then
                        e4defrag / 2>/dev/null && \
                            log_success "Desfragmentación completada" || \
                            log_warn "No se pudo desfragmentar"
                    fi
                fi
            fi
        fi
    fi

    # --- Verificar inodos ---
    print_step "Verificando uso de inodos..."
    local inode_usage=""
    inode_usage=$(df -i / 2>/dev/null | tail -1 | awk '{print $5}' | tr -d '%')
    echo -e "  ${C_DIM}Uso de inodos:${C_RESET} ${C_CYAN}${inode_usage}%${C_RESET}"

    # --- SMART (si disponible) ---
    if command -v smartctl &>/dev/null; then
        print_step "Verificando salud del disco (SMART)..."
        local smart_status=""
        smart_status=$(smartctl -H /dev/sda 2>/dev/null | grep -i "health" || echo "No disponible")
        echo -e "  ${C_DIM}Estado SMART:${C_RESET} ${C_CYAN}${smart_status}${C_RESET}"
    fi

    print_success "Optimización de disco completada"
}
optimize_disk
