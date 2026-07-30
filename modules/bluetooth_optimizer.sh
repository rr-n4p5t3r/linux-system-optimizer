#!/usr/bin/env bash
# =============================================================================
# bluetooth_optimizer.sh — Gestión del adaptador Bluetooth
# =============================================================================

optimize_bluetooth() {
    print_header "BLUETOOTH"

    if ! service_exists "bluetooth"; then
        print_info "No se detectó el servicio bluetooth en este sistema"
        return 0
    fi

    if ! systemctl is-active --quiet bluetooth 2>/dev/null; then
        print_info "El servicio bluetooth no está activo"
        return 0
    fi

    print_step "Dispositivos emparejados..."
    local paired_count=0
    if command -v bluetoothctl &>/dev/null; then
        local devices
        devices=$(bluetoothctl devices 2>/dev/null)
        paired_count=$(echo "$devices" | grep -c "^Device" || echo "0")

        if [[ "$paired_count" -gt 0 ]]; then
            echo "$devices" | while read -r _ mac name; do
                echo -e "  ${C_CYAN}•${C_RESET} ${name} ${C_DIM}(${mac})${C_RESET}"
            done
        fi
    fi

    if [[ "$paired_count" -eq 0 ]]; then
        echo -e "  ${C_YELLOW}Bluetooth activo pero sin dispositivos emparejados${C_RESET}"

        if [[ "$LSO_DRY_RUN" != "true" ]]; then
            if confirm "¿Detener y deshabilitar el servicio bluetooth?"; then
                systemctl stop bluetooth 2>/dev/null && \
                    systemctl disable bluetooth 2>/dev/null && \
                    log_success "Bluetooth detenido y deshabilitado" || \
                    log_warn "No se pudo deshabilitar bluetooth"
            fi
        else
            print_info "[DRY-RUN] Se ofrecería deshabilitar bluetooth (sin dispositivos emparejados)"
        fi
    else
        print_success "Bluetooth en uso (${paired_count} dispositivo(s) emparejado(s)) — no se toca"
    fi
}
optimize_bluetooth
