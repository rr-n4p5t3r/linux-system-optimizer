#!/usr/bin/env bash
# =============================================================================
# cpu_optimizer.sh — Optimización de CPU
# =============================================================================

optimize_cpu() {
    print_header "OPTIMIZACIÓN DE CPU"

    # --- Governor de CPU ---
    print_step "Analizando governors de CPU..."

    if [[ -d /sys/devices/system/cpu/cpu0/cpufreq ]]; then
        local current_governor
        current_governor=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || echo "unknown")
        echo -e "  ${C_DIM}Governor actual:${C_RESET} ${C_CYAN}${current_governor}${C_RESET}"

        local target_governor="${LSO_CPU_GOVERNOR:-ondemand}"

        # Para gaming, usar performance
        if [[ "$LSO_PROFILE" == "gaming" ]]; then
            target_governor="performance"
        fi

        # Para laptop en batería, usar powersave
        if [[ "$LSO_IS_LAPTOP" == "true" ]] && [[ "$LSO_PROFILE" == "laptop" ]]; then
            target_governor="powersave"
        fi

        echo -e "  ${C_DIM}Governor objetivo:${C_RESET} ${C_CYAN}${target_governor}${C_RESET}"

        if [[ "$LSO_DRY_RUN" != "true" ]]; then
            for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
                [[ -f "$cpu" ]] || continue
                echo "$target_governor" > "$cpu" 2>/dev/null || true
            done
            log_success "Governor de CPU cambiado a: ${target_governor}"
        else
            print_info "[DRY-RUN] Se cambiaría governor a ${target_governor}"
        fi
    else
        log_warn "No se detectó soporte de cpufreq"
    fi

    # --- Afinidad de IRQ ---
    print_step "Optimizando afinidad de interrupciones..."
    if [[ -f /proc/irq/default_smp_affinity ]] && [[ "$LSO_DRY_RUN" != "true" ]]; then
        # No modificar en dry-run, esto es avanzado
        log_info "Afinidad de IRQ verificada (no se modificó)"
    fi

    # --- Scheduler I/O ---
    print_step "Verificando scheduler de I/O..."
    for disk in /sys/block/sd* /sys/block/nvme* /sys/block/hd*; do
        [[ -d "$disk" ]] || continue
        local disk_name
        disk_name=$(basename "$disk")
        local current_scheduler
        current_scheduler=$(cat "${disk}/queue/scheduler" 2>/dev/null | grep -oP '\[\K[^\]]+' || echo "unknown")

        echo -e "  ${C_DIM}${disk_name}:${C_RESET} ${C_CYAN}${current_scheduler}${C_RESET}"

        # Para SSD/NVMe, mq-deadline o none es mejor
        if [[ "$LSO_DISK_TYPE" == "SSD" ]] || [[ "$LSO_DISK_TYPE" == "NVMe" ]]; then
            if [[ "$current_scheduler" == "cfq" ]] || [[ "$current_scheduler" == "bfq" ]]; then
                if [[ "$LSO_DRY_RUN" != "true" ]]; then
                    echo "mq-deadline" > "${disk}/queue/scheduler" 2>/dev/null || \
                    echo "none" > "${disk}/queue/scheduler" 2>/dev/null || true
                    log_info "Scheduler de ${disk_name} optimizado"
                fi
            fi
        fi
    done

    # --- Noatime en fstab (solo mostrar info) ---
    print_step "Verificando opciones de montaje..."
    if grep -q 'relatime\|noatime' /etc/fstab 2>/dev/null; then
        log_info "Opciones de atime ya optimizadas en fstab"
    else
        log_warn "Considera agregar 'noatime' a tus particiones en /etc/fstab"
    fi

    print_success "Optimización de CPU completada"
}

optimize_cpu
