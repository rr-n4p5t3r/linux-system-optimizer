#!/usr/bin/env bash
# =============================================================================
# service_manager.sh — Gestor y optimizador de servicios systemd
# =============================================================================

# Servicios comunes que pueden deshabilitarse en desktop
LSO_DESKTOP_OPTIONAL_SERVICES=(
    "bluetooth"          # Si no usas Bluetooth
    "cups" "cups-browsed" # Si no usas impresoras
    "avahi-daemon"       # Descubrimiento de red local
    "ModemManager"       # Si no usas módem 3G/4G
)

# Servicios para gaming (pueden deshabilitarse temporalmente)
LSO_GAMING_OPTIONAL_SERVICES=(
    "bluetooth"
    "cups"
    "avahi-daemon"
    "snapd"
    "flatpak-system-helper"
)

optimize_services() {
    print_header "GESTIÓN DE SERVICIOS"

    # --- Mostrar servicios que fallaron ---
    print_step "Servicios con fallos..."
    local failed
    failed=$(systemctl --failed --no-pager --no-legend 2>/dev/null | head -10 || true)

    if [[ -n "$failed" ]]; then
        echo -e "  ${C_RED}Servicios fallidos:${C_RESET}"
        echo "$failed" | while read line; do
            echo -e "    ${C_RED}• $line${C_RESET}"
        done

        if [[ "$LSO_DRY_RUN" != "true" ]]; then
            if confirm "¿Deseas reiniciar los servicios fallidos?"; then
                systemctl --failed --no-pager --no-legend 2>/dev/null | awk '{print $1}' | \
                    while read svc; do
                        systemctl restart "$svc" 2>/dev/null && \
                            log_success "Reiniciado: $svc" || \
                            log_warn "No se pudo reiniciar: $svc"
                    done
            fi
        fi
    else
        print_success "No hay servicios fallidos"
    fi

    # --- Servicios innecesarios según perfil ---
    print_step "Analizando servicios opcionales..."

    local services_to_check=()

    case "$LSO_PROFILE" in
        gaming)
            services_to_check=("${LSO_GAMING_OPTIONAL_SERVICES[@]}")
            ;;
        server)
            # En server no tocamos nada sin confirmación explícita
            services_to_check=()
            ;;
        *)
            services_to_check=("${LSO_DESKTOP_OPTIONAL_SERVICES[@]}")
            ;;
    esac

    for svc in "${services_to_check[@]}"; do
        if systemctl is-active --quiet "$svc" 2>/dev/null; then
            echo -e "  ${C_YELLOW}• $svc está activo${C_RESET}"

            if [[ "$LSO_DRY_RUN" != "true" ]]; then
                if confirm "¿Detener $svc?"; then
                    systemctl stop "$svc" 2>/dev/null && \
                        log_success "Detenido: $svc" || \
                        log_warn "No se pudo detener: $svc"

                    if confirm "¿Deshabilitar $svc al inicio?"; then
                        systemctl disable "$svc" 2>/dev/null && \
                            log_success "Deshabilitado: $svc" || true
                    fi
                fi
            else
                print_info "[DRY-RUN] Se ofrecería detener $svc"
            fi
        fi
    done

    # --- Tiempo de boot ---
    print_step "Analizando tiempo de inicio..."
    if command -v systemd-analyze &>/dev/null; then
        local boot_time
        boot_time=$(systemd-analyze 2>/dev/null | head -1 || echo "No disponible")
        echo -e "  ${C_DIM}Boot:${C_RESET} ${C_CYAN}${boot_time}${C_RESET}"

        local slow_services
        slow_services=$(systemd-analyze blame 2>/dev/null | head -5 || true)
        if [[ -n "$slow_services" ]]; then
            echo -e "  ${C_DIM}Servicios más lentos:${C_RESET}"
            echo "$slow_services" | while read line; do
                echo -e "    ${C_YELLOW}$line${C_RESET}"
            done
        fi
    fi

    print_success "Gestión de servicios completada"
}

optimize_services
