#!/usr/bin/env bash
# shellcheck disable=SC2154  # variables y arreglos definidos en otros archivos del módulo
# =============================================================================
# network.sh — Revisiones de auditoría: red y firewall
# =============================================================================
# Linux System Optimizer (LSO)
# Autor: Ricardo Rosero <rrosero2000@gmail.com>
# GitHub: https://github.com/rr-n4p5t3r
# Licencia: GPLv3
# =============================================================================

_SYSCTL_FILE="/etc/sysctl.d/99-lso-hardening.conf"

_chk_net_001() {
    local out tools=0 known=() active=""
    if audit_have ufw; then
        tools=$((tools + 1))
        out=$(audit_cmd_ufw_status)
        if [[ "$out" == *"Status: active"* || "$out" == *"Estado: activo"* ]]; then
            active="ufw activo"
        elif [[ "$out" == *inactive* || "$out" == *inactivo* ]]; then
            known+=("ufw inactivo")
        fi
    fi
    if [[ -z "$active" ]] && audit_have firewall-cmd; then
        tools=$((tools + 1))
        out=$(audit_cmd_firewalld_state)
        if [[ "$out" == running* ]]; then
            active="firewalld en ejecución"
        elif [[ -n "$out" ]]; then
            known+=("firewalld $out")
        fi
    fi
    if [[ -z "$active" ]] && audit_have nft; then
        tools=$((tools + 1))
        if out=$(audit_cmd_nft_ruleset); then
            if grep -qE '\b(drop|reject)\b' <<< "$out"; then
                active="reglas nftables con bloqueo"
            else
                known+=("nftables sin reglas de bloqueo")
            fi
        fi
    fi
    if [[ -z "$active" ]] && audit_have iptables; then
        tools=$((tools + 1))
        if out=$(audit_cmd_iptables_rules); then
            if grep -qE -- '^-P INPUT (DROP|REJECT)|-j (DROP|REJECT)' <<< "$out"; then
                active="reglas iptables con bloqueo"
            else
                known+=("iptables acepta todo")
            fi
        fi
    fi

    if [[ -n "$active" ]]; then
        audit_pass "$active"
    elif (( tools == 0 )); then
        audit_fail "No hay herramientas de firewall instaladas (ufw, firewalld, nftables, iptables)"
    elif (( ${#known[@]} )); then
        audit_fail "No se detectó firewall local activo: ${known[*]}"
    elif audit_is_root; then
        audit_skip "No se pudo determinar el estado del firewall"
    else
        audit_skip "Se requiere root para leer las reglas del firewall"
    fi
}

_chk_net_002() {
    if audit_have docker; then
        audit_na "Docker requiere reenvío IPv4"
        return 0
    fi
    audit_check_sysctl net.ipv4.ip_forward "0"
}
_chk_net_003() { audit_check_sysctl net.ipv4.conf.all.accept_redirects "0"; }
_chk_net_004() { audit_check_sysctl net.ipv4.conf.all.send_redirects "0"; }
_chk_net_005() { audit_check_sysctl net.ipv4.conf.all.rp_filter "1 2"; }
_chk_net_006() { audit_check_sysctl net.ipv4.tcp_syncookies "1"; }
_chk_net_007() { audit_check_sysctl net.ipv4.conf.all.log_martians "1"; }
_chk_net_008() { audit_check_sysctl net.ipv4.conf.all.accept_source_route "0"; }
_chk_net_009() { audit_check_sysctl net.ipv4.icmp_echo_ignore_broadcasts "1"; }

_chk_net_010() {
    audit_have ss || { audit_skip "No está disponible el comando ss (iproute2)"; return 0; }
    local proto host port bad=()
    while read -r proto host port; do
        [[ -z "$port" ]] && continue
        audit_is_loopback "$host" && continue
        case "$port" in 21|23|512|513|514) bad+=("$proto/$port") ;; esac
    done < <(audit_listeners)
    if (( ${#bad[@]} )); then
        audit_fail "Servicios inseguros en escucha: ${bad[*]}"
    else
        audit_pass "Sin telnet, FTP ni servicios r* en escucha"
    fi
}

_chk_net_011() {
    audit_have ss || { audit_skip "No está disponible el comando ss (iproute2)"; return 0; }
    local proto host port list=()
    local -A seen=()
    while read -r proto host port; do
        [[ -z "$port" || "$proto" != tcp ]] && continue
        case "$host" in
            0.0.0.0|"[::]"|"*"|"::") ;;
            *) continue ;;
        esac
        [[ -n "${seen[$proto/$port]:-}" ]] && continue
        seen[$proto/$port]=1
        list+=("$proto/$port")
    done < <(audit_listeners)
    if (( ${#list[@]} )); then
        audit_warn "En escucha en todas las interfaces: ${list[*]}"
    else
        audit_pass "Ningún servicio escucha en todas las interfaces"
    fi
}

_fix_sysctl() { printf 'sysctl -w %s=%s y agrega "%s = %s" a %s' "$1" "$2" "$1" "$2" "$_SYSCTL_FILE"; }

audit_register NET-001 high network "Firewall local activo" _chk_net_001 "Activa un firewall: ufw enable (Debian/Ubuntu) o systemctl enable --now firewalld (Fedora/RHEL)"
audit_register NET-002 medium network "Reenvío IPv4 desactivado" _chk_net_002 "$(_fix_sysctl net.ipv4.ip_forward 0)"
audit_register NET-003 medium network "Rechaza ICMP redirects" _chk_net_003 "$(_fix_sysctl net.ipv4.conf.all.accept_redirects 0)"
audit_register NET-004 low network "No envía ICMP redirects" _chk_net_004 "$(_fix_sysctl net.ipv4.conf.all.send_redirects 0)"
audit_register NET-005 medium network "Reverse path filtering activo" _chk_net_005 "$(_fix_sysctl net.ipv4.conf.all.rp_filter 1)"
audit_register NET-006 medium network "SYN cookies activas" _chk_net_006 "$(_fix_sysctl net.ipv4.tcp_syncookies 1)"
audit_register NET-007 low network "Registra paquetes marcianos" _chk_net_007 "$(_fix_sysctl net.ipv4.conf.all.log_martians 1)"
audit_register NET-008 medium network "Rechaza source routing" _chk_net_008 "$(_fix_sysctl net.ipv4.conf.all.accept_source_route 0)"
audit_register NET-009 low network "Ignora ping a broadcast" _chk_net_009 "$(_fix_sysctl net.ipv4.icmp_echo_ignore_broadcasts 1)"
audit_register NET-010 high network "Sin servicios inseguros escuchando" _chk_net_010 "Desinstala o desactiva telnet, FTP y rsh/rlogin (systemctl disable --now <servicio>); usa SSH/SFTP"
audit_register NET-011 info network "Servicios TCP expuestos en todas las interfaces" _chk_net_011 "Revisa si cada servicio necesita escuchar en 0.0.0.0; si no, limítalo a 127.0.0.1 o filtra con el firewall"
