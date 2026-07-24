#!/usr/bin/env bash
# =============================================================================
# package_optimizer.sh — Mantenimiento del gestor de paquetes del sistema
# =============================================================================
# En perfiles automáticos solo hace limpieza segura (clean + autoremove).
# La actualización completa del sistema (upgrade) solo corre con --full,
# nunca de forma automática dentro de un perfil.
# =============================================================================

optimize_packages() {
    print_header "OPTIMIZACIÓN DEL GESTOR DE PAQUETES"

    local pm="$LSO_PACKAGE_MANAGER"
    local pm_script="${LSO_BASE_DIR}/package_managers/${pm}.sh"

    if [[ -z "$pm" ]] || [[ "$pm" == "unknown" ]] || [[ ! -f "$pm_script" ]]; then
        print_warn "Gestor de paquetes no soportado o no detectado: ${pm:-desconocido}"
        return 0
    fi

    source "$pm_script"

    print_step "Limpiando caché de $pm..."
    if [[ "$LSO_DRY_RUN" != "true" ]]; then
        "${pm}_clean" && log_success "Caché de $pm limpiada" || log_warn "No se pudo limpiar caché de $pm"
    else
        print_info "[DRY-RUN] Se limpiaría caché de $pm"
    fi

    print_step "Eliminando paquetes huérfanos..."
    if [[ "$LSO_DRY_RUN" != "true" ]]; then
        "${pm}_autoremove" && log_success "Paquetes huérfanos eliminados" || log_warn "No se pudieron eliminar paquetes huérfanos"
    else
        print_info "[DRY-RUN] Se eliminarían paquetes huérfanos"
    fi

    if [[ "${LSO_FULL:-false}" == "true" ]]; then
        print_step "Actualizando el sistema (modo --full)..."
        if [[ "$LSO_DRY_RUN" != "true" ]]; then
            if confirm "¿Actualizar TODOS los paquetes del sistema ahora?"; then
                "${pm}_update"
                "${pm}_upgrade" && log_success "Sistema actualizado" || log_warn "La actualización tuvo problemas"
            else
                log_info "Actualización completa omitida por el usuario"
            fi
        else
            print_info "[DRY-RUN] Se actualizaría el sistema completo (${pm}_update + ${pm}_upgrade)"
        fi
    else
        print_info "Actualización completa omitida (usa --full para incluirla)"
    fi

    print_success "Optimización de paquetes completada"
}

optimize_packages
