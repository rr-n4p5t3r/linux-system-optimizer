#!/usr/bin/env bash
# shellcheck disable=SC2154  # variables y arreglos definidos en otros archivos del módulo
# =============================================================================
# accounts.sh — Revisiones de auditoría: cuentas y contraseñas
# =============================================================================
# Linux System Optimizer (LSO)
# Autor: Ricardo Rosero <rrosero2000@gmail.com>
# GitHub: https://github.com/rr-n4p5t3r
# Licencia: GPLv3
# =============================================================================
# Nunca se muestran hashes de contraseñas: solo nombres de usuario.

# Valor de una clave de /etc/login.defs (vacío si no está).
_acc_login_defs() {
    awk -v k="$1" '$1==k {print $2; exit}' "$(audit_path /etc/login.defs)" 2>/dev/null
}

_acc_rel() { local p="$1"; printf '%s' "${p#"${AUDIT_ROOT:-}"}"; }

_chk_acc_001() {
    local users
    users=$(awk -F: '$3==0 && $1!="root" {print $1}' "$(audit_path /etc/passwd)" 2>/dev/null | paste -sd, -)
    if [[ -n "$users" ]]; then
        audit_fail "Cuentas con UID 0 además de root: $users"
    else
        audit_pass "Solo root tiene UID 0"
    fi
}

_chk_acc_002() {
    local shadow users
    shadow=$(audit_path /etc/shadow)
    [[ -r "$shadow" ]] || { audit_skip "Se requiere root para leer /etc/shadow"; return 0; }
    users=$(awk -F: '$2=="" {print $1}' "$shadow" | paste -sd, -)
    if [[ -n "$users" ]]; then
        audit_fail "Cuentas sin contraseña: $users"
    else
        audit_pass "Todas las cuentas tienen contraseña o están bloqueadas"
    fi
}

