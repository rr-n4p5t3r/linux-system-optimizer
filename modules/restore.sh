#!/usr/bin/env bash
# =============================================================================
# restore.sh — Restauración de configuraciones desde backups
# =============================================================================

restore_system() {
    print_header "RESTAURACIÓN DE CONFIGURACIONES"

    # El mismo directorio que eligió backup_file (el del proyecto o el de estado).
    local backup_dir=""
    backup_dir=$(lso_pick_dir "${LSO_BASE_DIR}/backups" backups 2>/dev/null) || backup_dir="${LSO_BASE_DIR}/backups"

    if [[ ! -d "$backup_dir" ]] || [[ -z "$(ls -A "$backup_dir" 2>/dev/null)" ]]; then
        print_warn "No hay backups disponibles"
        return 0
    fi

    # Listar backups disponibles
    print_step "Backups disponibles:"
    local backups=()
    local i=1

    for backup in "$backup_dir"/*.bak; do
        [[ -f "$backup" ]] || continue
        local filename=""
        filename=$(basename "$backup")
        local size=""
        size=$(du -sh "$backup" 2>/dev/null | cut -f1)
        local date_str=""
        local epoch=""
        epoch=$(lso_backup_epoch "$backup")
        date_str="Fecha desconocida"
        [[ -n "$epoch" ]] && date_str=$(date -d "@$epoch" '+%Y-%m-%d %H:%M:%S' 2>/dev/null)
        local dest="ruta original desconocida"
        [[ -f "$backup.path" ]] && dest=$(head -1 "$backup.path")

        echo -e "  ${C_CYAN}${i}.${C_RESET} ${filename} (${size}) — ${date_str} → ${dest}"
        backups+=("$backup")
        ((i++))
    done

    echo
    echo -e "  ${C_CYAN}0.${C_RESET} ${C_YELLOW}Restaurar TODOS los backups${C_RESET}"
    echo -e "  ${C_CYAN}a.${C_RESET} ${C_RED}Eliminar TODOS los backups${C_RESET}"
    echo -e "  ${C_CYAN}q.${C_RESET} Cancelar"
    echo

    read -rp "$(echo -e "${C_YELLOW}Selecciona una opción: ${C_RESET}")" choice

    case "$choice" in
        0)
            print_warn "Restaurando TODOS los backups..."
            for backup in "${backups[@]}"; do
                restore_file "$backup"
            done
            print_success "Todos los backups restaurados"
            ;;
        [1-9]*)
            local idx=$((choice - 1))
            if [[ "$idx" -lt "${#backups[@]}" ]]; then
                restore_file "${backups[$idx]}"
            else
                log_error "Opción inválida"
            fi
            ;;
        a|A)
            if confirm "${C_RED}¿Eliminar TODOS los backups? Esta acción no se puede deshacer.${C_RESET}"; then
                rm -f "$backup_dir"/*.bak "$backup_dir"/*.bak.path
                print_success "Backups eliminados"
            fi
            ;;
        q|Q|*)
            log_info "Restauración cancelada"
            ;;
    esac
}

restore_system
