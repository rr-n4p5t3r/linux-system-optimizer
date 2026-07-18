#!/usr/bin/env bash
# desktop_optimizer.sh — Optimización del escritorio detectado
optimize_desktop() {
    print_header "OPTIMIZACIÓN DE ESCRITORIO"

    if [[ -z "$LSO_DESKTOP" ]] || [[ "$LSO_DESKTOP" == "unknown" ]]; then
        log_warn "Escritorio no detectado"
        return 0
    fi

    local desktop_script="${LSO_BASE_DIR}/desktops/${LSO_DESKTOP}.sh"

    if [[ -f "$desktop_script" ]]; then
        log_info "Cargando optimizaciones para: $LSO_DESKTOP"
        # shellcheck source=/dev/null
        source "$desktop_script"
    else
        log_warn "No hay script de optimización para: $LSO_DESKTOP"
    fi

    # --- Optimizaciones generales de escritorio ---
    print_step "Aplicando optimizaciones generales..."

    # Deshabilitar indexación global si aún está activa
    if command -v tracker &>/dev/null; then
        tracker daemon -t 2>/dev/null || true
        tracker daemon -k 2>/dev/null || true
    fi

    # Limpiar caché de iconos
    if [[ -d "$HOME/.cache/icon-cache.kcache" ]]; then
        rm -f "$HOME/.cache/icon-cache.kcache" 2>/dev/null || true
    fi

    print_success "Escritorio optimizado"
}
optimize_desktop
