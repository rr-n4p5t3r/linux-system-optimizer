#!/usr/bin/env bash
# shellcheck disable=SC2154  # variables y arreglos definidos en otros archivos del módulo
# =============================================================================
# waivers.sh — Excepciones (riesgos aceptados) de la auditoría
# =============================================================================
# Linux System Optimizer (LSO)
# Autor: Ricardo Rosero <rrosero2000@gmail.com>
# GitHub: https://github.com/rr-n4p5t3r
# Licencia: GPLv3
# =============================================================================
# Formato: una línea por excepción, "ID  # motivo". Las líneas vacías y las
# que empiezan con '#' se ignoran.
# shellcheck disable=SC2034  # AUDIT_WAIVER_UNKNOWN se consume en audit.sh

AUDIT_WAIVER_UNKNOWN=()

audit_load_waivers() {
    local file="$1" line id reason
    AUDIT_WAIVER_UNKNOWN=()
    [[ -r "$file" ]] || return 0
    while IFS= read -r line || [[ -n "$line" ]]; do
        line="${line#"${line%%[![:space:]]*}"}"
        [[ -z "$line" || "$line" == \#* ]] && continue
        id="${line%%[[:space:]#]*}"
        reason=""
        [[ "$line" == *"#"* ]] && reason="${line#*#}"
        reason="${reason#"${reason%%[![:space:]]*}"}"
        reason="${reason%"${reason##*[![:space:]]}"}"
        if [[ -z "${AUDIT_CAT[$id]:-}" ]]; then
            AUDIT_WAIVER_UNKNOWN+=("$id")
            continue
        fi
        AUDIT_WAIVED[$id]="${reason:-Excepción sin motivo}"
    done < "$file"
    return 0
}
