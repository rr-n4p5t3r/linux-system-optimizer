#!/usr/bin/env bash
# =============================================================================
# score.sh — Puntaje de la auditoría (1 a 10) con topes por hallazgos graves
# =============================================================================
# Linux System Optimizer (LSO)
# Autor: Ricardo Rosero <rrosero2000@gmail.com>
# GitHub: https://github.com/rr-n4p5t3r
# Licencia: GPLv3
# =============================================================================
# Pesos: critical 10, high 6, medium 3, low 1, info 0. PASS suma el peso,
# WARN la mitad, FAIL nada. NA, SKIP y WAIVED no entran al porcentaje.
# Se trabaja en "unidades dobles" para evitar decimales.
# shellcheck disable=SC2034  # variables consumidas por los renderizadores

_audit_weight() {
    case "$1" in
        critical) echo 10 ;; high) echo 6 ;; medium) echo 3 ;; low) echo 1 ;; *) echo 0 ;;
    esac
}

# Imprime "obtenido posible" (unidades dobles) para los IDs recibidos.
_audit_points() {
    local id w obt=0 pos=0
    for id in "$@"; do
        w=$(_audit_weight "${AUDIT_SEV[$id]}")
        case "${AUDIT_STATUS[$id]:-}" in
            PASS) obt=$((obt + 2 * w)); pos=$((pos + 2 * w)) ;;
            WARN) obt=$((obt + w));     pos=$((pos + 2 * w)) ;;
            FAIL) pos=$((pos + 2 * w)) ;;
        esac
    done
    echo "$obt $pos"
}

_audit_percent_of() { # obtenido posible → entero redondeado
    local obt="$1" pos="$2"
    echo $(( (obt * 100 + pos / 2) / pos ))
}

audit_compute_score() {
    declare -gA AUDIT_COUNT=(
        [critical]=0 [high]=0 [medium]=0 [low]=0
        [pass]=0 [warn]=0 [fail]=0 [skip]=0 [na]=0 [waived]=0
    )
    local id st sev evaluated=0 applicable=0 obt pos
    local -a ran=()
    for id in "${AUDIT_IDS[@]}"; do
        st="${AUDIT_STATUS[$id]:-}"
        [[ -z "$st" ]] && continue
        ran+=("$id")
        sev="${AUDIT_SEV[$id]}"
        case "$st" in
            PASS) AUDIT_COUNT[pass]=$((AUDIT_COUNT[pass] + 1)) ;;
            WARN|FAIL)
                if [[ "$st" == WARN ]]; then
                    AUDIT_COUNT[warn]=$((AUDIT_COUNT[warn] + 1))
                else
                    AUDIT_COUNT[fail]=$((AUDIT_COUNT[fail] + 1))
                fi
                [[ "$sev" != info ]] && AUDIT_COUNT[$sev]=$((AUDIT_COUNT[$sev] + 1))
                ;;
            SKIP)   AUDIT_COUNT[skip]=$((AUDIT_COUNT[skip] + 1)) ;;
            NA)     AUDIT_COUNT[na]=$((AUDIT_COUNT[na] + 1)) ;;
            WAIVED) AUDIT_COUNT[waived]=$((AUDIT_COUNT[waived] + 1)) ;;
        esac
    done
    evaluated=$((AUDIT_COUNT[pass] + AUDIT_COUNT[warn] + AUDIT_COUNT[fail]))
    applicable=$((evaluated + AUDIT_COUNT[skip]))

    AUDIT_CAP=""
    AUDIT_CAP_REASON=""
    read -r obt pos < <(_audit_points "${ran[@]}")
    if [[ $evaluated -eq 0 ]]; then
        AUDIT_PERCENT=0
        AUDIT_SCORE_BASE=1
        AUDIT_SCORE=1
        AUDIT_CAP_REASON="No se evaluó ninguna revisión"
        return 0
    fi
    # Si solo se evaluaron revisiones informativas (peso 0) no hay nada que restar.
    if [[ $pos -eq 0 ]]; then
        AUDIT_PERCENT=100
    else
        AUDIT_PERCENT=$(_audit_percent_of "$obt" "$pos")
    fi
    AUDIT_SCORE_BASE=$(( (AUDIT_PERCENT + 5) / 10 ))
    (( AUDIT_SCORE_BASE < 1 )) && AUDIT_SCORE_BASE=1
    AUDIT_SCORE=$AUDIT_SCORE_BASE

    # Topes candidatos en orden de prioridad: críticos, altos, cobertura.
    local crit=${AUDIT_COUNT[critical]} high=${AUDIT_COUNT[high]}
    local cap="" reason="" c
    _try_cap() {
        if [[ -z "$cap" || $1 -lt $cap ]]; then cap=$1; reason="$2"; fi
    }
    if (( crit == 1 )); then
        _try_cap 6 "Tope 6/10: 1 hallazgo crítico abierto"
    elif (( crit == 2 )); then
        _try_cap 4 "Tope 4/10: 2 hallazgos críticos abiertos"
    elif (( crit >= 3 )); then
        _try_cap 3 "Tope 3/10: ${crit} hallazgos críticos abiertos"
    fi
    if (( high >= 5 )); then
        _try_cap 6 "Tope 6/10: ${high} hallazgos altos abiertos"
    elif (( high == 1 )); then
        _try_cap 8 "Tope 8/10: 1 hallazgo alto abierto"
    elif (( high > 1 )); then
        _try_cap 8 "Tope 8/10: ${high} hallazgos altos abiertos"
    fi
    if (( applicable > 0 && evaluated * 100 < 90 * applicable )); then
        c=$(( (evaluated * 100 + applicable / 2) / applicable ))
        _try_cap 6 "Tope 6/10: cobertura de ${c} % (menos del 90 % evaluado; ¿corriste sin root?)"
    fi
    unset -f _try_cap

    # El tope solo se informa si de verdad baja el puntaje.
    if [[ -n "$cap" && $cap -lt $AUDIT_SCORE ]]; then
        AUDIT_CAP="$cap"
        AUDIT_CAP_REASON="$reason"
        AUDIT_SCORE=$cap
    fi
}

# Categorías en orden de primera aparición.
audit_categories() {
    local id
    local -A seen=()
    for id in "${AUDIT_IDS[@]}"; do
        [[ -n "${seen[${AUDIT_CAT[$id]}]:-}" ]] && continue
        seen[${AUDIT_CAT[$id]}]=1
        echo "${AUDIT_CAT[$id]}"
    done
}

_audit_ids_of() {
    local id
    for id in "${AUDIT_IDS[@]}"; do
        [[ "${AUDIT_CAT[$id]}" == "$1" ]] && echo "$id"
    done
}

audit_category_percent() {
    local -a ids
    local obt pos
    mapfile -t ids < <(_audit_ids_of "$1")
    read -r obt pos < <(_audit_points "${ids[@]}")
    if [[ $pos -eq 0 ]]; then
        # Sin peso evaluable: "-" si nada se evaluó; 100 si solo hubo info aprobadas.
        local id
        for id in "${ids[@]}"; do
            [[ "${AUDIT_STATUS[$id]:-}" == PASS ]] && { echo 100; return 0; }
        done
        echo "-"
        return 0
    fi
    _audit_percent_of "$obt" "$pos"
}

audit_category_open() {
    local id n=0
    while read -r id; do
        [[ -z "$id" ]] && continue
        case "${AUDIT_STATUS[$id]:-}" in FAIL|WARN) n=$((n + 1)) ;; esac
    done < <(_audit_ids_of "$1")
    echo "$n"
}
