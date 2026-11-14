#!/usr/bin/env bash
# =============================================================================
# cache_cleaner.sh — Limpieza de cachés del sistema
# =============================================================================

clean_caches() {
    print_header "LIMPIEZA DE CACHÉS"

    local total_freed=0

    # --- Caché de paquetes APT ---
    if command -v apt &>/dev/null; then
        print_step "Limpiando caché de APT..."
        local apt_before=""
        apt_before=$(du -sb /var/cache/apt/archives 2>/dev/null | cut -f1 || echo "0")

        if [[ "$LSO_DRY_RUN" != "true" ]]; then
            apt-get clean 2>/dev/null && \
                apt-get autoclean 2>/dev/null && \
                log_success "Caché de APT limpiada" || \
                log_warn "No se pudo limpiar caché de APT"
        else
            print_info "[DRY-RUN] Se limpiaría caché de APT"
        fi

        local apt_after=""
        apt_after=$(du -sb /var/cache/apt/archives 2>/dev/null | cut -f1 || echo "0")
        local apt_freed=$((apt_before - apt_after))
        total_freed=$((total_freed + apt_freed))
        [[ "$apt_freed" -gt 0 ]] && echo -e "  ${C_GREEN}Liberado: $(human_size "$apt_freed")${C_RESET}"
    fi

    # --- Caché de DNF ---
    if command -v dnf &>/dev/null; then
        print_step "Limpiando caché de DNF..."
        if [[ "$LSO_DRY_RUN" != "true" ]]; then
            dnf clean all 2>/dev/null && \
                log_success "Caché de DNF limpiada" || \
                log_warn "No se pudo limpiar caché de DNF"
        else
            print_info "[DRY-RUN] Se limpiaría caché de DNF"
        fi
    fi

    # --- Caché de Pacman ---
    if command -v pacman &>/dev/null; then
        print_step "Limpiando caché de Pacman..."
        if [[ "$LSO_DRY_RUN" != "true" ]]; then
            # Mantener solo los últimos 3 paquetes de cada uno
            paccache -rk3 2>/dev/null && \
                log_success "Caché de Pacman limpiada" || \
                log_warn "No se pudo limpiar caché de Pacman"
        else
            print_info "[DRY-RUN] Se limpiaría caché de Pacman"
        fi
    fi

    # --- Caché de Zypper ---
    if command -v zypper &>/dev/null; then
        print_step "Limpiando caché de Zypper..."
        if [[ "$LSO_DRY_RUN" != "true" ]]; then
            zypper clean 2>/dev/null && \
                log_success "Caché de Zypper limpiada" || \
                log_warn "No se pudo limpiar caché de Zypper"
        else
            print_info "[DRY-RUN] Se limpiaría caché de Zypper"
        fi
    fi

    # --- Cachés de navegadores ---
    print_step "Limpiando cachés de navegadores..."
    local browser_cache_dirs=(
        "$HOME/.cache/mozilla"
        "$HOME/.cache/google-chrome"
        "$HOME/.cache/chromium"
        "$HOME/.cache/BraveSoftware"
        "$HOME/.cache/opera"
        "$HOME/.cache/vivaldi"
    )

    for cache_dir in "${browser_cache_dirs[@]}"; do
        if [[ -d "$cache_dir" ]]; then
            local bsize=""
            bsize=$(du -sb "$cache_dir" 2>/dev/null | cut -f1 || echo "0")

            if [[ "$LSO_DRY_RUN" != "true" ]]; then
                # Solo limpiar caché de más de 30 días
                find "$cache_dir" -type f -atime +30 -delete 2>/dev/null || true
            fi

            local bsize_after=""
            bsize_after=$(du -sb "$cache_dir" 2>/dev/null | cut -f1 || echo "0")
            local bfreed=$((bsize - bsize_after))
            total_freed=$((total_freed + bfreed))
            [[ "$bfreed" -gt 0 ]] && echo -e "  ${C_GREEN}$(basename "$cache_dir"): $(human_size "$bfreed")${C_RESET}"
        fi
    done

    # --- Caché de thumbnails ---
    print_step "Limpiando caché de miniaturas..."
    local thumb_dir="$HOME/.cache/thumbnails"
    if [[ -d "$thumb_dir" ]]; then
        local thumb_before=""
        thumb_before=$(du -sb "$thumb_dir" 2>/dev/null | cut -f1 || echo "0")

        if [[ "$LSO_DRY_RUN" != "true" ]]; then
            find "$thumb_dir" -type f -atime +60 -delete 2>/dev/null || true
        fi

        local thumb_after=""
        thumb_after=$(du -sb "$thumb_dir" 2>/dev/null | cut -f1 || echo "0")
        local thumb_freed=$((thumb_before - thumb_after))
        total_freed=$((total_freed + thumb_freed))
        [[ "$thumb_freed" -gt 0 ]] && echo -e "  ${C_GREEN}Miniaturas: $(human_size "$thumb_freed")${C_RESET}"
    fi

    # --- Logs antiguos ---
    print_step "Rotando logs antiguos..."
    if [[ "$LSO_DRY_RUN" != "true" ]]; then
        journalctl --vacuum-time=30d 2>/dev/null && \
            log_success "Logs de journald rotados" || true

        find /var/log -name "*.log.*" -type f -mtime +30 -delete 2>/dev/null || true
        find /var/log -name "*.gz" -type f -mtime +60 -delete 2>/dev/null || true
    fi

    # --- Caché de fontconfig ---
    print_step "Limpiando caché de fuentes..."
    if [[ "$LSO_DRY_RUN" != "true" ]]; then
        fc-cache -fv 2>/dev/null && \
            log_success "Caché de fuentes regenerada" || true
    fi

    # --- Resumen ---
    print_header "RESUMEN DE LIMPIEZA"
    if [[ "$total_freed" -gt 0 ]]; then
        print_success "Espacio total liberado: $(human_size "$total_freed")"
    else
        print_info "No se liberó espacio significativo (sistema ya limpio)"
    fi
}

clean_caches
