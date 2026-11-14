#!/usr/bin/env bash
# Pruebas de las revisiones de sistema de archivos (checks/filesystem.sh)
# shellcheck disable=SC2034

source "$LSO_BASE_DIR/modules/audit/engine.sh"
source "$LSO_BASE_DIR/modules/audit/helpers.sh"
source "$LSO_BASE_DIR/modules/audit/checks/filesystem.sh"

audit_owner_uid() { echo 0; }

_tree() { # _tree good|bad
    local r="$(mktemp -d)" k
    mkdir -p "$r/proc/sys/fs" "$r/etc/cron.d" "$r/home/ana" "$r/data/pub" "$r/usr/bin"
    printf 'root:x:0:0::/root:/bin/bash\nana:x:1000:1000::/home/ana:/bin/bash\n' > "$r/etc/passwd"
    printf 'x\n' > "$r/etc/group"; printf 'x\n' > "$r/etc/gshadow"; printf 'x\n' > "$r/etc/crontab"
    printf 'x\n' > "$r/etc/hosts"
    if [[ "$1" == good ]]; then
        printf 'tmpfs /tmp tmpfs rw,nosuid,nodev 0 0\ntmpfs /var/tmp tmpfs rw,nosuid,nodev 0 0\ntmpfs /dev/shm tmpfs rw,nosuid,nodev,noexec 0 0\n' > "$r/proc/mounts"
        for k in suid_dumpable:0 protected_symlinks:1 protected_hardlinks:1 protected_fifos:1 protected_regular:2; do
            printf '%s\n' "${k#*:}" > "$r/proc/sys/fs/${k%%:*}"
        done
        chmod 644 "$r/etc/group"; chmod 640 "$r/etc/gshadow"; chmod 600 "$r/etc/crontab"
        chmod 750 "$r/home/ana"; chmod 1777 "$r/data/pub"; chmod 700 "$r/etc/cron.d"
        printf '#!/bin/sh\n' > "$r/usr/bin/find"; chmod 755 "$r/usr/bin/find"
    else
        printf '/dev/sda1 / ext4 rw 0 0\ntmpfs /dev/shm tmpfs rw 0 0\n' > "$r/proc/mounts"
        for k in suid_dumpable:2 protected_symlinks:0 protected_hardlinks:0 protected_fifos:0 protected_regular:0; do
            printf '%s\n' "${k#*:}" > "$r/proc/sys/fs/${k%%:*}"
        done
        chmod 666 "$r/etc/group"; chmod 644 "$r/etc/gshadow"; chmod 666 "$r/etc/crontab"
        chmod 755 "$r/home/ana"; chmod 777 "$r/data/pub"; chmod 666 "$r/etc/hosts"
        printf '#!/bin/sh\n' > "$r/usr/bin/find"; chmod 4755 "$r/usr/bin/find"
    fi
    echo "$r"
}

_run() { AUDIT_ROOT="$1"; audit_run_all filesystem; }

test_fs_good() {
    local r id
    r=$(_tree good); _run "$r"
    for id in FS-001 FS-002 FS-003 FS-004 FS-005 FS-006 FS-007 FS-008 FS-010 FS-011 FS-012 FS-013 FS-014 FS-015 FS-016; do
        assert_eq PASS "${AUDIT_STATUS[$id]}" "$id: ${AUDIT_DETAIL[$id]}"
    done
    rm -rf "$r"
}

test_fs_bad() {
    local r id
    r=$(_tree bad); _run "$r"
    for id in FS-001 FS-002 FS-003 FS-004 FS-005 FS-006 FS-007 FS-008 FS-010 FS-011 FS-012 FS-013 FS-014 FS-015 FS-016; do
        assert_eq FAIL "${AUDIT_STATUS[$id]}" "$id: ${AUDIT_DETAIL[$id]}"
    done
    assert_contains "${AUDIT_DETAIL[FS-004]}" "/etc/hosts"
    assert_contains "${AUDIT_DETAIL[FS-005]}" "/data/pub"
    assert_contains "${AUDIT_DETAIL[FS-008]}" "/usr/bin/find"
    assert_contains "${AUDIT_DETAIL[FS-010]}" "/home/ana"
    assert_contains "${AUDIT_DETAIL[FS-003]}" "nosuid"
    rm -rf "$r"
}

test_fs_tmp_bind_var_tmp() {
    local r
    r=$(_tree good)
    printf 'tmpfs /tmp tmpfs rw,nosuid,nodev 0 0\ntmpfs /dev/shm tmpfs rw,nosuid,nodev,noexec 0 0\n' > "$r/proc/mounts"
    _run "$r"
    assert_eq FAIL "${AUDIT_STATUS[FS-002]}"
    assert_contains "${AUDIT_DETAIL[FS-002]}" "no es un montaje propio"
    rm -rf "$r"
}

test_fs_slow_flags() {
    assert_eq 1 "${AUDIT_SLOW[FS-005]}"
    assert_eq 1 "${AUDIT_SLOW[FS-008]}"
    assert_eq 1 "${AUDIT_SLOW[FS-009]}"
    assert_eq "" "${AUDIT_SLOW[FS-004]}"
}

test_fs_count_is_16() {
    local n=0 id
    for id in "${AUDIT_IDS[@]}"; do [[ "${AUDIT_CAT[$id]}" == filesystem ]] && n=$((n + 1)); done
    assert_eq 16 "$n"
}
