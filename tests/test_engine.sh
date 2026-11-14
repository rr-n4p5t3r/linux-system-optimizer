#!/usr/bin/env bash
# Pruebas del motor de revisiones (modules/audit/engine.sh)
# shellcheck disable=SC2034

source "$LSO_BASE_DIR/modules/audit/engine.sh"

_pass_fn() { audit_pass "ok"; }
_fail_fn() { audit_fail "mal"; }
_none_fn() { :; }

test_register_and_run_pass() {
    audit_reset
    audit_register T-001 high demo "t" _pass_fn "fix"
    audit_run_all
    assert_eq "PASS" "${AUDIT_STATUS[T-001]}"
    assert_eq "ok" "${AUDIT_DETAIL[T-001]}"
    assert_eq "T-001" "${AUDIT_IDS[*]}"
    assert_eq "high" "${AUDIT_SEV[T-001]}"
    assert_eq "fix" "${AUDIT_FIX[T-001]}"
}

test_no_result_is_skip() {
    audit_reset
    audit_register T-001 low demo "t" _none_fn "fix"
    audit_run_all
    assert_eq "SKIP" "${AUDIT_STATUS[T-001]}"
    assert_eq "La revisión no reportó resultado" "${AUDIT_DETAIL[T-001]}"
}

CALLS=0
_count_fn() { CALLS=$((CALLS + 1)); audit_fail "x"; }

test_force_na_skips_execution() {
    audit_reset
    audit_register T-001 high demo "t" _count_fn "fix"
    AUDIT_FORCE_NA[T-001]="host"
    audit_run_all
    assert_eq "NA" "${AUDIT_STATUS[T-001]}"
    assert_eq "host" "${AUDIT_DETAIL[T-001]}"
    assert_eq "0" "$CALLS"
}

test_waived_overrides_open() {
    audit_reset
    audit_register T-001 high demo "t" _fail_fn "fix"
    AUDIT_WAIVED[T-001]="ticket 1"
    audit_run_all
    assert_eq "WAIVED" "${AUDIT_STATUS[T-001]}"
    assert_eq "ticket 1" "${AUDIT_DETAIL[T-001]}"
}

test_category_filter() {
    audit_reset
    audit_register S-001 high ssh "t" _pass_fn "fix"
    audit_register N-001 high network "t" _pass_fn "fix"
    audit_run_all "ssh"
    assert_eq "PASS" "${AUDIT_STATUS[S-001]}"
    assert_eq "" "${AUDIT_STATUS[N-001]:-}"
}

_fail_then_return() { audit_fail "boom"; return 1; }

test_failing_function_does_not_abort() {
    audit_reset
    audit_register T-001 high demo "t" _fail_then_return "fix"
    audit_register T-002 high demo "t" _pass_fn "fix"
    audit_run_all
    assert_eq "FAIL" "${AUDIT_STATUS[T-001]}"
    assert_eq "PASS" "${AUDIT_STATUS[T-002]}"
}

test_invalid_severity_rejected() {
    audit_reset
    assert_status 1 audit_register T-001 enorme demo "t" _pass_fn "fix"
}
