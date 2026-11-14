#!/usr/bin/env bash
# Pruebas de las revisiones de endurecimiento (checks/hardening.sh)
# shellcheck disable=SC2034

source "$LSO_BASE_DIR/modules/audit/engine.sh"
source "$LSO_BASE_DIR/modules/audit/helpers.sh"
source "$LSO_BASE_DIR/modules/audit/checks/hardening.sh"

audit_have() { [[ "$1" == systemctl ]]; }
ACTIVE=""
audit_cmd_systemctl_is_active() { [[ " $ACTIVE " == *" $1 "* ]]; }
ENABLED_STATE="enabled"
audit_cmd_systemctl_is_enabled() { echo "$ENABLED_STATE"; }

_sys() { # _sys RAIZ clave=valor…
    local r="$1" kv k
    shift
    for kv in "$@"; do
        k="${kv%%=*}"
        mkdir -p "$(dirname "$r/proc/sys/${k//.//}")"
        printf '%s\n' "${kv#*=}" > "$r/proc/sys/${k//.//}"
    done
}

_good() {
    local r
    r=$(mktemp -d)
    mkdir -p "$r/sys/module/apparmor/parameters" "$r/var/log/journal" "$r/boot/grub" \
        "$r/etc/modprobe.d" "$r/etc/security"
    printf 'Y\n' > "$r/sys/module/apparmor/parameters/enabled"
    _sys "$r" kernel.randomize_va_space=2 kernel.kptr_restrict=1 kernel.dmesg_restrict=1 \
        kernel.yama.ptrace_scope=1 kernel.unprivileged_bpf_disabled=2
    printf 'x\n' > "$r/boot/grub/grub.cfg"; chmod 600 "$r/boot/grub/grub.cfg"
    printf 'Acceso solo para usuarios autorizados.\n' > "$r/etc/issue.net"
    local fs
    for fs in cramfs freevxfs hfs hfsplus jffs2 udf; do
        printf 'install %s /bin/false\n' "$fs" >> "$r/etc/modprobe.d/lso.conf"
    done
    printf '*    hard    core    0\n' > "$r/etc/security/limits.conf"
    echo "$r"
}

_bad() {
    local r
    r=$(mktemp -d)
    mkdir -p "$r/sys/module/apparmor/parameters" "$r/boot/grub" "$r/etc/modprobe.d"
    printf 'N\n' > "$r/sys/module/apparmor/parameters/enabled"
    _sys "$r" kernel.randomize_va_space=0 kernel.kptr_restrict=0 kernel.dmesg_restrict=0 \
        kernel.yama.ptrace_scope=0 kernel.unprivileged_bpf_disabled=0
    printf 'x\n' > "$r/boot/grub/grub.cfg"; chmod 666 "$r/boot/grub/grub.cfg"
    printf 'Ubuntu 24.04\n' > "$r/etc/issue.net"
    printf 'blacklist cramfs\n' > "$r/etc/modprobe.d/x.conf"
    echo "$r"
}

_run() { AUDIT_ROOT="$1"; audit_run_all hardening; }

_all="HRD-001 HRD-002 HRD-003 HRD-004 HRD-005 HRD-006 HRD-007 HRD-008 HRD-009 HRD-010 HRD-011 HRD-012 HRD-013 HRD-014"

test_hardening_good() {
    local r id
    r=$(_good); ACTIVE="auditd systemd-timesyncd"; ENABLED_STATE="masked"; _run "$r"
    for id in $_all; do
        assert_eq PASS "${AUDIT_STATUS[$id]}" "$id: ${AUDIT_DETAIL[$id]}"
    done
    rm -rf "$r"
}

test_hardening_bad() {
    local r id
    r=$(_bad); ACTIVE=""; ENABLED_STATE="static"; _run "$r"
    for id in $_all; do
        assert_eq FAIL "${AUDIT_STATUS[$id]}" "$id: ${AUDIT_DETAIL[$id]}"
    done
    assert_contains "${AUDIT_DETAIL[HRD-013]}" "freevxfs"
    assert_not_contains "${AUDIT_DETAIL[HRD-013]}" "cramfs"
    rm -rf "$r"
}

test_selinux_enforcing() {
    local r
    r=$(_bad); ACTIVE=""; ENABLED_STATE="static"
    mkdir -p "$r/sys/fs/selinux"; printf '1\n' > "$r/sys/fs/selinux/enforce"
    _run "$r"
    assert_eq PASS "${AUDIT_STATUS[HRD-001]}"
    printf '0\n' > "$r/sys/fs/selinux/enforce"
    _run "$r"
    assert_eq FAIL "${AUDIT_STATUS[HRD-001]}"
    assert_contains "${AUDIT_DETAIL[HRD-001]}" "permissive"
    rm -rf "$r"
}

test_no_systemctl_is_skip() {
    local r
    r=$(_good); ACTIVE="auditd systemd-timesyncd"; ENABLED_STATE="masked"
    audit_have() { return 1; }
    _run "$r"
    assert_eq SKIP "${AUDIT_STATUS[HRD-002]}"
    assert_eq SKIP "${AUDIT_STATUS[HRD-012]}"
    rm -rf "$r"
}

test_grub_world_readable_warns() {
    local r
    r=$(_good); ACTIVE="auditd systemd-timesyncd"; ENABLED_STATE="masked"; chmod 644 "$r/boot/grub/grub.cfg"
    _run "$r"
    assert_eq WARN "${AUDIT_STATUS[HRD-010]}"
    rm -rf "$r"
}

test_coredump_systemd_storage_none() {
    local r
    r=$(_good); ACTIVE="auditd systemd-timesyncd"; ENABLED_STATE="masked"; rm -f "$r/etc/security/limits.conf"
    mkdir -p "$r/etc/systemd"; printf '[Coredump]\nStorage=none\n' > "$r/etc/systemd/coredump.conf"
    _run "$r"
    assert_eq PASS "${AUDIT_STATUS[HRD-014]}"
    rm -rf "$r"
}

test_apparmor_profiles_hidden_without_root() {
    local r
    r=$(_good); ACTIVE="auditd systemd-timesyncd"; ENABLED_STATE="masked"
    mkdir -p "$r/sys/kernel/security/apparmor"; : > "$r/sys/kernel/security/apparmor/profiles"
    audit_is_root() { return 1; }
    _run "$r"
    assert_eq PASS "${AUDIT_STATUS[HRD-001]}" "sin root el archivo de perfiles se ve vacío"
    audit_is_root() { return 0; }
    _run "$r"
    assert_eq FAIL "${AUDIT_STATUS[HRD-001]}" "con root, vacío significa sin perfiles"
    rm -rf "$r"
}
