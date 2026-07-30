#!/usr/bin/env bash
# =============================================================================
# plugin_loader.sh — Cargador dinámico de plugins para LSO
# =============================================================================
# Linux System Optimizer (LSO)
# Autor: Ricardo Rosero <rrosero2000@gmail.com>
# GitHub: https://github.com/rr-n4p5t3r
# Licencia: GPLv3
# =============================================================================


LSO_PLUGINS_DIR="${LSO_BASE_DIR}/plugins"
LSO_LOADED_PLUGINS=()

load_plugin() {
    local plugin_path="$1"
    local plugin_name=""
    plugin_name=$(basename "$plugin_path" .sh)

    if [[ ! -f "$plugin_path" ]]; then
        log_error "Plugin no encontrado: $plugin_path"
        return 1
    fi

    for loaded in "${LSO_LOADED_PLUGINS[@]:-}"; do
        [[ "$loaded" == "$plugin_name" ]] && return 0
    done

    log_info "Cargando plugin: $plugin_name"
    # shellcheck source=/dev/null
    source "$plugin_path"
    LSO_LOADED_PLUGINS+=("$plugin_name")
    log_success "Plugin cargado: $plugin_name"
}

load_all_plugins() {
    if [[ ! -d "$LSO_PLUGINS_DIR" ]]; then
        log_debug "Directorio de plugins no existe: $LSO_PLUGINS_DIR"
        return 0
    fi

    local plugin_count=0
    for plugin in "$LSO_PLUGINS_DIR"/*.sh; do
        [[ -f "$plugin" ]] || continue
        load_plugin "$plugin"
        ((plugin_count++))
    done

    log_info "Total plugins cargados: $plugin_count"
}

list_plugins() {
    print_header "PLUGINS DISPONIBLES"

    if [[ ! -d "$LSO_PLUGINS_DIR" ]] || [[ -z "$(ls -A "$LSO_PLUGINS_DIR"/*.sh 2>/dev/null)" ]]; then
        print_info "No hay plugins disponibles"
        return 0
    fi

    for plugin in "$LSO_PLUGINS_DIR"/*.sh; do
        local name status
        name=$(basename "$plugin" .sh)

        local is_loaded=false
        for loaded in "${LSO_LOADED_PLUGINS[@]:-}"; do
            if [[ "$loaded" == "$name" ]]; then
                is_loaded=true
                break
            fi
        done

        if $is_loaded; then
            status="${C_GREEN}[CARGADO]${C_RESET}"
        else
            status="${C_DIM}[NO CARGADO]${C_RESET}"
        fi

        echo -e "  ${C_CYAN}$name${C_RESET} $status"
    done
}

plugin_hook() {
    local hook_name="$1"
    shift

    for plugin in "${LSO_LOADED_PLUGINS[@]:-}"; do
        local func_name="${plugin}_${hook_name}"
        if declare -f "$func_name" &>/dev/null; then
            log_debug "Ejecutando hook $hook_name en plugin $plugin"
            "$func_name" "$@"
        fi
    done
}
