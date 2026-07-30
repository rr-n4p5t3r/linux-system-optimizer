#!/usr/bin/env bash
# security.sh — Verificaciones de seguridad básicas
check_security() {
    print_header "VERIFICACIÓN DE SEGURIDAD"

    LSO_SECURITY_REPORT="=== VERIFICACIÓN DE SEGURIDAD ===\n"
    LSO_SECURITY_REPORT+="Fecha: $(date)\n\n"

    # --- Verificar firewall ---
    print_step "Verificando firewall..."
    LSO_SECURITY_REPORT+="[FIREWALL]\n"
    if command -v ufw &>/dev/null; then
        local ufw_status
        ufw_status=$(ufw status 2>/dev/null | head -1)
        echo -e "  ${C_DIM}UFW:${C_RESET} ${C_CYAN}${ufw_status}${C_RESET}"
        LSO_SECURITY_REPORT+="  UFW: ${ufw_status}\n"
    elif command -v firewall-cmd &>/dev/null; then
        local fw_status
        fw_status=$(firewall-cmd --state 2>/dev/null || echo "not running")
        echo -e "  ${C_DIM}Firewalld:${C_RESET} ${C_CYAN}${fw_status}${C_RESET}"
        LSO_SECURITY_REPORT+="  Firewalld: ${fw_status}\n"
    else
        log_warn "No se detectó firewall activo"
        LSO_SECURITY_REPORT+="  No se detectó firewall activo\n"
    fi
    LSO_SECURITY_REPORT+="\n"

    # --- Verificar actualizaciones de seguridad ---
    print_step "Verificando actualizaciones de seguridad..."
    LSO_SECURITY_REPORT+="[ACTUALIZACIONES DE SEGURIDAD]\n"
    local sec_updates=""
    case "$LSO_PACKAGE_MANAGER" in
        apt)
            sec_updates=$(apt-get -s upgrade 2>/dev/null | grep -i security | head -5)
            ;;
        dnf)
            sec_updates=$(dnf updateinfo list security 2>/dev/null | head -5)
            ;;
        *)
            log_info "Verificación de seguridad no disponible para este gestor de paquetes"
            LSO_SECURITY_REPORT+="  No disponible para ${LSO_PACKAGE_MANAGER:-este gestor de paquetes}\n"
            ;;
    esac
    if [[ -n "$sec_updates" ]]; then
        echo "$sec_updates"
        LSO_SECURITY_REPORT+="${sec_updates}\n"
    elif [[ "$LSO_PACKAGE_MANAGER" == "apt" || "$LSO_PACKAGE_MANAGER" == "dnf" ]]; then
        echo -e "  ${C_GREEN}No hay actualizaciones de seguridad pendientes${C_RESET}"
        LSO_SECURITY_REPORT+="  No hay actualizaciones de seguridad pendientes\n"
    fi
    LSO_SECURITY_REPORT+="\n"

    # --- Verificar permisos de archivos sensibles ---
    print_step "Verificando permisos de archivos sensibles..."
    LSO_SECURITY_REPORT+="[ARCHIVOS SENSIBLES]\n"
    local sensitive_files=("/etc/shadow" "/etc/passwd" "/etc/group")
    for file in "${sensitive_files[@]}"; do
        if [[ -f "$file" ]]; then
            local perms
            perms=$(stat -c "%a" "$file" 2>/dev/null)
            local owner
            owner=$(stat -c "%U:%G" "$file" 2>/dev/null)
            echo -e "  ${C_DIM}$(basename "$file"):${C_RESET} ${C_CYAN}${perms} ${owner}${C_RESET}"
            LSO_SECURITY_REPORT+="  $(basename "$file"): ${perms} ${owner}\n"
        fi
    done
    LSO_SECURITY_REPORT+="\n"

    # --- Verificar usuarios con shell ---
    print_step "Usuarios con shell de login..."
    LSO_SECURITY_REPORT+="[USUARIOS CON SHELL DE LOGIN]\n"
    local login_users
    login_users=$(grep -E "/bin/bash|/bin/zsh|/bin/sh" /etc/passwd 2>/dev/null | awk -F: '{print $1}')
    if [[ -n "$login_users" ]]; then
        echo "$login_users" | while read -r line; do
            echo -e "  ${C_CYAN}$line${C_RESET}"
        done
        LSO_SECURITY_REPORT+="$(echo "$login_users" | sed 's/^/  /')\n"
    fi

    print_success "Verificación de seguridad completada"
}
check_security
