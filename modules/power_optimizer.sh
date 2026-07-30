#!/usr/bin/env bash
# =============================================================================
# power_optimizer.sh — Gestión de energía (TLP / powertop)
# =============================================================================
# No instala TLP ni powertop si no están presentes — igual que el resto de
# LSO, solo ajusta software que el usuario ya tiene instalado.
# =============================================================================

optimize_power() {
    print_header "GESTIÓN DE ENERGÍA"

    local did_something=false

    if command -v tlp &>/dev/null; then
        print_step "TLP detectado..."
        if systemctl is-active --quiet tlp 2>/dev/null; then
            print_success "TLP ya está activo"
        else
            if [[ "$LSO_DRY_RUN" != "true" ]]; then
                systemctl enable --now tlp 2>/dev/null && \
                    log_success "TLP habilitado e iniciado" || \
                    log_warn "No se pudo habilitar TLP"
            else
                print_info "[DRY-RUN] Se habilitaría e iniciaría TLP"
            fi
        fi
        did_something=true
    fi

    if command -v powertop &>/dev/null; then
        print_step "powertop detectado..."
        if [[ "$LSO_DRY_RUN" != "true" ]]; then
            if confirm "¿Aplicar 'powertop --auto-tune' ahora? (efecto se revierte al reiniciar)"; then
                powertop --auto-tune &>/dev/null && \
                    log_success "powertop --auto-tune aplicado" || \
                    log_warn "No se pudo aplicar powertop --auto-tune"
            fi
        else
            print_info "[DRY-RUN] Se ofrecería aplicar powertop --auto-tune"
        fi
        did_something=true
    fi

    if ! $did_something; then
        print_info "No se detectó TLP ni powertop instalados — instálalos con tu gestor de paquetes si quieres que LSO los gestione"
    fi

    print_success "Gestión de energía completada"
}
optimize_power
