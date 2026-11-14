#!/usr/bin/env bash
# shellcheck disable=SC2154  # variables y arreglos definidos en otros archivos del módulo
# Pruebas del puntaje (modules/audit/score.sh)
# shellcheck disable=SC2034

source "$LSO_BASE_DIR/modules/audit/engine.sh"
source "$LSO_BASE_DIR/modules/audit/score.sh"

# _mk ID SEV STATUS [CAT]
_mk() {
    local id="$1" sev="$2" st="$3" cat="${4:-demo}"
    AUDIT_IDS+=("$id")
    AUDIT_SEV[$id]="$sev"; AUDIT_BASE_SEV[$id]="$sev"; AUDIT_CAT[$id]="$cat"
    AUDIT_STATUS[$id]="$st"
}

_many() { # _many N SEV STATUS PREFIJO
    local i
    for ((i = 1; i <= $1; i++)); do _mk "$4-$i" "$2" "$3"; done
}

test_all_pass_is_10() {
    audit_reset
    _mk A high PASS; _mk B medium PASS; _mk C low PASS
    audit_compute_score
    assert_eq 10 "$AUDIT_SCORE"
    assert_eq 100 "$AUDIT_PERCENT"
    assert_eq "" "$AUDIT_CAP"
}

test_one_critical_caps_6() {
    audit_reset
    _many 20 medium PASS M
    _mk C1 critical FAIL
    audit_compute_score
    assert_eq 86 "$AUDIT_PERCENT"
    assert_eq 9 "$AUDIT_SCORE_BASE"
    assert_eq 6 "$AUDIT_SCORE"
    assert_eq 6 "$AUDIT_CAP"
    assert_contains "$AUDIT_CAP_REASON" "1 hallazgo crítico"
    assert_eq 1 "${AUDIT_COUNT[critical]}"
}

test_two_critical_caps_4() {
    audit_reset
    _many 40 medium PASS M
    _mk C1 critical FAIL; _mk C2 critical WARN
    audit_compute_score
    assert_eq 4 "$AUDIT_SCORE"
    assert_contains "$AUDIT_CAP_REASON" "2 hallazgos críticos"
}

test_three_critical_caps_3() {
    audit_reset
    _many 60 medium PASS M
    _many 3 critical FAIL C
    audit_compute_score
    assert_eq 3 "$AUDIT_SCORE"
}

test_high_caps() {
    audit_reset
    _many 40 medium PASS M
    _mk H1 high FAIL
    audit_compute_score
    assert_eq 8 "$AUDIT_SCORE"
    audit_reset
    _many 80 medium PASS M
    _many 5 high FAIL H
    audit_compute_score
    assert_eq 6 "$AUDIT_SCORE"
    assert_contains "$AUDIT_CAP_REASON" "5 hallazgos altos"
}

test_warn_counts_half() {
    audit_reset
    _mk A medium PASS; _mk B medium WARN
    audit_compute_score
    assert_eq 75 "$AUDIT_PERCENT"
    assert_eq 1 "${AUDIT_COUNT[warn]}"
    assert_eq 1 "${AUDIT_COUNT[medium]}"
}

test_coverage_cap() {
    audit_reset
    _many 9 medium PASS P
    _many 2 medium SKIP S
    audit_compute_score
    assert_eq 6 "$AUDIT_SCORE"
    assert_contains "$AUDIT_CAP_REASON" "cobertura"
    audit_reset
    _many 9 medium PASS P
    _mk S1 medium SKIP
    audit_compute_score
    assert_eq 10 "$AUDIT_SCORE"
    assert_eq "" "$AUDIT_CAP"
}

test_na_and_waived_ignored() {
    audit_reset
    _mk A medium PASS; _mk B critical NA; _mk C critical WAIVED
    audit_compute_score
    assert_eq 100 "$AUDIT_PERCENT"
    assert_eq 0 "${AUDIT_COUNT[critical]}"
    assert_eq 1 "${AUDIT_COUNT[na]}"
    assert_eq 1 "${AUDIT_COUNT[waived]}"
    assert_eq 10 "$AUDIT_SCORE"
}

test_nothing_evaluated_is_1() {
    audit_reset
    _mk A medium SKIP
    audit_compute_score
    assert_eq 1 "$AUDIT_SCORE"
    assert_eq 0 "$AUDIT_PERCENT"
}

test_category_percent() {
    audit_reset
    _mk S1 medium PASS ssh; _mk S2 medium FAIL ssh; _mk N1 high NA network
    audit_compute_score
    assert_eq 50 "$(audit_category_percent ssh)"
    assert_eq "-" "$(audit_category_percent network)"
    assert_eq 1 "$(audit_category_open ssh)"
    assert_eq "ssh network" "$(audit_categories | tr '\n' ' ' | sed 's/ $//')"
}