_chk_acc_003() {
    local perm uid
    perm=$(audit_perm /etc/shadow) || { audit_skip "No existe /etc/shadow"; return 0; }
    uid=$(audit_owner_uid /etc/shadow) || uid=""
    if [[ "$uid" != 0 ]]; then
        audit_fail "/etc/shadow pertenece al UID ${uid:-?}, no a root"
    elif (( 8#$perm & 8#037 )); then
        audit_fail "/etc/shadow tiene permisos $perm (máximo recomendado 640)"
    else
        audit_pass "/etc/shadow con permisos $perm"
    fi
}

_chk_acc_004() {
    local perm
    perm=$(audit_perm /etc/passwd) || { audit_skip "No existe /etc/passwd"; return 0; }
    if (( 8#$perm & 8#022 )); then
        audit_fail "/etc/passwd tiene permisos $perm (escribible por grupo u otros)"
    else
        audit_pass "/etc/passwd con permisos $perm"
    fi
}

_chk_acc_005() {
    [[ -r "$(audit_path /etc/login.defs)" ]] || { audit_skip "No existe /etc/login.defs"; return 0; }
    local v
    v=$(_acc_login_defs PASS_MAX_DAYS)
    if [[ "$v" =~ ^[0-9]+$ ]] && (( v <= 365 )); then
        audit_pass "PASS_MAX_DAYS $v"
    else
        audit_fail "PASS_MAX_DAYS ${v:-sin definir}"
    fi
}

_chk_acc_006() {
    local f v best=""
    for f in "$(audit_path /etc/security/pwquality.conf)" "$(audit_path /etc/security/pwquality.conf.d)"/*.conf; do
        [[ -r "$f" ]] || continue
        v=$(awk -F= '/^[[:space:]]*minlen[[:space:]]*=/ {gsub(/[[:space:]]/, "", $2); print $2}' "$f" | tail -1)
        [[ "$v" =~ ^[0-9]+$ ]] && best="$v"
    done
    if [[ -z "$best" ]]; then
        for f in "$(audit_path /etc/pam.d/common-password)" "$(audit_path /etc/pam.d/system-auth)"; do
            [[ -r "$f" ]] || continue
            v=$(grep -E '^[[:space:]]*password.*(pam_pwquality|pam_unix|pam_cracklib)' "$f" \
                | grep -oE 'minlen=[0-9]+' | tail -1 | cut -d= -f2)
            [[ "$v" =~ ^[0-9]+$ ]] && best="$v"
        done
    fi
    if [[ -z "$best" ]]; then
        audit_fail "No se encontró una política de longitud mínima (minlen)"
    elif (( best >= 8 )); then
        audit_pass "Longitud mínima de contraseña: $best"
    else
        audit_fail "Longitud mínima de contraseña: $best (menos de 8)"
    fi
}

_chk_acc_007() {
    local dups
    dups=$(awk -F: '{print $3}' "$(audit_path /etc/passwd)" 2>/dev/null | sort | uniq -d | paste -sd, -)
    if [[ -n "$dups" ]]; then
        audit_fail "UIDs duplicados: $dups"
    else
        audit_pass "Sin UIDs duplicados"
    fi
}

_chk_acc_008() {
    local users
    users=$(awk -F: '$3>=1 && $3<=999 && $7 !~ /(nologin|false|sync|shutdown|halt)$/ && $7!="" {print $1}' \
        "$(audit_path /etc/passwd)" 2>/dev/null | paste -sd, -)
    if [[ -n "$users" ]]; then
        audit_warn "Cuentas de sistema con shell de login: $users"
    else
        audit_pass "Las cuentas de sistema no tienen shell de login"
    fi
}

_chk_acc_009() {
    [[ -r "$(audit_path /etc/login.defs)" ]] || { audit_skip "No existe /etc/login.defs"; return 0; }
    local v
    v=$(_acc_login_defs UMASK)
    case "$v" in
        027|077|0027|0077) audit_pass "UMASK $v" ;;
        *) audit_warn "UMASK ${v:-sin definir}" ;;
    esac
}

_chk_acc_010() {
    local main f hits=()
    main=$(audit_path /etc/sudoers)
    [[ -e "$main" ]] || { audit_na "sudo no está instalado"; return 0; }
    [[ -r "$main" ]] || { audit_skip "Se requiere root para leer /etc/sudoers"; return 0; }
    for f in "$main" "$(audit_path /etc/sudoers.d)"/*; do
        [[ -f "$f" ]] || continue
        [[ -r "$f" ]] || { audit_skip "Se requiere root para leer $(_acc_rel "$f")"; return 0; }
        grep -qE '^[[:space:]]*[^#[:space:]].*NOPASSWD' "$f" && hits+=("$(_acc_rel "$f")")
    done
    if (( ${#hits[@]} )); then
        audit_fail "Reglas NOPASSWD en: ${hits[*]}"
    else
        audit_pass "Ninguna regla de sudo omite la contraseña"
    fi
}

audit_register ACC-001 critical accounts "Solo root tiene UID 0" _chk_acc_001 "Cambia el UID de la cuenta extra (usermod -u <uid> usuario) o bloquéala: passwd -l usuario"
audit_register ACC-002 critical accounts "Ninguna cuenta sin contraseña" _chk_acc_002 "Asigna contraseña (passwd usuario) o bloquea la cuenta: passwd -l usuario"
audit_register ACC-003 high accounts "/etc/shadow protegido" _chk_acc_003 "chown root:shadow /etc/shadow && chmod 640 /etc/shadow (en Fedora/RHEL: chmod 000)"
audit_register ACC-004 medium accounts "/etc/passwd sin escritura ajena" _chk_acc_004 "chown root:root /etc/passwd && chmod 644 /etc/passwd"
audit_register ACC-005 medium accounts "Vencimiento de contraseñas configurado" _chk_acc_005 "En /etc/login.defs: PASS_MAX_DAYS 365 (aplica a cuentas nuevas; para las existentes: chage -M 365 usuario)"
audit_register ACC-006 medium accounts "Política de longitud mínima de contraseña" _chk_acc_006 "En /etc/security/pwquality.conf: minlen = 12 (requiere libpam-pwquality)"
audit_register ACC-007 high accounts "Sin UIDs duplicados" _chk_acc_007 "Asigna un UID único a cada cuenta: usermod -u <uid> usuario"
audit_register ACC-008 low accounts "Cuentas de sistema sin shell de login" _chk_acc_008 "usermod -s /usr/sbin/nologin usuario"
audit_register ACC-009 low accounts "umask restrictiva por defecto" _chk_acc_009 "En /etc/login.defs: UMASK 027"
audit_register ACC-010 high accounts "sudo siempre pide contraseña" _chk_acc_010 "Quita NOPASSWD de la regla con: visudo (o visudo -f /etc/sudoers.d/<archivo>)"
