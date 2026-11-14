#!/usr/bin/env bash
# =============================================================================
# process_manager.sh — Gestor y optimizador de procesos
# =============================================================================

# Lista de procesos que NUNCA deben terminarse (críticos). Documenta el
# principio "No finalizar procesos críticos automáticamente" (ver README);
# este módulo solo actúa sobre zombies y sobre LSO_CANDIDATE_PROCESES, así
# que hoy no hay ningún punto que necesite consultarla, pero se deja
# declarada como referencia para módulos futuros que maten procesos por
# nombre.
# shellcheck disable=SC2034
LSO_CRITICAL_PROCESSES=(
    "systemd" "init" "kernel" "kthreadd" "sshd" "bash" "login"
    "Xorg" "Xwayland" "gnome-shell" "plasmashell" "cinnamon"
    "dbus-daemon" "NetworkManager" "pipewire" "pulseaudio"
    "gdm" "sddm" "lightdm" "loginwindow"
)

# Lista de procesos candidatos para terminar (no críticos, consumidores)
LSO_CANDIDATE_PROCESES=(
    "tracker-miner" "tracker-store" "baloo_file" "baloo_file_extractor"
    "zeitgeist" "zeitgeist-daemon" "mission-control" "evolution"
    "packagekitd" "snapd" "flatpak" "appimagelauncher"
)

optimize_processes() {
    print_header "GESTIÓN DE PROCESOS"

    # --- Mostrar procesos más consumidores ---
    print_step "Top 15 procesos por uso de CPU..."
    echo -e "  ${C_DIM}PID    %CPU   %MEM   USER     COMMAND${C_RESET}"
    ps aux --sort=-%cpu 2>/dev/null | head -16 | tail -15 | \
        awk '{printf "  %-6s %-6s %-6s %-8s %s\n", $2, $3, $4, $1, $11}' | \
        while read line; do echo -e "${C_CYAN}$line${C_RESET}"; done

    # --- Verificar procesos zombie ---
    print_step "Verificando procesos zombie..."
    local zombies=""
    zombies=$(ps aux 2>/dev/null | awk '$8 ~ /^Z/ {print $2, $11}' || true)

    if [[ -n "$zombies" ]]; then
        echo -e "  ${C_YELLOW}Procesos zombie detectados:${C_RESET}"
        echo "$zombies" | while read pid cmd; do
            echo -e "    ${C_RED}PID $pid: $cmd${C_RESET}"
        done

        if [[ "$LSO_DRY_RUN" != "true" ]]; then
            if confirm "¿Deseas intentar limpiar procesos zombie?"; then
                echo "$zombies" | while read pid _; do
                    kill -9 "$pid" 2>/dev/null || true
                done
                log_success "Procesos zombie limpiados"
            fi
        fi
    else
        print_success "No hay procesos zombie"
    fi

    # --- Optimizar nice de procesos pesados ---
    print_step "Ajustando prioridades de procesos..."

    # Bajar prioridad de indexadores y otros procesos no críticos conocidos
    for proc in "${LSO_CANDIDATE_PROCESES[@]}"; do
        local pids=""
        pids=$(pgrep -f "$proc" 2>/dev/null || true)
        if [[ -n "$pids" ]]; then
            for pid in $pids; do
                if [[ "$LSO_DRY_RUN" != "true" ]]; then
                    renice +10 -p "$pid" &>/dev/null && \
                        log_info "Prioridad reducida: $proc (PID $pid)"
                else
                    print_info "[DRY-RUN] Se reduciría prioridad de $proc (PID $pid)"
                fi
            done
        fi
    done

    # --- Verificar procesos duplicados ---
    print_step "Verificando procesos duplicados..."
    local duplicates=""
    duplicates=$(ps aux 2>/dev/null | awk '{print $11}' | sort | uniq -d | grep -v '^\[' || true)

    if [[ -n "$duplicates" ]]; then
        echo -e "  ${C_DIM}Procesos con múltiples instancias:${C_RESET}"
        echo "$duplicates" | head -5 | while read proc; do
            local count=""
            count=$(pgrep -c -f "$proc" 2>/dev/null || echo "0")
            echo -e "    ${C_CYAN}$proc: ${count} instancias${C_RESET}"
        done
    fi

    print_success "Gestión de procesos completada"
}

optimize_processes
