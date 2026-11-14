#!/usr/bin/env bash
# =============================================================================
# engine.sh — Motor de revisiones del módulo de auditoría (lso audit)
# =============================================================================
# Linux System Optimizer (LSO)
# Autor: Ricardo Rosero <rrosero2000@gmail.com>
# GitHub: https://github.com/rr-n4p5t3r
# Licencia: GPLv3
# =============================================================================
# Cada revisión se registra con audit_register y, al ejecutarse, reporta
# exactamente un resultado con audit_pass/fail/warn/skip/na. El motor solo
# guarda resultados; no imprime nada (los renderizadores se encargan).
# shellcheck disable=SC2034  # los arreglos se consumen en otros archivos

audit_reset() {
    AUDIT_IDS=()
    declare -gA AUDIT_SEV=() AUDIT_BASE_SEV=() AUDIT_CAT=() AUDIT_TITLE=() \
        AUDIT_FUNC=() AUDIT_FIX=() AUDIT_STATUS=() AUDIT_DETAIL=() \
        AUDIT_ADJ=() AUDIT_FORCE_NA=() AUDIT_WAIVED=()
    AUDIT_CURRENT=""
}

# audit_register ID SEVERIDAD CATEGORIA "TITULO" FUNCION "FIX"
audit_register() {
    local id="$1" sev="$2" cat="$3" title="$4" fn="$5" fix="${6:-}"
    case "$sev" in
        critical|high|medium|low|info) ;;
        *)
            echo "audit: severidad inválida '$sev' en $id" >&2
            return 1
            ;;
    esac
    AUDIT_IDS+=("$id")
    AUDIT_SEV[$id]="$sev"
    AUDIT_BASE_SEV[$id]="$sev"
    AUDIT_CAT[$id]="$cat"
    AUDIT_TITLE[$id]="$title"
    AUDIT_FUNC[$id]="$fn"
    AUDIT_FIX[$id]="$fix"
    AUDIT_ADJ[$id]=""
}

# Fija el resultado de la revisión en curso; solo cuenta el primero.
_audit_result() {
    local status="$1" detail="${2:-}"
    [[ -z "$AUDIT_CURRENT" ]] && return 0
    [[ -n "${AUDIT_STATUS[$AUDIT_CURRENT]:-}" ]] && return 0
    AUDIT_STATUS[$AUDIT_CURRENT]="$status"
    AUDIT_DETAIL[$AUDIT_CURRENT]="$detail"
}

audit_pass() { _audit_result PASS "${1:-}"; }
audit_fail() { _audit_result FAIL "${1:-}"; }
audit_warn() { _audit_result WARN "${1:-}"; }
audit_skip() { _audit_result SKIP "${1:-}"; }
audit_na()   { _audit_result NA   "${1:-}"; }

# audit_run_all [CSV_CATEGORIAS]
audit_run_all() {
    local filter="${1:-}" id
    for id in "${AUDIT_IDS[@]}"; do
        if [[ -n "$filter" && ",${filter}," != *",${AUDIT_CAT[$id]},"* ]]; then
            continue
        fi
        unset "AUDIT_STATUS[$id]"
        AUDIT_DETAIL[$id]=""
        if [[ -n "${AUDIT_FORCE_NA[$id]:-}" ]]; then
            AUDIT_STATUS[$id]="NA"
            AUDIT_DETAIL[$id]="${AUDIT_FORCE_NA[$id]}"
            continue
        fi
        AUDIT_CURRENT="$id"
        "${AUDIT_FUNC[$id]}" || true
        AUDIT_CURRENT=""
        if [[ -z "${AUDIT_STATUS[$id]:-}" ]]; then
            AUDIT_STATUS[$id]="SKIP"
            AUDIT_DETAIL[$id]="La revisión no reportó resultado"
        fi
        if [[ -n "${AUDIT_WAIVED[$id]:-}" && "${AUDIT_STATUS[$id]}" != "NA" ]]; then
            AUDIT_STATUS[$id]="WAIVED"
            AUDIT_DETAIL[$id]="${AUDIT_WAIVED[$id]}"
        fi
    done
}

audit_reset
