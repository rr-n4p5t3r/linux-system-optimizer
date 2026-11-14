#!/usr/bin/env bash
# shellcheck disable=SC2154  # variables y arreglos definidos en otros archivos del módulo
# Pruebas de las revisiones de actualizaciones (checks/patching.sh)
# shellcheck disable=SC2034

source "$LSO_BASE_DIR/modules/audit/engine.sh"
source "$LSO_BASE_DIR/modules/audit/helpers.sh"
source "$LSO_BASE_DIR/modules/audit/checks/patching.sh"

LSO_PACKAGE_MANAGER=apt
audit_have() { [[ "$1" == apt-get || "$1" == systemctl ]]; }
audit_cmd_apt_upgrade_sim() { printf 'Inst libc6 [2.39-0ubuntu8.3] (2.39-0ubuntu8.4 Ubuntu:24.04/noble-updates, Ubuntu:24.04/noble-security [amd64])\nInst vim [2:9.1] (2:9.1.1 Ubuntu:24.04/noble-updates [amd64])\n'; }
audit_cmd_uname_r() { echo "6.8.0-40-generic"; }

_apt_tree() { # good|bad
    local r
    r=$(mktemp -d)
    mkdir -p "$r/var/lib/apt/periodic" "$r/etc/apt/apt.conf.d" "$r/etc/apt/sources.list.d" "$r/usr/bin" "$r/boot" "$r/var/run"
    touch "$r/boot/vmlinuz-6.8.0-40-generic" "$r/boot/vmlinuz-6.8.0-31-generic"
    if [[ "$1" == good ]]; then
        touch "$r/var/lib/apt/periodic/update-success-stamp"
        printf 'APT::Periodic::Update-Package-Lists "1";\nAPT::Periodic::Unattended-Upgrade "1";\n' > "$r/etc/apt/apt.conf.d/20auto-upgrades"
        touch "$r/usr/bin/unattended-upgrade"
        printf 'deb http://archive.ubuntu.com/ubuntu noble main\n' > "$r/etc/apt/sources.list"
    else
        touch -d '30 days ago' "$r/var/lib/apt/periodic/update-success-stamp"
        printf 'deb [trusted=yes] http://repo.example noble main\n' > "$r/etc/apt/sources.list.d/x.list"
        printf 'linux-image-6.8.0-45-generic\n' > "$r/var/run/reboot-required.pkgs"
        touch "$r/var/run/reboot-required" "$r/boot/vmlinuz-6.8.0-45-generic"
    fi
    echo "$r"
}

_run() { AUDIT_ROOT="$1"; audit_run_all patching; }

test_patching_good() {
    local r id
    r=$(_apt_tree good)
    audit_cmd_apt_upgrade_sim() { printf 'Inst vim [2:9.1] (2:9.1.1 Ubuntu:24.04/noble-updates [amd64])\n'; }
    _run "$r"
    for id in PAT-001 PAT-002 PAT-003 PAT-004 PAT-005 PAT-006; do
        assert_eq PASS "${AUDIT_STATUS[$id]}" "$id: ${AUDIT_DETAIL[$id]}"
    done
    rm -rf "$r"
}

test_patching_bad() {
    local r id
    r=$(_apt_tree bad)
    _run "$r"
    for id in PAT-001 PAT-002 PAT-003 PAT-004 PAT-005 PAT-006; do
        assert_eq FAIL "${AUDIT_STATUS[$id]}" "$id: ${AUDIT_DETAIL[$id]}"
    done
    assert_contains "${AUDIT_DETAIL[PAT-001]}" "1"
    assert_contains "${AUDIT_DETAIL[PAT-004]}" "linux-image"
    assert_contains "${AUDIT_DETAIL[PAT-005]}" "6.8.0-45"
    assert_contains "${AUDIT_DETAIL[PAT-006]}" "x.list"
    rm -rf "$r"
}

test_dnf_gpgcheck_off() {
    local r
    r=$(mktemp -d); mkdir -p "$r/etc/yum.repos.d"
    printf '[x]\nbaseurl=http://x\ngpgcheck=0\n' > "$r/etc/yum.repos.d/x.repo"
    LSO_PACKAGE_MANAGER=dnf
    _run "$r"
    assert_eq FAIL "${AUDIT_STATUS[PAT-006]}"
    rm -rf "$r"
}

test_dnf_automatic_timer() {
    local r
    r=$(mktemp -d)
    LSO_PACKAGE_MANAGER=dnf
    audit_cmd_systemctl_is_enabled() { [[ "$1" == dnf-automatic.timer || "$1" == dnf-automatic-install.timer ]] && echo enabled || echo disabled; }
    _run "$r"
    assert_eq PASS "${AUDIT_STATUS[PAT-003]}"
    rm -rf "$r"
}

test_unknown_pm_is_na() {
    local r
    r=$(mktemp -d)
    LSO_PACKAGE_MANAGER=""
    audit_have() { return 1; }
    _run "$r"
    assert_eq NA "${AUDIT_STATUS[PAT-001]}"
    assert_eq NA "${AUDIT_STATUS[PAT-003]}"
    rm -rf "$r"
}
