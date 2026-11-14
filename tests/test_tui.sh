#!/usr/bin/env bash
# shellcheck disable=SC2154  # variables y arreglos definidos en otros archivos del módulo
# Pruebas del tablero interactivo (render_tui.sh), sin terminal real:
# se construye el cuadro en memoria y se verifican medidas y contenido.
# shellcheck disable=SC2034

source "$LSO_BASE_DIR/modules/audit/engine.sh"
source "$LSO_BASE_DIR/modules/audit/score.sh"
source "$LSO_BASE_DIR/modules/audit/render_plain.sh"
source "$LSO_BASE_DIR/modules/audit/render_tui.sh"

_f() { audit_fail "detalle de prueba"; }
_p() { audit_pass "bien"; }
_w() { audit_warn "ojo"; }

_setup() {
    audit_reset
    audit_register PER-009 critical persistence "PAM acepta cualquier autenticación" _f "Quita pam_permit"
    audit_register HRD-001 high hardening "Sin MAC activo" _f "Instala AppArmor"
    audit_register NET-001 medium network "Firewall local" _f "ufw enable"
    audit_register FS-010 low filesystem "Homes legibles" _w "chmod 750"
    local i
    for i in 1 2 3 4 5 6 7 8; do audit_register "OK-00$i" medium ssh "Bien $i" _p "nada"; done
    audit_run_all
    audit_compute_score
    AUDIT_VERSION="1.0.0"; AUDIT_HOST="zeus"; AUDIT_DISTRO="Linux Mint 22.3"
    AUDIT_DURATION="5.4"; AUDIT_IS_ROOT=true
    AUDIT_PROFILE_CLASS=desktop; AUDIT_PROFILE_SOURCE=chosen; AUDIT_PROFILE_LABEL="Escritorio / laptop"
    TUI_COLORS=256
    tui_init_state
}

# Ancho visible de una línea (sin secuencias ANSI).
_vis() { local s="$1"; s=$(sed 's/\x1b\[[0-9;]*m//g' <<< "$s"); echo "${#s}"; }

_check_widths() {
    local i
    for i in "${!TUI_FRAME[@]}"; do
        assert_eq "$1" "$(_vis "${TUI_FRAME[$i]}")" "ancho de la línea $i"
    done
    assert_eq "$2" "${#TUI_FRAME[@]}" "cantidad de líneas"
}

test_summary_frame_fits() {
    _setup
    tui_build_frame 110 32
    _check_widths 110 32
    local all
    all=$(printf '%s\n' "${TUI_FRAME[@]}")
    assert_contains "$all" "Puntaje"
    assert_contains "$all" "Abiertos por gravedad"
    assert_contains "$all" "Categorías"
    assert_contains "$all" "Lo más urgente"
    assert_contains "$all" "PER-009"
    assert_contains "$all" "zeus"
    assert_contains "$all" "de 10"
}

test_frame_fits_wide_terminal() {
    _setup
    tui_build_frame 160 45
    _check_widths 160 45
}

test_tab_cycles() {
    _setup
    assert_eq 1 "$TUI_TAB"
    tui_handle_key TAB;  assert_eq 2 "$TUI_TAB"
    tui_handle_key TAB;  assert_eq 3 "$TUI_TAB"
    tui_handle_key TAB;  assert_eq 1 "$TUI_TAB"
    tui_handle_key 3;    assert_eq 3 "$TUI_TAB"
}

test_selection_moves_and_clamps() {
    _setup
    tui_handle_key DOWN; assert_eq 1 "$TUI_SEL"
    tui_handle_key UP;   assert_eq 0 "$TUI_SEL"
    tui_handle_key UP;   assert_eq 0 "$TUI_SEL"
    tui_handle_key END;  assert_eq 3 "$TUI_SEL" "4 hallazgos abiertos"
}

test_findings_tab_and_detail() {
    _setup
    tui_handle_key 2
    tui_build_frame 110 32
    _check_widths 110 32
    tui_handle_key ENTER
    assert_eq "PER-009" "$TUI_DETAIL"
    tui_build_frame 110 32
    _check_widths 110 32
    local all
    all=$(printf '%s\n' "${TUI_FRAME[@]}")
    assert_contains "$all" "Quita pam_permit"
    assert_contains "$all" "detalle de prueba"
    tui_handle_key ESC
    assert_eq "" "$TUI_DETAIL"
}

test_findings_all_toggle_and_severity_filter() {
    _setup
    tui_handle_key 2
    assert_eq 4 "$(tui_items | wc -l)"
    tui_handle_key a
    assert_eq 12 "$(tui_items | wc -l)"
    tui_handle_key a
    tui_handle_key s
    assert_eq "critical" "$TUI_FILTER_SEV"
    assert_eq 1 "$(tui_items | wc -l)"
}

test_categories_enter_filters_findings() {
    _setup
    tui_handle_key 3
    tui_build_frame 110 32
    _check_widths 110 32
    tui_handle_key ENTER
    assert_eq 2 "$TUI_TAB"
    assert_eq "persistence" "$TUI_FILTER_CAT"
}

test_help_overlay() {
    _setup
    tui_handle_key '?'
    tui_build_frame 110 32
    _check_widths 110 32
    assert_contains "$(printf '%s\n' "${TUI_FRAME[@]}")" "Atajos"
    tui_handle_key '?'
    assert_eq 0 "$TUI_HELP"
}

test_quit_key() {
    _setup
    tui_handle_key q
    assert_eq 1 "$TUI_QUIT"
}

test_small_terminal_message() {
    _setup
    tui_build_frame 60 20
    assert_contains "$(printf '%s\n' "${TUI_FRAME[@]}")" "100×30"
}

test_score_digits() {
    _setup
    AUDIT_SCORE=10
    tui_build_frame 110 32
    _check_widths 110 32
}

test_eight_color_fallback() {
    _setup
    TUI_COLORS=8
    tui_build_frame 110 32
    _check_widths 110 32
    assert_not_contains "$(printf '%s' "${TUI_FRAME[@]}")" "38;5;"
}

test_percent_correct_with_newline_ifs() {
    _setup
    _build_with_nl_ifs() { local IFS=$'\n'; tui_build_frame 110 32; }
    _build_with_nl_ifs
    local all
    all=$(printf '%s\n' "${TUI_FRAME[@]}" | sed 's/\x1b\[[0-9;]*m//g')
    assert_contains "$all" "filesystem  "
    assert_contains "$all" " 50 % ✖ 1" "filesystem tiene 1 de 2 revisiones bajas aprobadas a medias"
    assert_not_contains "$all" "persistence ━━━━━━━━━━━━━━━━━━━━━━━ 100 %"
}
