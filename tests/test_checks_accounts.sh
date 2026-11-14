#!/usr/bin/env bash
# shellcheck disable=SC2154  # variables y arreglos definidos en otros archivos del módulo
# Pruebas de las revisiones de cuentas (modules/audit/checks/accounts.sh)
# shellcheck disable=SC2034

source "$LSO_BASE_DIR/modules/audit/engine.sh"
source "$LSO_BASE_DIR/modules/audit/helpers.sh"
source "$LSO_BASE_DIR/modules/audit/checks/accounts.sh"

audit_owner_uid() { echo 0; }

_bad_tree() {
    local r
    r=$(mktemp -d)
    mkdir -p "$r/etc/sudoers.d" "$r/etc/security" "$r/etc/pam.d"
    cat > "$r/etc/passwd" <<'P'
root:x:0:0:root:/root:/bin/bash
toor:x:0:0::/root:/bin/bash
daemon:x:1:1:daemon:/usr/sbin:/bin/bash
ana:x:1001:1001::/home/ana:/bin/bash
beto:x:1001:1001::/home/beto:/bin/bash
P
    cat > "$r/etc/shadow" <<'S'
root:$6$abc$hash:19000:0:99999:7:::
test::19000:0:99999:7:::
S
    printf 'PASS_MAX_DAYS 99999\nUMASK 022\n' > "$r/etc/login.defs"
    printf 'minlen = 6\n' > "$r/etc/security/pwquality.conf"
    printf 'root ALL=(ALL) ALL\n' > "$r/etc/sudoers"
    printf 'ana ALL=(ALL) NOPASSWD: ALL\n' > "$r/etc/sudoers.d/ana"
    chmod 644 "$r/etc/passwd"; chmod 644 "$r/etc/shadow"; chmod 440 "$r/etc/sudoers"
    echo "$r"
}

_good_tree() {
    local r
    r=$(mktemp -d)
    mkdir -p "$r/etc/sudoers.d" "$r/etc/security" "$r/etc/pam.d"
    cat > "$r/etc/passwd" <<'P'
root:x:0:0:root:/root:/bin/bash
daemon:x:1:1:daemon:/usr/sbin:/usr/sbin/nologin
sync:x:4:65534:sync:/bin:/bin/sync
ana:x:1001:1001::/home/ana:/bin/bash
P
    cat > "$r/etc/shadow" <<'S'
root:!:19000:0:99999:7:::
ana:$6$abc$hash:19000:0:365:7:::
S
    printf 'PASS_MAX_DAYS 180\nUMASK 027\n' > "$r/etc/login.defs"
    printf '# comentario\nminlen = 12\n' > "$r/etc/security/pwquality.conf"
    printf 'root ALL=(ALL) ALL\n# ana ALL=(ALL) NOPASSWD: ALL\n' > "$r/etc/sudoers"
    chmod 644 "$r/etc/passwd"; chmod 640 "$r/etc/shadow"; chmod 440 "$r/etc/sudoers"
    echo "$r"
}

_run() { AUDIT_ROOT="$1"; audit_run_all accounts; }

test_accounts_bad() {
    local r
    r=$(_bad_tree)
    _run "$r"
    assert_eq FAIL "${AUDIT_STATUS[ACC-001]}" ACC-001
    assert_contains "${AUDIT_DETAIL[ACC-001]}" "toor"
    assert_eq FAIL "${AUDIT_STATUS[ACC-002]}" ACC-002
    assert_contains "${AUDIT_DETAIL[ACC-002]}" "test"
    assert_not_contains "${AUDIT_DETAIL[ACC-002]}" '$6$'
    assert_eq FAIL "${AUDIT_STATUS[ACC-003]}" ACC-003
    assert_eq PASS "${AUDIT_STATUS[ACC-004]}" ACC-004
    assert_eq FAIL "${AUDIT_STATUS[ACC-005]}" ACC-005
    assert_eq FAIL "${AUDIT_STATUS[ACC-006]}" ACC-006
    assert_eq FAIL "${AUDIT_STATUS[ACC-007]}" ACC-007
    assert_contains "${AUDIT_DETAIL[ACC-007]}" "1001"
    assert_eq WARN "${AUDIT_STATUS[ACC-008]}" ACC-008
    assert_contains "${AUDIT_DETAIL[ACC-008]}" "daemon"
    assert_eq WARN "${AUDIT_STATUS[ACC-009]}" ACC-009
    assert_eq FAIL "${AUDIT_STATUS[ACC-010]}" ACC-010
    assert_contains "${AUDIT_DETAIL[ACC-010]}" "sudoers.d/ana"
    rm -rf "$r"
}

test_accounts_good() {
    local r id
    r=$(_good_tree)
    _run "$r"
    for id in ACC-001 ACC-002 ACC-003 ACC-004 ACC-005 ACC-006 ACC-007 ACC-008 ACC-009 ACC-010; do
        assert_eq PASS "${AUDIT_STATUS[$id]}" "$id: ${AUDIT_DETAIL[$id]}"
    done
    rm -rf "$r"
}

test_minlen_from_pam() {
    local r
    r=$(_good_tree)
    rm -f "$r/etc/security/pwquality.conf"
    printf 'password requisite pam_pwquality.so retry=3 minlen=10\n' > "$r/etc/pam.d/common-password"
    _run "$r"
    assert_eq PASS "${AUDIT_STATUS[ACC-006]}"
    rm -rf "$r"
}

test_shadow_unreadable_is_skip() {
    [[ $EUID -eq 0 ]] && skip_test "root puede leer cualquier archivo"
    local r
    r=$(_good_tree)
    chmod 000 "$r/etc/shadow" "$r/etc/sudoers"
    _run "$r"
    assert_eq SKIP "${AUDIT_STATUS[ACC-002]}"
    assert_contains "${AUDIT_DETAIL[ACC-002]}" "root"
    assert_eq SKIP "${AUDIT_STATUS[ACC-010]}"
    chmod 600 "$r/etc/shadow" "$r/etc/sudoers"
    rm -rf "$r"
}

test_no_login_defs_is_skip() {
    local r
    r=$(_good_tree)
    rm -f "$r/etc/login.defs"
    _run "$r"
    assert_eq SKIP "${AUDIT_STATUS[ACC-005]}"
    assert_eq SKIP "${AUDIT_STATUS[ACC-009]}"
    rm -rf "$r"
}
