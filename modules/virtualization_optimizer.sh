#!/usr/bin/env bash
# =============================================================================
# virtualization_optimizer.sh — Optimización de KVM/libvirt
# =============================================================================

optimize_virtualization() {
    print_header "VIRTUALIZACIÓN (KVM)"

    if [[ -e /dev/kvm ]]; then
        print_success "Aceleración KVM disponible (/dev/kvm)"
    else
        print_info "No se detectó /dev/kvm — la CPU o la BIOS pueden no tener virtualización habilitada"
    fi

    if ! service_exists "libvirtd"; then
        print_info "libvirtd no está instalado"
        return 0
    fi

    print_step "Servicio libvirtd..."
    if systemctl is-active --quiet libvirtd 2>/dev/null; then
        print_success "libvirtd ya está activo"
    else
        if [[ "$LSO_DRY_RUN" != "true" ]]; then
            if confirm "¿Iniciar y habilitar libvirtd?"; then
                systemctl enable --now libvirtd 2>/dev/null && \
                    log_success "libvirtd iniciado y habilitado" || \
                    log_warn "No se pudo iniciar libvirtd"
            fi
        else
            print_info "[DRY-RUN] Se ofrecería iniciar y habilitar libvirtd"
        fi
    fi

    if [[ -n "${SUDO_USER:-}" ]]; then
        print_step "Grupos de virtualización para ${SUDO_USER}..."
        local in_groups
        in_groups=$(groups "$SUDO_USER" 2>/dev/null)

        for grp in libvirt kvm; do
            if getent group "$grp" &>/dev/null && [[ "$in_groups" != *"$grp"* ]]; then
                if [[ "$LSO_DRY_RUN" != "true" ]]; then
                    if confirm "¿Agregar a ${SUDO_USER} al grupo '$grp'? (requiere cerrar sesión para aplicar)"; then
                        usermod -aG "$grp" "$SUDO_USER" 2>/dev/null && \
                            log_success "${SUDO_USER} agregado al grupo $grp" || \
                            log_warn "No se pudo agregar al grupo $grp"
                    fi
                else
                    print_info "[DRY-RUN] Se ofrecería agregar a ${SUDO_USER} al grupo '$grp'"
                fi
            fi
        done
    fi

    print_step "Ajustando hugepages..."
    local target_hugepages="${LSO_KVM_HUGEPAGES:-0}"
    if [[ "$target_hugepages" -gt 0 ]]; then
        if [[ "$LSO_DRY_RUN" != "true" ]]; then
            [[ "$LSO_AUTO_BACKUP" == "true" ]] && backup_file /etc/sysctl.conf 2>/dev/null

            sysctl -w "vm.nr_hugepages=${target_hugepages}" &>/dev/null

            if grep -q "^vm.nr_hugepages" /etc/sysctl.conf 2>/dev/null; then
                sed -i "s/^vm.nr_hugepages=.*/vm.nr_hugepages=${target_hugepages}/" /etc/sysctl.conf
            else
                echo "vm.nr_hugepages=${target_hugepages}" >> /etc/sysctl.conf
            fi

            log_success "vm.nr_hugepages ajustado a ${target_hugepages}"
        else
            print_info "[DRY-RUN] Se ajustaría vm.nr_hugepages a ${target_hugepages}"
        fi
    else
        print_info "Hugepages no configuradas (LSO_KVM_HUGEPAGES=0) — omitido"
    fi

    print_success "Optimización de virtualización completada"
}
optimize_virtualization
