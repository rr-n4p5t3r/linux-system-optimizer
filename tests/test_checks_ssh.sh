#!/usr/bin/env bash
# shellcheck disable=SC2154  # variables y arreglos definidos en otros archivos del módulo
# Pruebas de las revisiones SSH (modules/audit/checks/ssh.sh)
# Los árboles se crean en /tmp: el repo puede vivir en NTFS, sin permisos Unix.
# shellcheck disable=SC2034

source "$LSO_BASE_DIR/modules/audit/engine.sh"
source "$LSO_BASE_DIR/modules/audit/helpers.sh"
source "$LSO_BASE_DIR/modules/audit/checks/ssh.sh"

audit_owner_uid() { echo 0; }
audit_is_root() { return 1; }

_tree() { # _tree CONTENIDO_SSHD → imprime raíz temporal
    local root
    root=$(mktemp -d)
    mkdir -p "$root/etc/ssh"
    printf '%s\n' "$1" > "$root/etc/ssh/sshd_config"
    chmod 600 "$root/etc/ssh/sshd_config"
    printf 'k\n' > "$root/etc/ssh/ssh_host_ed25519_key"
    chmod 600 "$root/etc/ssh/ssh_host_ed25519_key"
    echo "$root"
}

BAD='PermitRootLogin yes
PasswordAuthentication yes
PermitEmptyPasswords yes
MaxAuthTries 10
X11Forwarding yes
Ciphers aes256-ctr,aes128-cbc
LoginGraceTime 2m'

GOOD='PermitRootLogin prohibit-password
PasswordAuthentication no
PermitEmptyPasswords no
MaxAuthTries 3
X11Forwarding no
Ciphers aes256-gcm@openssh.com,aes256-ctr
LoginGraceTime 30
ClientAliveInterval 300'

_run() { AUDIT_ROOT="$1"; audit_run_all ssh; }

test_ssh_bad_fails() {
    local root id
    root=$(_tree "$BAD")
    _run "$root"
    for id in SSH-001 SSH-002 SSH-003 SSH-004 SSH-005 SSH-006 SSH-007 SSH-010; do
        assert_eq "FAIL" "${AUDIT_STATUS[$id]}" "$id"
    done
    assert_eq "PASS" "${AUDIT_STATUS[SSH-008]}"
    assert_eq "PASS" "${AUDIT_STATUS[SSH-009]}"
    assert_contains "${AUDIT_DETAIL[SSH-001]}" "PermitRootLogin yes"
    assert_contains "${AUDIT_DETAIL[SSH-006]}" "aes128-cbc"
    rm -rf "$root"
}

test_ssh_good_passes() {
    local root id
    root=$(_tree "$GOOD")
    _run "$root"
    for id in SSH-001 SSH-002 SSH-003 SSH-004 SSH-005 SSH-006 SSH-007 SSH-008 SSH-009 SSH-010; do
        assert_eq "PASS" "${AUDIT_STATUS[$id]}" "$id"
    done
    rm -rf "$root"
}

test_ssh_count_is_10() {
    local n=0 id
    for id in "${AUDIT_IDS[@]}"; do [[ "${AUDIT_CAT[$id]}" == ssh ]] && n=$((n + 1)); done
    assert_eq 10 "$n"
}

test_no_sshd_is_na() {
    local root id
    root=$(mktemp -d)
    _run "$root"
    for id in SSH-001 SSH-005 SSH-009 SSH-010; do
        assert_eq "NA" "${AUDIT_STATUS[$id]}" "$id"
    done
    assert_eq "OpenSSH server no está instalado" "${AUDIT_DETAIL[SSH-001]}"
    rm -rf "$root"
}

test_host_key_world_readable() {
    local root
    root=$(_tree "$GOOD")
    chmod 644 "$root/etc/ssh/ssh_host_ed25519_key"
    _run "$root"
    assert_eq "FAIL" "${AUDIT_STATUS[SSH-009]}"
    assert_contains "${AUDIT_DETAIL[SSH-009]}" "ssh_host_ed25519_key"
    rm -rf "$root"
}

test_sshd_config_group_writable() {
    local root
    root=$(_tree "$GOOD")
    chmod 664 "$root/etc/ssh/sshd_config"
    _run "$root"
    assert_eq "FAIL" "${AUDIT_STATUS[SSH-008]}"
    rm -rf "$root"
}

test_sshd_config_not_root_owned() {
    local root
    root=$(_tree "$GOOD")
    audit_owner_uid() { echo 1000; }
    _run "$root"
    assert_eq "FAIL" "${AUDIT_STATUS[SSH-008]}"
    rm -rf "$root"
}
