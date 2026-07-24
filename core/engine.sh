#!/usr/bin/env bash
# =============================================================================
# engine.sh — Motor principal de ejecución de LSO
# =============================================================================
# Linux System Optimizer (LSO)
# Autor: Ricardo Rosero <rrosero2000@gmail.com>
# GitHub: https://github.com/rr-n4p5t3r
# Licencia: GPLv3
# =============================================================================

LSO_MODULES_DIR="${LSO_BASE_DIR}/modules"
LSO_CONFIG_DIR="${LSO_BASE_DIR}/config"
LSO_PROFILE=""
LSO_DRY_RUN=false
LSO_FORCE=false

load_config() {
    local config_file="${LSO_CONFIG_DIR}/settings.conf"

    if [[ -f "$config_file" ]]; then
        # shellcheck source=/dev/null
        source "$config_file" || log_warn "No se pudo cargar settings.conf completamente"
        log_info "Configuración cargada desde: $config_file"
    else
        log_warn "Archivo de configuración no encontrado: $config_file"
    fi
}

load_profile() {
    local profile_name="${1:-desktop}"
    local profile_file="${LSO_CONFIG_DIR}/profiles/${profile_name}.conf"

    if [[ -f "$profile_file" ]]; then
        # shellcheck source=/dev/null
        source "$profile_file" || log_warn "No se pudo cargar el perfil completamente"
        LSO_PROFILE="$profile_name"
        log_info "Perfil cargado: $profile_name"
    else
        log_warn "Perfil no encontrado: $profile_name. Usando defaults."
        LSO_PROFILE="default"
    fi
}

run_module() {
    local module_name="$1"
    local module_path="${LSO_MODULES_DIR}/${module_name}.sh"

    if [[ ! -f "$module_path" ]]; then
        log_error "Módulo no encontrado: $module_name"
        return 1
    fi

    print_header "EJECUTANDO MÓDULO: $module_name"
    log_info "Iniciando módulo: $module_name"

    plugin_hook "pre_${module_name}"

    if [[ "$LSO_DRY_RUN" == "true" ]]; then
        print_warn "MODO SIMULACIÓN (dry-run): No se aplicarán cambios"
    fi

    # Ejecutar módulo con manejo de errores
    set +e
    # shellcheck source=/dev/null
    source "$module_path"
    local module_exit=$?
    set -e

    if [[ $module_exit -ne 0 ]]; then
        log_warn "El módulo $module_name terminó con código $module_exit"
    fi

    plugin_hook "post_${module_name}"

    log_success "Módulo completado: $module_name"
}

run_modules() {
    local modules=("$@")
    local total=${#modules[@]}
    local current=0

    if [[ $total -eq 0 ]]; then
        log_warn "No hay módulos para ejecutar"
        return 0
    fi

    print_header "EJECUTANDO ${total} MÓDULOS"

    for module in "${modules[@]}"; do
        ((current++))
        progress_bar "$current" "$total"
        run_module "$module" || log_warn "Módulo $module falló, continuando..."
    done

    print_success "Todos los módulos completados"
}

run_analysis() {
    print_header "ANÁLISIS COMPLETO DEL SISTEMA"
    run_module "analyzer" || log_warn "El análisis tuvo problemas"
}

run_optimization() {
    local profile="${1:-$LSO_PROFILE}"
    profile="${profile:-desktop}"

    load_profile "$profile"

    print_header "OPTIMIZACIÓN CON PERFIL: $profile"

    local modules_to_run=()

    case "$profile" in
        desktop)
            modules_to_run=("analyzer" "cpu_optimizer" "process_manager" "service_manager" "startup_manager" "desktop_optimizer" "browser_optimizer" "cache_cleaner" "package_optimizer")
            ;;
        laptop)
            modules_to_run=("analyzer" "cpu_optimizer" "process_manager" "service_manager" "startup_manager" "desktop_optimizer" "browser_optimizer" "cache_cleaner" "package_optimizer" "swap")
            ;;
        gaming)
            modules_to_run=("analyzer" "cpu_optimizer" "process_manager" "service_manager" "startup_manager" "desktop_optimizer" "browser_optimizer" "disk_optimizer" "package_optimizer")
            ;;
        workstation)
            modules_to_run=("analyzer" "cpu_optimizer" "process_manager" "service_manager" "startup_manager" "desktop_optimizer" "browser_optimizer" "disk_optimizer" "network_optimizer" "cache_cleaner" "package_optimizer")
            ;;
        server)
            modules_to_run=("analyzer" "cpu_optimizer" "process_manager" "service_manager" "disk_optimizer" "network_optimizer" "journal_optimizer" "cache_cleaner" "package_optimizer")
            ;;
        dev)
            modules_to_run=("analyzer" "cpu_optimizer" "process_manager" "service_manager" "startup_manager" "dev_environment" "cache_cleaner" "package_optimizer")
            ;;
        *)
            modules_to_run=("analyzer" "cpu_optimizer" "process_manager" "service_manager" "cache_cleaner")
            ;;
    esac

    if [[ "$LSO_FORCE" != "true" ]]; then
        echo -e "
${C_CYAN}Módulos a ejecutar:${C_RESET}"
        printf '  - %s
' "${modules_to_run[@]}"
        echo -e "  - memory_optimizer ${C_DIM}(al final, después del motor de reglas)${C_RESET}"
        echo
        if ! confirm "¿Deseas continuar con la optimización?"; then
            log_info "Optimización cancelada por el usuario"
            return 0
        fi
    fi

    run_modules "${modules_to_run[@]}"

    run_rule_engine || log_warn "El motor de reglas tuvo problemas"

    # memory_optimizer corre al final a propósito: todos los módulos y
    # acciones del motor de reglas anteriores generan E/S de disco que
    # repuebla la caché de página del kernel, así que liberar memoria antes
    # de ellos no serviría de nada — el usuario vería el RAM alto de nuevo
    # al terminar el resto de la optimización.
    run_module "memory_optimizer" || log_warn "La optimización de memoria tuvo problemas"

    run_module "report" || log_warn "El reporte tuvo problemas"
}
