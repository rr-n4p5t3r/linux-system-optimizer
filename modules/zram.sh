#!/usr/bin/env bash
# zram.sh — Configuración de ZRAM
setup_zram() {
    print_header "CONFIGURACIÓN DE ZRAM"

    if [[ "${LSO_ZRAM_ENABLED:-false}" != "true" ]]; then
        print_info "ZRAM está deshabilitado en la configuración"
        return 0
    fi

    # Verificar si zram está disponible
    if ! modprobe zram 2>/dev/null; then
        log_warn "Módulo zram no disponible en el kernel"
        return 0
    fi

    # Verificar si ya está configurado
    if swapon --show=NAME,TYPE 2>/dev/null | grep -q "zram"; then
        log_info "ZRAM ya está configurado"
        return 0
    fi

    print_step "Configurando ZRAM..."

    local ram_total_mb
    ram_total_mb=$(free -m | awk '/^Mem:/{print $2}')
    local zram_percent="${LSO_ZRAM_SIZE_PERCENT:-50}"
    local zram_size_mb=$((ram_total_mb * zram_percent / 100))

    echo -e "  ${C_DIM}RAM total:${C_RESET} ${C_CYAN}${ram_total_mb}MB${C_RESET}"
    echo -e "  ${C_DIM}ZRAM (${zram_percent}%):${C_RESET} ${C_CYAN}${zram_size_mb}MB${C_RESET}"

    if [[ "$LSO_DRY_RUN" != "true" ]]; then
        # Crear dispositivo zram
        echo 1 > /sys/class/zram-control/hot_add 2>/dev/null || true
        local zram_dev
        zram_dev=$(ls /dev/zram* 2>/dev/null | tail -1)

        if [[ -n "$zram_dev" ]]; then
            local zram_block
            zram_block=$(basename "$zram_dev")
            echo "${zram_size_mb}M" > "/sys/block/${zram_block}/disksize" 2>/dev/null
            mkswap "$zram_dev" &>/dev/null
            swapon "$zram_dev" -p 100 &>/dev/null

            # Persistir
            cat > /etc/systemd/system/zram.service << ZRAMEOF
[Unit]
Description=ZRAM Swap
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/sbin/modprobe zram
ExecStart=/bin/sh -c 'echo ${zram_size_mb}M > /sys/block/zram0/disksize && mkswap /dev/zram0 && swapon /dev/zram0 -p 100'
ExecStop=/bin/sh -c 'swapoff /dev/zram0 && echo 1 > /sys/block/zram0/reset'
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
ZRAMEOF

            systemctl enable zram.service 2>/dev/null || true
            log_success "ZRAM configurado: ${zram_size_mb}MB"
        else
            log_warn "No se pudo crear dispositivo ZRAM"
        fi
    else
        print_info "[DRY-RUN] Se configuraría ZRAM de ${zram_size_mb}MB"
    fi

    print_success "Configuración de ZRAM completada"
}
setup_zram
