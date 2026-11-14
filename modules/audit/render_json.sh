#!/usr/bin/env bash
# =============================================================================
# render_json.sh — Informe de auditoría en JSON (lso audit --json), esquema v1
# =============================================================================
# Linux System Optimizer (LSO)
# Autor: Ricardo Rosero <rrosero2000@gmail.com>
# GitHub: https://github.com/rr-n4p5t3r
# Licencia: GPLv3
# =============================================================================
# Se genera sin jq: todas las cadenas pasan por audit_json_escape.

audit_json_escape() {
    local s="$1" i c hex
    s="${s//\\/\\\\}"
    s="${s//\"/\\\"}"
    s="${s//$'\n'/\\n}"
    s="${s//$'\t'/\\t}"
    s="${s//$'\r'/\\r}"
    # Solo se recorre la tabla de control si queda alguno (caso raro).
    if [[ "$s" =~ [[:cntrl:]] ]]; then
        for i in {1..31}; do
            printf -v hex '%02x' "$i"
            printf -v c '%b' "\\x$hex"
            [[ "$s" == *"$c"* ]] && s="${s//"$c"/\\u00$hex}"
        done
    fi
    printf '%s' "$s"
}

_js() { printf '"%s"' "$(audit_json_escape "$1")"; }

audit_render_json() {
    local id first cat pct cap
    printf '{\n'
    printf '  "schema": 1,\n  "tool": "lso-audit",\n'
    printf '  "version": %s,\n' "$(_js "${AUDIT_VERSION:-}")"
    printf '  "generated": %s,\n' "$(_js "$(date -Iseconds)")"
    printf '  "host": %s,\n' "$(_js "${AUDIT_HOST:-}")"
    printf '  "distro": %s,\n' "$(_js "${AUDIT_DISTRO:-}")"
    printf '  "profile": {"class": %s, "source": %s, "label": %s},\n' \
        "$(_js "${AUDIT_PROFILE_CLASS:-}")" "$(_js "${AUDIT_PROFILE_SOURCE:-}")" "$(_js "${AUDIT_PROFILE_LABEL:-}")"
    printf '  "root": %s,\n' "$([[ "${AUDIT_IS_ROOT:-false}" == true ]] && echo true || echo false)"
    printf '  "duration_s": %s,\n' "${AUDIT_DURATION:-0}"
    cap="null"
    [[ -n "${AUDIT_CAP:-}" ]] && cap="{\"value\": $AUDIT_CAP, \"reason\": $(_js "$AUDIT_CAP_REASON")}"
    printf '  "score": {"value": %s, "base": %s, "percent": %s, "cap": %s},\n' \
        "$AUDIT_SCORE" "$AUDIT_SCORE_BASE" "$AUDIT_PERCENT" "$cap"
    printf '  "counts": {"critical": %s, "high": %s, "medium": %s, "low": %s, "pass": %s, "warn": %s, "skip": %s, "na": %s, "waived": %s},\n' \
        "${AUDIT_COUNT[critical]}" "${AUDIT_COUNT[high]}" "${AUDIT_COUNT[medium]}" "${AUDIT_COUNT[low]}" \
        "${AUDIT_COUNT[pass]}" "${AUDIT_COUNT[warn]}" "${AUDIT_COUNT[skip]}" "${AUDIT_COUNT[na]}" "${AUDIT_COUNT[waived]}"

    printf '  "categories": ['
    first=1
    while read -r cat; do
        [[ -z "$cat" ]] && continue
        pct=$(audit_category_percent "$cat")
        [[ "$pct" == "-" ]] && pct="null"
        (( first )) || printf ','
        first=0
        printf '\n    {"name": %s, "percent": %s, "open": %s}' "$(_js "$cat")" "$pct" "$(audit_category_open "$cat")"
    done < <(audit_categories)
    printf '\n  ],\n'

    printf '  "checks": ['
    first=1
    for id in $(audit_sorted_ids all); do
        (( first )) || printf ','
        first=0
        printf '\n    {"id": %s, "category": %s, "severity": %s, "base_severity": %s, "status": %s, "title": %s, "detail": %s, "fix": %s, "adjusted": %s}' \
            "$(_js "$id")" "$(_js "${AUDIT_CAT[$id]}")" "$(_js "${AUDIT_SEV[$id]}")" "$(_js "${AUDIT_BASE_SEV[$id]}")" \
            "$(_js "${AUDIT_STATUS[$id]}")" "$(_js "${AUDIT_TITLE[$id]}")" "$(_js "${AUDIT_DETAIL[$id]}")" \
            "$(_js "${AUDIT_FIX[$id]}")" \
            "$([[ -n "${AUDIT_ADJ[$id]}" ]] && _js "${AUDIT_ADJ[$id]}" || echo null)"
    done
    printf '\n  ]\n}\n'
}
