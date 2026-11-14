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

# --- Montajes, servicios y usuarios ------------------------------------------

# audit_mount_opts PUNTO → opciones del montaje (return 1 si no es un montaje propio)
audit_mount_opts() {
    local opts
    opts=$(awk -v mp="$1" '$2==mp {o=$4} END {if (o!="") print o}' "$(audit_path /proc/mounts)" 2>/dev/null)
    [[ -n "$opts" ]] || return 1
    printf '%s\n' "$opts"
}

audit_cmd_systemctl_is_active() { systemctl is-active --quiet "$1" 2>/dev/null; }

# audit_service_active SERVICIO… → 0 si alguno está activo, 1 si ninguno,
# 2 si no se puede saber (sin systemctl).
audit_service_active() {
    audit_have systemctl || return 2
    local s
    for s in "$@"; do
        audit_cmd_systemctl_is_active "$s" && return 0
    done
    return 1
}

# audit_user_homes → "usuario home" para root y las cuentas humanas (UID 1000–65533)
audit_user_homes() {
    awk -F: '($3==0 || ($3>=1000 && $3<65534)) && $6!="" {print $1, $6}' \
        "$(audit_path /etc/passwd)" 2>/dev/null
}

# Ruta sin el prefijo AUDIT_ROOT, para mostrarla en los detalles.
audit_rel() { local p="$1"; printf '%s' "${p#"${AUDIT_ROOT:-}"}"; }

# audit_check_sysctl CLAVE "VALORES ACEPTADOS" → reporta PASS/FAIL/SKIP
# (se usa dentro de una revisión).
audit_check_sysctl() {
    local key="$1" ok="$2" v
    if ! v=$(audit_sysctl "$key") || [[ -z "$v" ]]; then
        audit_skip "No se pudo leer $key"
        return 0
    fi
    if [[ " $ok " == *" $v "* ]]; then
        audit_pass "$key = $v"
    else
        audit_fail "$key = $v"
    fi
}

# Puntos de montaje locales donde buscar archivos (siempre incluye "/").
audit_local_mounts() {
    {
        echo /
        awk '$3 ~ /^(ext[234]|xfs|btrfs|f2fs|jfs|reiserfs|zfs)$/ {print $2}' \
            "$(audit_path /proc/mounts)" 2>/dev/null
    } | sort -u
}

# audit_find ARGS… → find sobre cada montaje local (sin cruzar a otros)
audit_find() {
    local mp
    while read -r mp; do
        find "$(audit_path "$mp")" -xdev "$@" 2>/dev/null
    done < <(audit_local_mounts)
}

# Lista de hasta N elementos separados por coma, con "…" si hay más.
audit_short_list() {
    local max="${1:-5}"
    awk -v m="$max" 'NF {n++; if (n<=m) a = a (n>1 ? ", " : "") $0} END {if (n>m) a = a " … (" n " en total)"; print a}'
}

# Un solo recorrido del disco para todas las revisiones lentas. Cada línea:
#   W <ruta>  directorio escribible por todos sin sticky bit
#   S <ruta>  archivo con SUID
#   U <ruta>  archivo o directorio sin dueño o sin grupo
AUDIT_SCAN_ROOT="__none__"
AUDIT_SCAN_DATA=""

audit_disk_scan() {
    if [[ "$AUDIT_SCAN_ROOT" != "${AUDIT_ROOT:-}" ]]; then
        AUDIT_SCAN_DATA=$(audit_find \
            \( -type d -perm -0002 ! -perm -1000 -printf 'W %p\n' \) , \
            \( -type f -perm -4000 -printf 'S %p\n' \) , \
            \( \( -nouser -o -nogroup \) -printf 'U %p\n' \))
        AUDIT_SCAN_ROOT="${AUDIT_ROOT:-}"
    fi
    # audit_disk_scan TIPO → rutas (sin prefijo AUDIT_ROOT) de ese tipo
    local p
    while IFS= read -r p; do
        [[ "$p" == "$1 "* ]] && audit_rel "${p#"$1 "}" && echo
    done <<< "$AUDIT_SCAN_DATA"
}

audit_cmd_systemctl_is_enabled() { systemctl is-enabled "$1" 2>/dev/null; }

# Primer archivo legible de la lista (con prefijo AUDIT_ROOT), o return 1.
audit_first_file() {
    local p
    for p in "$@"; do
        [[ -r "$(audit_path "$p")" ]] && { printf '%s\n' "$p"; return 0; }
    done
    return 1
}

audit_cmd_apt_upgrade_sim()  { LC_ALL=C apt-get -s -o Debug::NoLocking=1 upgrade 2>/dev/null; }
audit_cmd_dnf_security()     { dnf -q updateinfo list --security 2>/dev/null; }
audit_cmd_zypper_security()  { zypper -q list-patches --category security 2>/dev/null; }
audit_cmd_needs_restarting() { needs-restarting -r >/dev/null 2>&1; }
audit_cmd_uname_r()          { uname -r; }

# Gestor de paquetes: apt, dnf, zypper, pacman o vacío.
audit_pkg_manager() {
    case "${LSO_PACKAGE_MANAGER:-}" in
        apt|apt-get) echo apt; return 0 ;;
        dnf|yum) echo dnf; return 0 ;;
        zypper|pacman) echo "$LSO_PACKAGE_MANAGER"; return 0 ;;
    esac
    if audit_have apt-get; then echo apt
    elif audit_have dnf || audit_have yum; then echo dnf
    elif audit_have zypper; then echo zypper
    elif audit_have pacman; then echo pacman
    fi
}

# Días desde la última modificación de RUTA (return 1 si no existe).
audit_age_days() {
    local p m
    p=$(audit_path "$1")
    [[ -e "$p" ]] || return 1
    m=$(stat -c %Y "$p" 2>/dev/null) || return 1
    echo $(( ($(date +%s) - m) / 86400 ))
}

# Imprime "proto dirección puerto" por cada socket en escucha.
audit_listeners() {
    audit_cmd_ss | awk '{
        addr = $5; n = split(addr, a, ":"); port = a[n];
        host = substr(addr, 1, length(addr) - length(port) - 1);
        print $1, host, port
    }'
}

audit_is_loopback() { [[ "$1" == 127.* || "$1" == "[::1]" || "$1" == "::1" ]]; }

# audit_port_state PUERTO → none | loopback | exposed (según ss)
audit_port_state() {
    local proto host port state=none
    while read -r proto host port; do
        [[ "$port" == "$1" ]] || continue
        if audit_is_loopback "$host"; then
            [[ "$state" == none ]] && state=loopback
        else
            state=exposed
        fi
    done < <(audit_listeners)
    echo "$state"
}
