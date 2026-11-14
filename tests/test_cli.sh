#!/usr/bin/env bash
# Pruebas de punta a punta de "lso audit" (optimizer.sh audit …)
# shellcheck disable=SC2034

OPT="$LSO_BASE_DIR/optimizer.sh"
_lso() { bash "$OPT" "$@" --fast 2>/dev/null; }

test_json_stdout_is_clean() {
    local out
    out=$(_lso audit --json)
    assert_eq "{" "${out:0:1}"
    if command -v jq >/dev/null; then
        local expected
        expected=$(cat "$LSO_BASE_DIR"/modules/audit/checks/*.sh | grep -c '^audit_register ')
        assert_eq "$expected" "$(jq '.checks|length' <<< "$out")"
    fi
}

test_plain_has_score() {
    local out
    out=$(_lso audit --plain --no-color)
    assert_contains "$out" "Puntaje:"
    assert_not_contains "$out" "LINUX SYSTEM OPTIMIZER"
    assert_not_contains "$out" $'\033'
}

test_default_without_tty_is_plain() {
    assert_contains "$(_lso audit)" "Puntaje:"
}

test_bad_flag_exit_2() {
    assert_status 2 bash "$OPT" audit --nope
}

test_plain_and_json_conflict() {
    assert_status 2 bash "$OPT" audit --plain --json
}

test_unknown_profile_exit_2() {
    assert_status 2 bash "$OPT" audit --profile marciano
}

test_unknown_category_exit_2() {
    assert_status 2 bash "$OPT" audit --category nube
}

test_output_mode_600() {
    local tmp out
    tmp=$(mktemp -d)
    out=$(_lso audit --json --output "$tmp/r.json")
    assert_eq "" "$out"
    assert_eq "600" "$(stat -c %a "$tmp/r.json")"
    assert_eq "{" "$(head -c1 "$tmp/r.json")"
    rm -rf "$tmp"
}

test_category_filter() {
    local out
    out=$(_lso audit --json --category ssh)
    assert_contains "$out" '"category": "ssh"'
    assert_not_contains "$out" '"category": "accounts"'
    assert_not_contains "$out" '"category": "network"'
}

test_profile_server() {
    local out
    out=$(_lso audit --profile server --json)
    assert_contains "$out" '"class": "server"'
    assert_contains "$out" '"source": "chosen"'
}

test_help_lists_audit() {
    assert_contains "$(_lso help)" "audit"
    assert_contains "$(_lso audit --help)" "--plain"
}

test_min_score_exit_codes() {
    local score
    score=$(bash "$OPT" audit --json --fast 2>/dev/null | grep -o '"value": [0-9]*' | head -1 | grep -o '[0-9]*$')
    assert_status 0 bash "$OPT" audit --json --fast --min-score "$score"
    if (( score < 10 )); then
        assert_status 1 bash "$OPT" audit --json --fast --min-score $((score + 1))
    fi
}

test_min_score_invalid() {
    assert_status 2 bash "$OPT" audit --min-score 11
    assert_status 2 bash "$OPT" audit --min-score abc
}
