#!/usr/bin/env bash
# =============================================================================
# lib.sh — Asserts para las pruebas de LSO
# =============================================================================
# Linux System Optimizer (LSO)
# Autor: Ricardo Rosero <rrosero2000@gmail.com>
# GitHub: https://github.com/rr-n4p5t3r
# Licencia: GPLv3
# =============================================================================

TEST_FAILS=0

_test_fail() {
    TEST_FAILS=$((TEST_FAILS + 1))
    printf '    ✗ %s\n' "$1" >&2
}

assert_eq() {
    local expected="$1" actual="$2" msg="${3:-}"
    [[ "$expected" == "$actual" ]] && return 0
    _test_fail "${msg:+$msg: }esperado [$expected], obtenido [$actual]"
}

assert_contains() {
    local text="$1" sub="$2" msg="${3:-}"
    [[ "$text" == *"$sub"* ]] && return 0
    _test_fail "${msg:+$msg: }no contiene [$sub] en [${text:0:300}]"
}

assert_not_contains() {
    local text="$1" sub="$2" msg="${3:-}"
    [[ "$text" != *"$sub"* ]] && return 0
    _test_fail "${msg:+$msg: }contiene [$sub] en [${text:0:300}]"
}

# assert_status CODIGO cmd args...
assert_status() {
    local expected="$1"; shift
    local rc=0
    "$@" >/dev/null 2>&1 || rc=$?
    [[ "$rc" == "$expected" ]] && return 0
    _test_fail "código esperado $expected, obtenido $rc: $*"
}

# Marca la prueba como omitida (código 77).
skip_test() {
    printf '    (omitida: %s)\n' "$1"
    exit 77
}
