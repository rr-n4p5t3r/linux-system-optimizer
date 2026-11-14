#!/usr/bin/env bash
# shellcheck disable=SC2154  # variables y arreglos definidos en otros archivos del módulo
# Pruebas de las salidas plain y JSON (render_plain.sh, render_json.sh)
# shellcheck disable=SC2034

source "$LSO_BASE_DIR/modules/audit/engine.sh"
source "$LSO_BASE_DIR/modules/audit/score.sh"
source "$LSO_BASE_DIR/modules/audit/render_plain.sh"
source "$LSO_BASE_DIR/modules/audit/render_json.sh"

_st() { audit_fail "$1"; }
_p() { audit_pass "bien"; }
_l() { audit_fail "bajo"; }
_n() { audit_na "no aplica"; }

_setup() {
    audit_reset
    audit_register LOW-001 low demo "Algo menor" _l "arregla lo menor"
    audit_register CRI-001 critical demo "Algo grave" _st_grave 'chmod 600 "/x"'
    _st_grave() { audit_fail 'detalle con "comillas" y \barra'; }
    audit_register OK-001 medium otra "Algo bien" _p "nada"
    audit_register NA-001 high otra "No aplica" _n "nada"
    audit_register NET-001 high network "Firewall" _l "ufw enable"
    AUDIT_SEV[NET-001]=medium; AUDIT_ADJ[NET-001]="desktop:medium"
    audit_run_all
    audit_compute_score
    AUDIT_VERSION="0.4.0"; AUDIT_HOST="equipo"; AUDIT_DISTRO="Ubuntu 24.04"
    AUDIT_DURATION="1.2"; AUDIT_IS_ROOT=false; AUDIT_COLOR=0
    AUDIT_PROFILE_CLASS=desktop; AUDIT_PROFILE_SOURCE=detected; AUDIT_PROFILE_LABEL="Escritorio"
}

test_plain_no_ansi_when_color_off() {
    _setup
    local out
    out=$(audit_render_plain)
    assert_not_contains "$out" $'\033'
    assert_contains "$out" "Puntaje: "
    assert_contains "$out" "Escritorio (detectado)"
}

test_plain_has_color_when_on() {
    _setup
    AUDIT_COLOR=1
    assert_contains "$(audit_render_plain)" $'\033['
}

test_plain_sorted_by_severity() {
    _setup
    local out a b
    out=$(audit_render_plain)
    a="${out%%CRI-001*}"; b="${out%%LOW-001*}"
    (( ${#a} < ${#b} )) || _test_fail "CRI-001 debería aparecer antes que LOW-001"
    assert_contains "$out" "[CRÍTICO]"
    assert_contains "$out" "Corrección: arregla lo menor"
    assert_not_contains "$out" "OK-001" "las aprobadas no salen sin --all"
}

_setup_capped() {
    _setup
    local i
    for ((i = 10; i < 40; i++)); do
        audit_register "PAS-0$i" medium otra "Pasa" _p "nada"
    done
    audit_run_all
    audit_compute_score
}

test_plain_shows_cap() {
    _setup_capped
    assert_contains "$(audit_render_plain)" "Tope 6/10: 1 hallazgo crítico abierto"
}

test_plain_all_lists_pass() {
    _setup
    local out
    out=$(audit_render_plain all)
    assert_contains "$out" "OK-001"
    assert_contains "$out" "NA-001"
}

test_sorted_ids() {
    _setup
    assert_eq "CRI-001 NET-001 LOW-001" "$(audit_sorted_ids | tr '\n' ' ' | sed 's/ $//')"
}

test_json_escape() {
    local s
    s=$(audit_json_escape $'a"b\\c\nd\te\x01')
    assert_eq 'a\"b\\c\nd\te\u0001' "$s"
}

test_json_valid() {
    command -v jq >/dev/null || skip_test "jq no está instalado"
    _setup
    local out
    out=$(audit_render_json)
    assert_status 0 jq -e '.schema==1 and .tool=="lso-audit" and .score.value>=1 and (.checks|length)==5' <<< "$out"
    assert_eq '"detalle con \"comillas\" y \\barra"' "$(jq '.checks[]|select(.id=="CRI-001").detail' <<< "$out")"
    assert_eq '1' "$(jq '.counts.low' <<< "$out")"
    out=$(_setup_capped; audit_render_json)
    assert_eq '6' "$(jq '.score.cap.value' <<< "$out")"
    assert_contains "$(jq -r '.score.cap.reason' <<< "$out")" "crítico"
    assert_eq 'false' "$(jq '.root' <<< "$out")"
    assert_eq '1' "$(jq '.counts.critical' <<< "$out")"
    assert_eq '"desktop"' "$(jq '.profile.class' <<< "$out")"
}

test_json_profile_adjusted() {
    command -v jq >/dev/null || skip_test "jq no está instalado"
    _setup
    assert_eq '"desktop:medium"' "$(audit_render_json | jq '.checks[]|select(.id=="NET-001").adjusted')"
}

test_json_no_cap_is_null() {
    command -v jq >/dev/null || skip_test "jq no está instalado"
    audit_reset
    audit_register OK-001 medium otra "Algo bien" _p "nada"
    audit_run_all; audit_compute_score
    AUDIT_VERSION=x; AUDIT_HOST=h; AUDIT_DISTRO=d; AUDIT_DURATION=0.1; AUDIT_IS_ROOT=true
    AUDIT_PROFILE_CLASS=server; AUDIT_PROFILE_SOURCE=chosen; AUDIT_PROFILE_LABEL=Servidor
    assert_eq 'null' "$(audit_render_json | jq '.score.cap')"
}
