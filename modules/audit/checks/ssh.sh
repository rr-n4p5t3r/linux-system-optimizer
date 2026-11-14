#!/usr/bin/env bash
# shellcheck disable=SC2154  # variables y arreglos definidos en otros archivos del módulo
# =============================================================================
# ssh.sh — Revisiones de auditoría: servidor OpenSSH
# =============================================================================
# Linux System Optimizer (LSO)
# Autor: Ricardo Rosero <rrosero2000@gmail.com>
# GitHub: https://github.com/rr-n4p5t3r
# Licencia: GPLv3
# =============================================================================

# Devuelve 0 si sshd está presente; si no, marca NA y devuelve 1.
_ssh_require() {
    audit_sshd_present && return 0
    audit_na "OpenSSH server no está instalado"
    return 1
}

# Convierte un tiempo de sshd (30, 2m, 1h30m) a segundos.
_ssh_seconds() {
    local v="$1" total=0 n
    [[ "$v" =~ ^[0-9]+$ ]] && { echo "$v"; return 0; }
    while [[ "$v" =~ ^([0-9]+)([smhdwSMHDW])(.*)$ ]]; do
        n="${BASH_REMATCH[1]}"
        case "${BASH_REMATCH[2],,}" in
            s) total=$((total + n)) ;;
            m) total=$((total + n * 60)) ;;
            h) total=$((total + n * 3600)) ;;
            d) total=$((total + n * 86400)) ;;
            w) total=$((total + n * 604800)) ;;
        esac
        v="${BASH_REMATCH[3]}"
    done
    [[ -z "$v" ]] || return 1
    echo "$total"
}

_chk_ssh_001() {
    _ssh_require || return 0
    local v
    v=$(audit_sshd_value permitrootlogin prohibit-password)
    case "$v" in
        no|prohibit-password|without-password) audit_pass "PermitRootLogin $v" ;;
        *) audit_fail "PermitRootLogin $v" ;;
    esac
}

_chk_ssh_002() {
    _ssh_require || return 0
    local v
    v=$(audit_sshd_value passwordauthentication yes)
    [[ "$v" == no ]] && audit_pass "PasswordAuthentication no" || audit_fail "PasswordAuthentication $v"
}

_chk_ssh_003() {
    _ssh_require || return 0
    local v
    v=$(audit_sshd_value permitemptypasswords no)
    [[ "$v" == no ]] && audit_pass "PermitEmptyPasswords no" || audit_fail "PermitEmptyPasswords $v"
}

_chk_ssh_004() {
    _ssh_require || return 0
    local v
    v=$(audit_sshd_value maxauthtries 6)
    if [[ "$v" =~ ^[0-9]+$ ]] && (( v <= 4 )); then
        audit_pass "MaxAuthTries $v"
    else
        audit_fail "MaxAuthTries $v"
    fi
}

_chk_ssh_005() {
    _ssh_require || return 0
    local v
    v=$(audit_sshd_value x11forwarding no)
    [[ "$v" == no ]] && audit_pass "X11Forwarding no" || audit_fail "X11Forwarding $v"
}

_chk_ssh_006() {
    _ssh_require || return 0
    local v weak=() c
    v=$(audit_sshd_value ciphers "")
    if [[ -z "$v" ]]; then
        audit_pass "Cifrados por defecto de OpenSSH"
        return 0
    fi
    for c in ${v//,/ }; do
        [[ "$c" == *cbc* || "$c" == *arcfour* || "$c" == *3des* ]] && weak+=("$c")
    done
    if (( ${#weak[@]} )); then
        audit_fail "Cifrados débiles: ${weak[*]}"
    else
        audit_pass "Ciphers $v"
    fi
}

_chk_ssh_007() {
    _ssh_require || return 0
    local v s
    v=$(audit_sshd_value logingracetime 120)
    if s=$(_ssh_seconds "$v") && (( s > 0 && s <= 60 )); then
        audit_pass "LoginGraceTime $v"
    else
        audit_fail "LoginGraceTime $v"
    fi
}

_chk_ssh_008() {
    _ssh_require || return 0
    local perm uid
    perm=$(audit_perm /etc/ssh/sshd_config) || { audit_skip "No se pudieron leer los permisos de sshd_config"; return 0; }
    uid=$(audit_owner_uid /etc/ssh/sshd_config) || uid=""
    if [[ "$uid" != 0 ]]; then
        audit_fail "sshd_config pertenece al UID ${uid:-?}, no a root"
    elif (( 8#$perm & 8#022 )); then
        audit_fail "sshd_config tiene permisos $perm (escribible por grupo u otros)"
    else
        audit_pass "sshd_config con permisos $perm, dueño root"
    fi
}

_chk_ssh_009() {
    _ssh_require || return 0
    local f perm bad=() n=0
    for f in "$(audit_path /etc/ssh)"/ssh_host_*_key; do
        [[ -e "$f" ]] || continue
        n=$((n + 1))
        perm=$(stat -c '%a' "$f" 2>/dev/null) || { audit_skip "No se pudieron leer los permisos de $(basename "$f")"; return 0; }
        (( 8#$perm & 8#077 )) && bad+=("$(basename "$f") ($perm)")
    done
    if (( n == 0 )); then
        audit_skip "No se encontraron llaves privadas del host"
    elif (( ${#bad[@]} )); then
        audit_fail "Llaves con permisos abiertos: ${bad[*]}"
    else
        audit_pass "$n llaves privadas del host con permisos correctos"
    fi
}

_chk_ssh_010() {
    _ssh_require || return 0
    local v s
    v=$(audit_sshd_value clientaliveinterval 0)
    if s=$(_ssh_seconds "$v") && (( s > 0 )); then
        audit_pass "ClientAliveInterval $v"
    else
        audit_fail "ClientAliveInterval $v (las sesiones inactivas no se cierran)"
    fi
}

_CFG="en /etc/ssh/sshd_config (o en /etc/ssh/sshd_config.d/) y luego: systemctl reload sshd"
audit_register SSH-001 high ssh "Root no puede entrar por SSH con contraseña" _chk_ssh_001 "PermitRootLogin prohibit-password $_CFG"
audit_register SSH-002 high ssh "SSH no acepta contraseñas" _chk_ssh_002 "PasswordAuthentication no $_CFG (antes, configura tu llave pública)"
audit_register SSH-003 critical ssh "SSH no acepta contraseñas vacías" _chk_ssh_003 "PermitEmptyPasswords no $_CFG"
audit_register SSH-004 medium ssh "Intentos de autenticación limitados" _chk_ssh_004 "MaxAuthTries 4 $_CFG"
audit_register SSH-005 medium ssh "Reenvío X11 desactivado" _chk_ssh_005 "X11Forwarding no $_CFG"
audit_register SSH-006 medium ssh "Sin cifrados débiles" _chk_ssh_006 "Quita los cifrados cbc, arcfour y 3des de la línea Ciphers $_CFG"
audit_register SSH-007 low ssh "Tiempo de gracia de login corto" _chk_ssh_007 "LoginGraceTime 60 $_CFG"
audit_register SSH-008 medium ssh "sshd_config protegido" _chk_ssh_008 "chown root:root /etc/ssh/sshd_config && chmod 600 /etc/ssh/sshd_config"
audit_register SSH-009 critical ssh "Llaves privadas del host protegidas" _chk_ssh_009 "chmod 600 /etc/ssh/ssh_host_*_key"
audit_register SSH-010 low ssh "Sesiones inactivas se cierran" _chk_ssh_010 "ClientAliveInterval 300 $_CFG"
unset _CFG
