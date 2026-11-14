#!/usr/bin/env bash
# =============================================================================
# render_plain.sh — Informe de auditoría en texto (lso audit --plain)
# =============================================================================
# Linux System Optimizer (LSO)
# Autor: Ricardo Rosero <rrosero2000@gmail.com>
# GitHub: https://github.com/rr-n4p5t3r
# Licencia: GPLv3
# =============================================================================

_audit_sev_rank() {
    case "$1" in critical) echo 0 ;; high) echo 1 ;; medium) echo 2 ;; low) echo 3 ;; *) echo 4 ;; esac
}

audit_sev_label() {
    case "$1" in
        critical) echo "CRÍTICO" ;; high) echo "ALTO" ;; medium) echo "MEDIO" ;;
        low) echo "BAJO" ;; *) echo "INFO" ;;
    esac
}

# audit_sorted_ids [all] → IDs ordenados por gravedad efectiva y luego por ID.
# Sin "all" solo devuelve los abiertos (FAIL/WARN).
audit_sorted_ids() {
    local mode="${1:-}" id st
    for id in "${AUDIT_IDS[@]}"; do
        st="${AUDIT_STATUS[$id]:-}"
        [[ -z "$st" ]] && continue
        if [[ "$mode" != all && "$st" != FAIL && "$st" != WARN ]]; then
            continue
        fi
        printf '%s %s\n' "$(_audit_sev_rank "${AUDIT_SEV[$id]}")" "$id"
    done | sort -k1,1n -k2,2 | awk '{print $2}'
}

# Colores locales del informe (vacíos si AUDIT_COLOR=0).
_audit_plain_colors() {
    if [[ "${AUDIT_COLOR:-0}" == 1 ]]; then
        _R=$'\033[0m' _B=$'\033[1m' _D=$'\033[2m'
        _CRIT=$'\033[1;37;41m' _HIGH=$'\033[1;31m' _MED=$'\033[1;33m' _LOW=$'\033[1;36m'
        _OK=$'\033[32m'
    else
        _R="" _B="" _D="" _CRIT="" _HIGH="" _MED="" _LOW="" _OK=""
    fi
}

_audit_sev_color() {
    case "$1" in critical) printf '%s' "$_CRIT" ;; high) printf '%s' "$_HIGH" ;;
        medium) printf '%s' "$_MED" ;; low) printf '%s' "$_LOW" ;; *) printf '%s' "$_D" ;; esac
}

_audit_plain_list() { # _audit_plain_list TITULO ESTADO
    local id any=0
    for id in $(audit_sorted_ids all); do
        [[ "${AUDIT_STATUS[$id]}" != "$2" ]] && continue
        (( any )) || { printf '\n%s%s%s\n' "$_B" "$1" "$_R"; any=1; }
        printf '  %-8s %s %s— %s%s\n' "$id" "${AUDIT_TITLE[$id]}" "$_D" "${AUDIT_DETAIL[$id]}" "$_R"
    done
}

audit_render_plain() {
    local mode="${1:-}" id sev src cat pct open
    local _R _B _D _CRIT _HIGH _MED _LOW _OK
    _audit_plain_colors
    src="detectado"; [[ "${AUDIT_PROFILE_SOURCE:-}" == chosen ]] && src="elegido"

    printf '%sLSO audit%s · %s · %s · %s (%s) · v%s · %s s\n' "$_B" "$_R" \
        "${AUDIT_HOST:-}" "${AUDIT_DISTRO:-}" "${AUDIT_PROFILE_LABEL:-}" "$src" \
        "${AUDIT_VERSION:-}" "${AUDIT_DURATION:-}"
    [[ "${AUDIT_IS_ROOT:-true}" == false ]] && \
        printf '%sSin root: algunas revisiones no se pudieron evaluar.%s\n' "$_D" "$_R"
    printf '\n%sPuntaje: %s/10%s  (base %s/10, %s %%)\n' "$_B" "$AUDIT_SCORE" "$_R" \
        "$AUDIT_SCORE_BASE" "$AUDIT_PERCENT"
    [[ -n "${AUDIT_CAP_REASON:-}" ]] && printf '  %s%s%s\n' "$_MED" "$AUDIT_CAP_REASON" "$_R"
    printf 'Abiertos: %s crítico · %s alto · %s medio · %s bajo    ' \
        "${AUDIT_COUNT[critical]}" "${AUDIT_COUNT[high]}" "${AUDIT_COUNT[medium]}" "${AUDIT_COUNT[low]}"
    printf '%s✓ %s aprobadas%s · ? %s no evaluables · ≈ %s exceptuadas\n' "$_OK" \
        "${AUDIT_COUNT[pass]}" "$_R" "${AUDIT_COUNT[skip]}" "${AUDIT_COUNT[waived]}"

    printf '\n%sCategorías%s\n' "$_B" "$_R"
    while read -r cat; do
        [[ -z "$cat" ]] && continue
        pct=$(audit_category_percent "$cat")
        open=$(audit_category_open "$cat")
        [[ "$pct" != "-" ]] && pct="$pct %"
        printf '  %-12s %6s   ✖ %s\n' "$cat" "$pct" "$open"
    done < <(audit_categories)

    printf '\n%sHallazgos%s\n' "$_B" "$_R"
    local any=0
    for id in $(audit_sorted_ids); do
        any=1
        sev="${AUDIT_SEV[$id]}"
        printf '  %s[%s]%s %s%-8s%s %s' "$(_audit_sev_color "$sev")" "$(audit_sev_label "$sev")" "$_R" \
            "$_B" "$id" "$_R" "${AUDIT_TITLE[$id]}"
        [[ "${AUDIT_STATUS[$id]}" == WARN ]] && printf ' %s(advertencia)%s' "$_D" "$_R"
        printf '  %s%s%s\n' "$_D" "${AUDIT_CAT[$id]}" "$_R"
        [[ -n "${AUDIT_DETAIL[$id]}" ]] && printf '      Detalle: %s\n' "${AUDIT_DETAIL[$id]}"
        [[ -n "${AUDIT_ADJ[$id]}" ]] && printf '      %sGravedad ajustada por perfil (%s; original: %s)%s\n' \
            "$_D" "${AUDIT_ADJ[$id]}" "$(audit_sev_label "${AUDIT_BASE_SEV[$id]}")" "$_R"
        printf '      Corrección: %s\n' "${AUDIT_FIX[$id]}"
    done
    (( any )) || printf '  %sNo hay hallazgos abiertos.%s\n' "$_OK" "$_R"

    if [[ "$mode" == all ]]; then
        _audit_plain_list "Aprobadas" PASS
        _audit_plain_list "No evaluables" SKIP
        _audit_plain_list "No aplica" NA
        _audit_plain_list "Exceptuadas" WAIVED
    fi
}
