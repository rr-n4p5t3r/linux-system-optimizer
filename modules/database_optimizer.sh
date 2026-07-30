#!/usr/bin/env bash
# =============================================================================
# database_optimizer.sh — Tuning para servidores de base de datos
# =============================================================================

LSO_DB_SERVICES=(
    "mysql" "mariadb" "postgresql" "mongod" "redis-server" "redis"
)

optimize_database() {
    print_header "OPTIMIZACIÓN DE BASE DE DATOS"

    # --- Motores de base de datos instalados ---
    print_step "Verificando motores de base de datos..."
    local found_db=false
    local svc
    for svc in "${LSO_DB_SERVICES[@]}"; do
        service_exists "$svc" || continue
        found_db=true

        if systemctl is-active --quiet "$svc" 2>/dev/null; then
            echo -e "  ${C_GREEN}•${C_RESET} $svc ${C_DIM}(activo)${C_RESET}"
        else
            echo -e "  ${C_YELLOW}•${C_RESET} $svc ${C_DIM}(instalado, inactivo)${C_RESET}"

            if [[ "${LSO_DB_START_DATABASES:-true}" == "true" ]]; then
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

    # --- Tuning de sysctl orientado a cargas de BD ---
    print_step "Ajustando parámetros de kernel para cargas de BD..."

    local swappiness="${LSO_DB_SWAPPINESS:-1}"
    local dirty_ratio="${LSO_DB_DIRTY_RATIO:-10}"
    local dirty_bg_ratio="${LSO_DB_DIRTY_BACKGROUND_RATIO:-5}"
    local shmmax="${LSO_DB_SHMMAX:-}"
    local shmall="${LSO_DB_SHMALL:-}"

    if [[ "$LSO_DRY_RUN" != "true" ]]; then
        [[ "$LSO_AUTO_BACKUP" == "true" ]] && backup_file /etc/sysctl.conf 2>/dev/null

        local params=(
            "vm.swappiness=${swappiness}"
            "vm.dirty_ratio=${dirty_ratio}"
            "vm.dirty_background_ratio=${dirty_bg_ratio}"
        )
        [[ -n "$shmmax" ]] && params+=("kernel.shmmax=${shmmax}")
        [[ -n "$shmall" ]] && params+=("kernel.shmall=${shmall}")

        local param
        for param in "${params[@]}"; do
            local key="${param%%=*}"
            sysctl -w "$param" &>/dev/null
            if grep -q "^${key}=" /etc/sysctl.conf 2>/dev/null; then
                sed -i "s|^${key}=.*|${param}|" /etc/sysctl.conf
            else
                echo "$param" >> /etc/sysctl.conf
            fi
        done

        log_success "Kernel ajustado para cargas de BD (swappiness=${swappiness}, dirty_ratio=${dirty_ratio}, dirty_background_ratio=${dirty_bg_ratio})"
    else
        print_info "[DRY-RUN] Se ajustaría: vm.swappiness=${swappiness}, vm.dirty_ratio=${dirty_ratio}, vm.dirty_background_ratio=${dirty_bg_ratio}"
    fi

    print_success "Optimización de base de datos completada"
}
optimize_database
