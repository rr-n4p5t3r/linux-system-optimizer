#!/usr/bin/env bash
# journal_optimizer.sh — Optimización de journald
optimize_journal() {
    print_header "OPTIMIZACIÓN DE JOURNALD"

    local journal_conf="/etc/systemd/journald.conf"

    if [[ ! -f "$journal_conf" ]]; then
        log_warn "journald.conf no encontrado"
        return 0
    fi

    print_step "Configurando límites de journald..."

    if [[ "$LSO_DRY_RUN" != "true" ]]; then
        backup_file "$journal_conf" 2>/dev/null || true

        # Crear override
        mkdir -p /etc/systemd/journald.conf.d
        cat > /etc/systemd/journald.conf.d/99-lso.conf << JOURNALEOF
[Journal]
SystemMaxUse=${LSO_JOURNAL_MAX_SIZE:-500M}
SystemMaxFiles=${LSO_JOURNAL_MAX_FILES:-5}
MaxFileSec=1week
Compress=yes
JOURNALEOF

        systemctl restart systemd-journald 2>/dev/null && \
            log_success "Journald optimizado" || \
            log_warn "No se pudo reiniciar journald"
    else
        print_info "[DRY-RUN] Se configuraría journald"
    fi

    # Limpiar logs antiguos
    print_step "Limpiando logs antiguos..."
    if [[ "$LSO_DRY_RUN" != "true" ]]; then
        journalctl --vacuum-time=30d 2>/dev/null && \
            log_success "Logs antiguos limpiados" || true
    fi

    print_success "Optimización de journald completada"
}
optimize_journal
