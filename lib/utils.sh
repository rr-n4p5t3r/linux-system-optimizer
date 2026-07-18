#!/usr/bin/env bash
# =============================================================================
# utils.sh — Utilidades generales para LSO
# =============================================================================
# Linux System Optimizer (LSO)
# Autor: Ricardo Rosero <rrosero2000@gmail.com>
# GitHub: https://github.com/rr-n4p5t3r
# Licencia: MIT
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
    local response
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

backup_file() {
    local file="$1"
    local backup_dir="${LSO_BASE_DIR}/backups"
    local backup_path="${backup_dir}/$(basename "$file").$(date +%s).bak"

    mkdir -p "$backup_dir" 2>/dev/null || {
        backup_dir="/tmp/lso-backups"
        mkdir -p "$backup_dir"
        backup_path="${backup_dir}/$(basename "$file").$(date +%s).bak"
    }

    if [[ -f "$file" ]]; then
        cp -a "$file" "$backup_path" 2>/dev/null || {
            log_warn "No se pudo crear backup de: $file"
            return 1
        }
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

    local filename
    filename=$(basename "$backup_path")
    local original_name
    original_name=$(echo "$filename" | sed 's/\.[0-9]*\.bak$//')

    local target_path=""
    if [[ -f "/etc/$original_name" ]]; then
        target_path="/etc/$original_name"
    elif [[ -f "/usr/$original_name" ]]; then
        target_path="/usr/$original_name"
    else
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
