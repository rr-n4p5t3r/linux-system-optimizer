#!/usr/bin/env bash
# =============================================================================
# audit.sh — Punto de entrada de "lso audit" (auditoría de seguridad)
# =============================================================================
# Linux System Optimizer (LSO)
# Autor: Ricardo Rosero <rrosero2000@gmail.com>
# GitHub: https://github.com/rr-n4p5t3r
# Licencia: GPLv3
# =============================================================================
# Solo lectura: ninguna revisión modifica el sistema. Cada hallazgo trae la
# corrección sugerida para que la apliques tú.
# shellcheck disable=SC2034  # metadatos consumidos por los renderizadores

AUDIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AUDIT_DEFAULT_WAIVERS="/etc/lso/audit-waivers.conf"

audit_usage() {
    cat << 'EOF_HELP'
USO:
    lso audit [opciones]

Sin opciones de formato abre el tablero interactivo (terminal de al menos
100×30 con UTF-8); si no es posible, muestra el informe en texto.

Auditoría de seguridad de solo lectura: revisa el sistema, califica de 1 a 10
y muestra cada hallazgo con su corrección sugerida. No cambia nada.

OPCIONES:
    --plain               Informe en texto
    --all                 Con --plain, incluye también aprobadas, no evaluables,
                          no aplica y exceptuadas
    --json                Informe en JSON (esquema v1)
    --output ARCHIVO      Guarda el informe en ARCHIVO (permisos 600)
    --category CAT[,CAT]  Solo esas categorías: accounts, ssh, network, filesystem,
                          hardening, persistence, patching, secrets, apps
    --profile PERFIL      Fuerza el perfil: server, database, docker, desktop,
                          laptop, gaming, dev, workstation
    --waivers ARCHIVO     Excepciones (por defecto /etc/lso/audit-waivers.conf)
    --fast                Omite las revisiones lentas (recorren el disco)
    --no-color            Sin colores
    -h, --help            Muestra esta ayuda

Corre con sudo para evaluar todo: sin root, lo que requiere permisos queda
como "no evaluable" y el puntaje tiene un tope de 6/10.

EJEMPLOS:
    sudo lso audit --plain
    sudo lso audit --json --output informe.json
    sudo lso audit --profile server --category ssh,network
EOF_HELP
}

_audit_usage_error() {
    echo "lso audit: $1" >&2
    echo "Usa 'lso audit --help' para ver las opciones." >&2
    return 2
}

_audit_version() {
    local v=""
    [[ -r "${LSO_BASE_DIR:-}/VERSION" ]] && \
        v=$(awk -F': *' '/^Versi/ {print $2; exit}' "$LSO_BASE_DIR/VERSION")
    printf '%s' "${v:-desconocida}"
}

