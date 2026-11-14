#!/usr/bin/env bash
# =============================================================================
# helpers.sh — Lectura del sistema para las revisiones de auditoría
# =============================================================================
# Linux System Optimizer (LSO)
# Autor: Ricardo Rosero <rrosero2000@gmail.com>
# GitHub: https://github.com/rr-n4p5t3r
# Licencia: GPLv3
# =============================================================================
# Todas las rutas pasan por audit_path (AUDIT_ROOT permite probar con
# árboles de archivos falsos) y todos los comandos externos pasan por
# envoltorios audit_cmd_* / audit_is_* que las pruebas pueden reemplazar.
# Nada aquí modifica el sistema.

AUDIT_ROOT="${AUDIT_ROOT:-}"

audit_path() { printf '%s%s' "${AUDIT_ROOT:-}" "$1"; }

audit_perm() {
    local p
    p=$(audit_path "$1")
    [[ -e "$p" ]] || return 1
    stat -c '%a' "$p" 2>/dev/null
}

audit_owner_uid() {
    local p
    p=$(audit_path "$1")
    [[ -e "$p" ]] || return 1
    stat -c '%u' "$p" 2>/dev/null
}

audit_is_root() { [[ ${EUID:-$(id -u)} -eq 0 ]]; }

audit_have() { command -v "$1" >/dev/null 2>&1; }

audit_sysctl() {
    local p
    p=$(audit_path "/proc/sys/${1//.//}")
    [[ -r "$p" ]] || return 1
    tr -d '[:space:]' < "$p"
}

audit_is_container() {
    [[ -e /.dockerenv || -e /run/.containerenv ]] && return 0
    audit_have systemd-detect-virt && systemd-detect-virt -cq 2>/dev/null
}

# --- Envoltorios de comandos -------------------------------------------------
audit_cmd_ss()               { ss -Htuln 2>/dev/null; }
audit_cmd_ufw_status()       { ufw status 2>/dev/null; }
audit_cmd_firewalld_state()  { firewall-cmd --state 2>/dev/null; }
audit_cmd_nft_ruleset()      { nft list ruleset 2>/dev/null; }
audit_cmd_iptables_rules()   { iptables -S 2>/dev/null; }
audit_cmd_sshd_T()           { sshd -T 2>/dev/null; }

# --- SSH ---------------------------------------------------------------------
audit_sshd_present() { [[ -e "$(audit_path /etc/ssh/sshd_config)" ]]; }

# Emite "clave valor" (clave en minúsculas) siguiendo los Include en su
# posición. Emite "__match__" y devuelve 2 al encontrar un bloque Match.
_audit_sshd_emit() {
    local file="$1" line key rest pat f
    local -a files
    [[ -r "$file" ]] || return 0
    while IFS= read -r line || [[ -n "$line" ]]; do
        line="${line#"${line%%[![:space:]]*}"}"
        [[ -z "$line" || "$line" == \#* ]] && continue
        # Clave y valor, separados por espacios o por '='.
        key="${line%%[[:space:]=]*}"
        rest="${line#"$key"}"
        rest="${rest#"${rest%%[![:space:]=]*}"}"
        rest="${rest%"${rest##*[![:space:]]}"}"
        key="${key,,}"
        case "$key" in
            match)
                echo "__match__"
                return 2
                ;;
            include)
                for pat in $rest; do
                    [[ "$pat" != /* ]] && pat="/etc/ssh/$pat"
                    files=()
                    for f in $(audit_path "$pat"); do
                        [[ -e "$f" ]] && files+=("$f")
                    done
                    for f in "${files[@]}"; do
                        _audit_sshd_emit "$f" || return 2
                    done
                done
                ;;
            *)
                printf '%s %s\n' "$key" "$rest"
                ;;
        esac
    done < "$file"
    return 0
}

# audit_sshd_value CLAVE DEFAULT → valor efectivo en minúsculas
audit_sshd_value() {
    local want="${1,,}" def="$2" k v
    if [[ -z "${AUDIT_ROOT:-}" ]] && audit_is_root && audit_have sshd; then
        v=$(audit_cmd_sshd_T | awk -v k="$want" '$1==k { $1=""; sub(/^ /, ""); print; exit }')
        if [[ -n "$v" ]]; then
            printf '%s\n' "${v,,}"
            return 0
        fi
    fi
    while read -r k v; do
        [[ "$k" == "__match__" ]] && break
        if [[ "$k" == "$want" ]]; then
            printf '%s\n' "${v,,}"
            return 0
        fi
    done < <(_audit_sshd_emit "$(audit_path /etc/ssh/sshd_config)")
    printf '%s\n' "$def"
}
