#!/usr/bin/env bash
# security.sh — Verificaciones de seguridad básicas
check_security() {
    print_header "VERIFICACIÓN DE SEGURIDAD"

    # --- Verificar firewall ---
    print_step "Verificando firewall..."
    if command -v ufw &>/dev/null; then
        local ufw_status
        ufw_status=$(ufw status 2>/dev/null | head -1)
        echo -e "  ${C_DIM}UFW:${C_RESET} ${C_CYAN}${ufw_status}${C_RESET}"
    elif command -v firewall-cmd &>/dev/null; then
        local fw_status
        fw_status=$(firewall-cmd --state 2>/dev/null || echo "not running")
        echo -e "  ${C_DIM}Firewalld:${C_RESET} ${C_CYAN}${fw_status}${C_RESET}"
    else
        log_warn "No se detectó firewall activo"
    fi

    # --- Verificar actualizaciones de seguridad ---
    print_step "Verificando actualizaciones de seguridad..."
    case "$LSO_PACKAGE_MANAGER" in
        apt)
            apt-get -s upgrade 2>/dev/null | grep -i security | head -5 || \
                echo -e "  ${C_GREEN}No hay actualizaciones de seguridad pendientes${C_RESET}"
            ;;
        dnf)
            dnf updateinfo list security 2>/dev/null | head -5 || \
                echo -e "  ${C_GREEN}No hay actualizaciones de seguridad pendientes${C_RESET}"
            ;;
        *)
            log_info "Verificación de seguridad no disponible para este gestor de paquetes"
            ;;
    esac

    # --- Verificar permisos de archivos sensibles ---
    print_step "Verificando permisos de archivos sensibles..."
    local sensitive_files=("/etc/shadow" "/etc/passwd" "/etc/group")
    for file in "${sensitive_files[@]}"; do
        if [[ -f "$file" ]]; then
            local perms
            perms=$(stat -c "%a" "$file" 2>/dev/null)
            local owner
            owner=$(stat -c "%U:%G" "$file" 2>/dev/null)
            echo -e "  ${C_DIM}$(basename "$file"):${C_RESET} ${C_CYAN}${perms} ${owner}${C_RESET}"
        fi
    done

    # --- Verificar usuarios con shell ---
    print_step "Usuarios con shell de login..."
    grep -E "/bin/bash|/bin/zsh|/bin/sh" /etc/passwd 2>/dev/null | \
        awk -F: '{print "  " $1}' | while read line; do
            echo -e "${C_CYAN}$line${C_RESET}"
        done

    print_success "Verificación de seguridad completada"
}
check_security
