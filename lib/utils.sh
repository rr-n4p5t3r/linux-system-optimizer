#!/usr/bin/env bash
# =============================================================================
# utils.sh — Utilidades generales para LSO
# =============================================================================
# Linux System Optimizer (LSO)
# Autor: Ricardo Rosero <rrosero2000@gmail.com>
# GitHub: https://github.com/rr-n4p5t3r
# Licencia: GPLv3
# =============================================================================


require_root() {
    if [[ $EUID -ne 0 ]]; then
        log_error "Este módulo requiere privilegios de root. Usa: sudo $0"
        exit 1
    fi
}

check_deps() {
    local missing=()
    for cmd in "$@"; do
        if ! command -v "$cmd" &>/dev/null; then
            missing+=("$cmd")
        fi
    done
    if [[ ${#missing[@]} -gt 0 ]]; then
        log_warn "Dependencias faltantes: ${missing[*]}"
        return 1
    fi
    return 0
}

confirm() {
    local msg="${1:-¿Continuar?}"
    local response=""
    read -rp "$(echo -e "${C_YELLOW}$msg [s/N]: ${C_RESET}")" response
    [[ "$response" =~ ^[Ss]$ ]]
}

pause() {
    read -rp "$(echo -e "${C_DIM}Presiona Enter para continuar...${C_RESET}")"
}

service_exists() {
    systemctl list-unit-files "$1.service" &>/dev/null || \
    systemctl list-units --type=service --all 2>/dev/null | grep -q "$1.service" || \
    return 1
}

# --- Directorios seguros ------------------------------------------------------
# LSO corre como root: escribir en un directorio donde otro usuario puede crear
# archivos permite ataques con enlaces simbólicos (root termina escribiendo en
# /etc/shadow o restaurando un archivo preparado por el atacante).

# lso_safe_dir DIR → 0 si es un directorio real (no enlace), cuyo dueño es
# root o el usuario actual y que no es escribible por grupo ni otros.
lso_safe_dir() {
    local d="$1" perm owner
    [[ -d "$d" && ! -L "$d" ]] || return 1
    perm=$(stat -c '%a' "$d" 2>/dev/null) || return 1
    owner=$(stat -c '%u' "$d" 2>/dev/null) || return 1
    [[ "$owner" == 0 || "$owner" == "${EUID:-$(id -u)}" ]] || return 1
    (( 8#$perm & 8#022 )) && return 1
    return 0
}

# lso_state_dir SUBDIR → directorio seguro para datos de LSO (logs, backups).
# Root: /var/lib/lso/SUBDIR (logs en /var/log/lso). Usuario: ~/.local/state/lso/SUBDIR.
lso_state_dir() {
    local sub="$1" d
    if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
        if [[ "$sub" == logs ]]; then d="/var/log/lso"; else d="/var/lib/lso/$sub"; fi
    else
        d="${XDG_STATE_HOME:-${HOME:-/tmp}/.local/state}/lso/$sub"
    fi
    if (umask 077; mkdir -p "$d") 2>/dev/null && lso_safe_dir "$d"; then
        printf '%s\n' "$d"
        return 0
    fi
    # Último recurso: un directorio temporal nuevo y privado (nunca un nombre fijo).
    mktemp -d "${TMPDIR:-/tmp}/lso-${sub}.XXXXXX"
}

# lso_pick_dir PREFERIDO SUBDIR → PREFERIDO si es seguro y escribible; si no, lso_state_dir
lso_pick_dir() {
    local want="$1" sub="$2"
    (umask 022; mkdir -p "$want") 2>/dev/null
    if lso_safe_dir "$want" && [[ -w "$want" ]]; then
        printf '%s\n' "$want"
    else
        lso_state_dir "$sub"
    fi
}

backup_file() {
    local file="$1"
    local backup_dir=""
    backup_dir=$(lso_pick_dir "${LSO_BASE_DIR}/backups" backups) || {
        log_warn "No hay un directorio seguro para backups"
        return 1
    }
    local backup_path=""
    backup_path="${backup_dir}/$(basename "$file").$(date +%s).bak"

    if [[ -f "$file" ]]; then
        cp -a "$file" "$backup_path" 2>/dev/null || {
            log_warn "No se pudo crear backup de: $file"
            return 1
        }
        # La ruta original se guarda al lado para restaurar al sitio exacto.
        readlink -f "$file" > "${backup_path}.path" 2>/dev/null || true
        log_info "Backup creado: $backup_path"
        echo "$backup_path"
    else
        log_warn "Archivo no existe para backup: $file"
        return 1
    fi
}

restore_file() {
    local backup_path="$1"

    if [[ ! -f "$backup_path" ]]; then
        log_error "Backup no encontrado: $backup_path"
        return 1
    fi

    local target_path="" original_name=""
    if [[ -f "${backup_path}.path" ]]; then
        target_path=$(head -1 "${backup_path}.path")
        if [[ "$target_path" != /* ]]; then
            log_error "Ruta original inválida en ${backup_path}.path"
            return 1
        fi
    else
        # Backups anteriores a 1.0.0 no guardaban la ruta: se busca por nombre.
        original_name=$(basename "$backup_path" | sed 's/\.[0-9]*\.bak$//')
        local dir
        for dir in /etc /usr/local/etc /opt; do
            if [[ -f "$dir/$original_name" ]]; then
                target_path="$dir/$original_name"
                break
            fi
        done
    fi

    if [[ -z "$target_path" ]]; then
        log_warn "No se pudo determinar la ruta original para: $original_name"
        log_info "Backup disponible en: $backup_path"
        return 1
    fi

    cp -a "$backup_path" "$target_path" 2>/dev/null || {
        log_error "No se pudo restaurar: $backup_path -> $target_path"
        return 1
    }

    log_success "Restaurado: $backup_path -> $target_path"
}

# lso_backup_epoch RUTA → segundos epoch del nombre "archivo.EPOCH.bak" (o vacío)
lso_backup_epoch() {
    local n="${1##*/}"
    n="${n%.bak}"
    n="${n##*.}"
    [[ "$n" =~ ^[0-9]+$ ]] && printf '%s\n' "$n"
    return 0
}

human_size() {
    local bytes=${1:-0}

    if ! [[ "$bytes" =~ ^[0-9]+$ ]]; then
        echo "0B"
        return 0
    fi

    local unit="B"
    local size=$bytes

    if [[ $bytes -ge 1099511627776 ]]; then
        size=$(awk "BEGIN {printf \"%.2f\", $bytes/1099511627776}")
        unit="TiB"
    elif [[ $bytes -ge 1073741824 ]]; then
        size=$(awk "BEGIN {printf \"%.2f\", $bytes/1073741824}")
        unit="GiB"
    elif [[ $bytes -ge 1048576 ]]; then
        size=$(awk "BEGIN {printf \"%.2f\", $bytes/1048576}")
        unit="MiB"
    elif [[ $bytes -ge 1024 ]]; then
        size=$(awk "BEGIN {printf \"%.2f\", $bytes/1024}")
        unit="KiB"
    fi
    echo "${size}${unit}"
}

is_laptop() {
    [[ -d /sys/class/power_supply/BAT0 ]] || \
    [[ -d /sys/class/power_supply/BAT1 ]] || \
    (command -v dmidecode &>/dev/null && dmidecode -s chassis-type 2>/dev/null | grep -qi "laptop\|notebook\|portable") || \
    return 1
}

# --- Configuración -------------------------------------------------------------

# set_conf_key ARCHIVO CLAVE VALOR [SECCIÓN] → fija "CLAVE=VALOR" sin tocar el
# resto del archivo: reemplaza la línea existente o la agrega al final. Si el
# archivo no existe y se indica SECCIÓN, lo crea con ese encabezado ([main]).
set_conf_key() {
    local file="$1" key="$2" value="$3" section="${4:-}"
    if [[ ! -f "$file" ]]; then
        mkdir -p "$(dirname "$file")"
        if [[ -n "$section" ]]; then printf '[%s]\n' "$section" > "$file"; else : > "$file"; fi
    fi
    if grep -qE "^[[:space:]]*${key}[[:space:]]*=" "$file"; then
        sed -i -E "s|^[[:space:]]*${key}[[:space:]]*=.*|${key}=${value}|" "$file"
    else
        printf '%s=%s\n' "$key" "$value" >> "$file"
    fi
}

# --- Usuario real ----------------------------------------------------------------

# lso_target_home → home del usuario que invocó sudo (o el $HOME actual).
# Con sudo, $HOME suele ser /root y las optimizaciones de usuario (navegadores,
# caché, autoarranque) caerían en la cuenta equivocada.
lso_target_home() {
    local h=""
    if [[ -n "${SUDO_USER:-}" && "${SUDO_USER}" != root ]]; then
        h=$(getent passwd "$SUDO_USER" 2>/dev/null | cut -d: -f6)
    fi
    printf '%s\n' "${h:-${HOME:-}}"
}

# lso_target_user → usuario que invocó sudo (o el actual).
lso_target_user() {
    if [[ -n "${SUDO_USER:-}" && "${SUDO_USER}" != root ]]; then
        printf '%s\n' "$SUDO_USER"
    else
        id -un
    fi
}

# lso_tune_dnf_conf [ARCHIVO] [deltarpm] → ajusta solo las claves de
# rendimiento de DNF, con backup previo, conservando el resto del archivo
# (proxy, exclusiones, etc.). Antes se sobrescribía dnf.conf completo.
lso_tune_dnf_conf() {
    local conf="${1:-/etc/dnf/dnf.conf}" with_delta="${2:-}" kv
    [[ -f "$conf" ]] && backup_file "$conf" >/dev/null
    local -a settings=(
        gpgcheck=1 installonly_limit=3 clean_requirements_on_remove=True best=False
        skip_if_unavailable=True fastestmirror=True max_parallel_downloads=10
    )
    [[ "$with_delta" == deltarpm ]] && settings+=(deltarpm=True)
    for kv in "${settings[@]}"; do
        set_conf_key "$conf" "${kv%%=*}" "${kv#*=}" main
    done
}