_audit_progress() {
    local msg
    msg="Auditando [$1/$2] $3 · ${AUDIT_TITLE[$3]}"
    (( ${#msg} > 78 )) && msg="${msg:0:77}…"
    printf '\r\033[K  %s' "$msg" >&2
}

audit_main() {
    local mode="" all="" output="" categories="" profile="" fast=0 nocolor=0
    local waivers="$AUDIT_DEFAULT_WAIVERS"
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --plain) [[ "$mode" == json ]] && { _audit_usage_error "--plain y --json no se pueden usar juntos"; return 2; }
                     mode=plain ;;
            --json)  [[ "$mode" == plain ]] && { _audit_usage_error "--plain y --json no se pueden usar juntos"; return 2; }
                     mode=json ;;
            --all) all=all ;;
            --output|--category|--profile|--waivers)
                [[ -n "${2:-}" ]] || { _audit_usage_error "$1 requiere un valor"; return 2; }
                case "$1" in
                    --output) output="$2" ;; --category) categories="$2" ;;
                    --profile) profile="$2" ;; --waivers) waivers="$2" ;;
                esac
                shift ;;
            --fast) fast=1 ;;
            --no-color) nocolor=1 ;;
            -h|--help) audit_usage; return 0 ;;
            *) _audit_usage_error "opción desconocida: $1"; return 2 ;;
        esac
        shift
    done
    AUDIT_FAST=$fast

    if [[ "${LSO_DISTRO_ID:-}" == freebsd ]]; then
        echo "lso audit: FreeBSD todavía no está soportado." >&2
        return 2
    fi

    local f
    for f in engine score helpers profiles waivers render_plain render_json; do
        # shellcheck source=/dev/null
        source "$AUDIT_DIR/$f.sh"
    done
    for f in "$AUDIT_DIR"/checks/*.sh; do
        # shellcheck source=/dev/null
        source "$f"
    done

    # Validaciones de uso.
    local valid c
    valid=" $(audit_categories | tr '\n' ' ')"
    if [[ -n "$categories" ]]; then
        for c in ${categories//,/ }; do
            [[ "$valid" == *" $c "* ]] || {
                _audit_usage_error "categoría desconocida: $c (válidas:${valid% })"; return 2; }
        done
    fi
    if [[ -n "$profile" ]] && ! audit_profile_class_for "$profile" >/dev/null; then
        _audit_usage_error "perfil desconocido: $profile (válidos: server, database, docker, desktop, laptop, gaming, dev, workstation)"
        return 2
    fi

    local t0="${EPOCHREALTIME/,/.}"
    audit_profile_resolve "$profile"
    audit_profile_apply
    audit_load_waivers "$waivers"
    (( ${#AUDIT_WAIVER_UNKNOWN[@]} )) && \
        echo "Aviso: excepciones con ID desconocido en $waivers: ${AUDIT_WAIVER_UNKNOWN[*]}" >&2
    # Progreso en stderr solo si es una terminal (no ensucia --json ni archivos).
    if [[ -t 2 ]]; then
        AUDIT_PROGRESS_CB=_audit_progress
    fi
    audit_run_all "$categories"
    [[ -n "${AUDIT_PROGRESS_CB:-}" ]] && printf '\r\033[K' >&2
    AUDIT_PROGRESS_CB=""
    audit_compute_score

    AUDIT_VERSION=$(_audit_version)
    AUDIT_HOST=$(uname -n 2>/dev/null)
    AUDIT_DISTRO="${LSO_DISTRO:-Linux} ${LSO_DISTRO_VERSION:-}"
    AUDIT_DISTRO="${AUDIT_DISTRO% }"
    AUDIT_DURATION=$(awk -v a="$t0" -v b="${EPOCHREALTIME/,/.}" 'BEGIN {printf "%.1f", b - a}')
    AUDIT_IS_ROOT=false
    audit_is_root && AUDIT_IS_ROOT=true
    [[ "$AUDIT_IS_ROOT" == false ]] && \
        echo "Aviso: sin root algunas revisiones no se pueden evaluar (usa sudo)." >&2

    AUDIT_COLOR=0
    if [[ -t 1 && $nocolor -eq 0 && -z "${NO_COLOR:-}" && -z "$output" ]]; then
        AUDIT_COLOR=1
    fi

    if [[ -z "$mode" ]]; then
        # Sin formato explícito: tablero si la terminal lo permite; si no, texto.
        # shellcheck source=/dev/null
        source "$AUDIT_DIR/render_tui.sh"
        if [[ -z "$output" ]] && tui_supported; then
            tui_run
            return 0
        fi
        mode=plain
    fi

    local report
    if [[ "$mode" == json ]]; then
        report=$(audit_render_json)
    else
        report=$(audit_render_plain "$all")
    fi

    if [[ -n "$output" ]]; then
        ( umask 077; printf '%s\n' "$report" > "$output" ) || {
            echo "lso audit: no se pudo escribir $output" >&2; return 1; }
        chmod 600 "$output"
        echo "Informe guardado en $output" >&2
    else
        printf '%s\n' "$report"
    fi
    return 0
}
