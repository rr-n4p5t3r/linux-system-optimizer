#!/usr/bin/env bash
# =============================================================================
# docker_optimizer.sh — Limpieza y diagnóstico de Docker/Podman
# =============================================================================

optimize_docker() {
    print_header "OPTIMIZACIÓN DE DOCKER/PODMAN"

    local engine=""
    command -v docker &>/dev/null && engine="docker"
    [[ -z "$engine" ]] && command -v podman &>/dev/null && engine="podman"

    if [[ -z "$engine" ]]; then
        print_info "No se detectó Docker ni Podman instalados"
        return 0
    fi

    print_step "Uso de disco (${engine})..."
    "$engine" system df 2>/dev/null | while read -r line; do
        echo -e "  ${C_CYAN}${line}${C_RESET}"
    done

    print_step "Limpieza de recursos no usados..."
    if [[ "$LSO_DRY_RUN" != "true" ]]; then
        if confirm "¿Limpiar contenedores detenidos, redes e imágenes 'dangling' de ${engine}?"; then
            "$engine" system prune -f 2>/dev/null && \
                log_success "Limpieza de ${engine} completada" || \
                log_warn "No se pudo completar la limpieza de ${engine}"
        fi

        echo
        print_warn "Limpiar volúmenes puede borrar datos de contenedores (bases de datos, etc.)"
        if confirm "¿Limpiar también volúmenes no usados? (ADVERTENCIA: pérdida de datos posible)"; then
            "$engine" volume prune -f 2>/dev/null && \
                log_success "Volúmenes no usados eliminados" || \
                log_warn "No se pudo limpiar volúmenes"
        else
            log_info "Limpieza de volúmenes omitida"
        fi
    else
        print_info "[DRY-RUN] Se ofrecería limpiar contenedores/redes/imágenes dangling, y por separado, volúmenes no usados"
    fi

    print_success "Optimización de ${engine} completada"
}
optimize_docker
