#!/usr/bin/env bash
# =============================================================================
# startup_manager.sh — Gestor de aplicaciones de inicio (autostart)
# =============================================================================

# Aplicaciones de autoarranque candidatas a deshabilitar (no críticas)
LSO_STARTUP_OPTIONAL_APPS=(
    "update-notifier" "deja-dup-monitor" "software-properties-dbus"
    "org.gnome.Software" "print-applet" "cheese"
    "spotify" "discord" "slack" "telegram-desktop" "skypeforlinux"
)

optimize_startup() {
    print_header "GESTIÓN DE APLICACIONES DE INICIO"

    local autostart_dir="$HOME/.config/autostart"

    if [[ ! -d "$autostart_dir" ]]; then
        print_info "No se encontró directorio de autoarranque: $autostart_dir"
        return 0
    fi

    print_step "Aplicaciones de inicio detectadas..."
    local entries=()
    while IFS= read -r -d '' file; do
        entries+=("$file")
    done < <(find "$autostart_dir" -maxdepth 1 -name "*.desktop" -print0 2>/dev/null)

    if [[ ${#entries[@]} -eq 0 ]]; then
        print_info "No hay aplicaciones configuradas para iniciar con la sesión"
        return 0
    fi

    for entry in "${entries[@]}"; do
        local name app_id
        app_id=$(basename "$entry" .desktop)
        name=$(grep -m1 "^Name=" "$entry" 2>/dev/null | cut -d'=' -f2-)
        name="${name:-$app_id}"

        if ! grep -qE "^Hidden=true|^X-GNOME-Autostart-enabled=false" "$entry" 2>/dev/null; then
            echo -e "  ${C_CYAN}•${C_RESET} ${name} ${C_DIM}(${app_id})${C_RESET}"
        fi
    done

    print_step "Candidatos a deshabilitar..."
    local disabled_count=0

    for entry in "${entries[@]}"; do
        local app_id
        app_id=$(basename "$entry" .desktop)

        grep -qE "^Hidden=true|^X-GNOME-Autostart-enabled=false" "$entry" 2>/dev/null && continue

        local is_candidate=false
        for candidate in "${LSO_STARTUP_OPTIONAL_APPS[@]}"; do
            [[ "$app_id" == *"$candidate"* ]] && is_candidate=true && break
        done
        $is_candidate || continue

        echo -e "  ${C_YELLOW}• $app_id se inicia automáticamente${C_RESET}"

        if [[ "$LSO_DRY_RUN" != "true" ]]; then
            if confirm "¿Deshabilitar el inicio automático de $app_id?"; then
                [[ "$LSO_AUTO_BACKUP" == "true" ]] && backup_file "$entry" 2>/dev/null

                if grep -q "^X-GNOME-Autostart-enabled=" "$entry" 2>/dev/null; then
                    sed -i "s/^X-GNOME-Autostart-enabled=.*/X-GNOME-Autostart-enabled=false/" "$entry"
                else
                    echo "X-GNOME-Autostart-enabled=false" >> "$entry"
                fi

                log_success "Inicio automático deshabilitado: $app_id"
                ((disabled_count++))
            fi
        else
            print_info "[DRY-RUN] Se ofrecería deshabilitar $app_id"
        fi
    done

    if [[ "$disabled_count" -gt 0 ]]; then
        print_success "$disabled_count aplicaciones deshabilitadas del inicio"
    else
        print_success "Gestión de inicio completada"
    fi
}

optimize_startup
