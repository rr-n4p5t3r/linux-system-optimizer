#!/usr/bin/env bash
# =============================================================================
# dev_environment.sh — Entorno de desarrollo: motores de BD, inotify, tooling
# =============================================================================

# Servicios de motores de base de datos a detectar/activar
LSO_DEV_DATABASE_SERVICES=(
    "mysql" "mariadb" "postgresql" "mongod" "redis-server" "redis"
)

optimize_dev_environment() {
    print_header "ENTORNO DE DESARROLLO"

    # --- Límite de inotify (VS Code, webpack, etc. suelen agotarlo) ---
    if [[ "${LSO_DEV_INCREASE_INOTIFY:-true}" == "true" ]]; then
        print_step "Ajustando límite de inotify (fs.inotify.max_user_watches)..."
        local current_watches target_watches
        current_watches=$(cat /proc/sys/fs/inotify/max_user_watches 2>/dev/null || echo "8192")
        target_watches="${LSO_DEV_INOTIFY_WATCHES:-524288}"

        echo -e "  ${C_DIM}Actual:${C_RESET} ${C_CYAN}${current_watches}${C_RESET}"
        echo -e "  ${C_DIM}Objetivo:${C_RESET} ${C_CYAN}${target_watches}${C_RESET}"

        if [[ "$LSO_DRY_RUN" != "true" ]]; then
            if [[ "$current_watches" -lt "$target_watches" ]]; then
                [[ "$LSO_AUTO_BACKUP" == "true" ]] && backup_file /etc/sysctl.conf 2>/dev/null

                sysctl -w "fs.inotify.max_user_watches=${target_watches}" &>/dev/null

                if grep -q "^fs.inotify.max_user_watches" /etc/sysctl.conf 2>/dev/null; then
                    sed -i "s/^fs.inotify.max_user_watches=.*/fs.inotify.max_user_watches=${target_watches}/" /etc/sysctl.conf
                else
                    echo "fs.inotify.max_user_watches=${target_watches}" >> /etc/sysctl.conf
                fi

                log_success "Límite de inotify ajustado a ${target_watches}"
            else
                print_info "El límite actual ya es suficiente"
            fi
        else
            print_info "[DRY-RUN] Se ajustaría fs.inotify.max_user_watches a ${target_watches}"
        fi
    fi

    # --- Motores de base de datos ---
    print_step "Verificando motores de base de datos..."
    local found_db=false
    local svc=""
    for svc in "${LSO_DEV_DATABASE_SERVICES[@]}"; do
        service_exists "$svc" || continue
        found_db=true

        if systemctl is-active --quiet "$svc" 2>/dev/null; then
            echo -e "  ${C_GREEN}•${C_RESET} $svc ${C_DIM}(activo)${C_RESET}"
        else
            echo -e "  ${C_YELLOW}•${C_RESET} $svc ${C_DIM}(instalado, inactivo)${C_RESET}"

            if [[ "${LSO_DEV_START_DATABASES:-true}" == "true" ]]; then
                if [[ "$LSO_DRY_RUN" != "true" ]]; then
                    if confirm "¿Iniciar y habilitar $svc?"; then
                        systemctl enable --now "$svc" 2>/dev/null && \
                            log_success "Iniciado y habilitado: $svc" || \
                            log_warn "No se pudo iniciar: $svc"
                    fi
                else
                    print_info "[DRY-RUN] Se ofrecería iniciar $svc"
                fi
            fi
        fi
    done
    $found_db || print_info "No se detectaron motores de base de datos instalados"

    # --- Entornos virtuales y gestores de versiones ---
    print_step "Herramientas de entornos virtuales/versiones detectadas..."
    local tool_found=false

    if command -v python3 &>/dev/null && python3 -c "import venv" 2>/dev/null; then
        echo -e "  ${C_CYAN}•${C_RESET} python3 venv"
        tool_found=true
    fi

    local tool=""
    for tool in conda pyenv rbenv rvm docker podman; do
        if command -v "$tool" &>/dev/null; then
            echo -e "  ${C_CYAN}•${C_RESET} $tool"
            tool_found=true
        fi
    done

    if [[ -s "$HOME/.nvm/nvm.sh" ]]; then
        echo -e "  ${C_CYAN}•${C_RESET} nvm"
        tool_found=true
    fi

    $tool_found || print_info "No se detectaron gestores de entornos virtuales/versiones"

    if [[ ${#LSO_LANGUAGES[@]} -gt 0 ]]; then
        echo -e "  ${C_DIM}Lenguajes instalados:${C_RESET} ${C_CYAN}${LSO_LANGUAGES[*]}${C_RESET}"
    fi

    print_success "Entorno de desarrollo revisado"
}

optimize_dev_environment
