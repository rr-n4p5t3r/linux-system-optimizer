#!/usr/bin/env bash
# Pruebas de los ayudantes de lectura (modules/audit/helpers.sh)
# shellcheck disable=SC2034

source "$LSO_BASE_DIR/modules/audit/helpers.sh"
FIX="$TESTS_DIR/fixtures/ssh_include"

test_sshd_include_first_wins() {
    AUDIT_ROOT="$FIX"
    assert_eq "no" "$(audit_sshd_value permitrootlogin yes)"
}

test_sshd_include_later_file() {
    AUDIT_ROOT="$FIX"
    assert_eq "yes" "$(audit_sshd_value X11Forwarding no)"
}

test_sshd_spaces_and_case() {
    AUDIT_ROOT="$FIX"
    assert_eq "3" "$(audit_sshd_value maxauthtries 6)"
}

test_sshd_match_ignored() {
    AUDIT_ROOT="$FIX"
    assert_eq "yes" "$(audit_sshd_value passwordauthentication yes)"
    assert_eq "no" "$(audit_sshd_value passwordauthentication no)"
}

test_sshd_default() {
    AUDIT_ROOT="$FIX"
    assert_eq "120" "$(audit_sshd_value logingracetime 120)"
}

test_sshd_present() {
    AUDIT_ROOT="$FIX"
    assert_status 0 audit_sshd_present
    AUDIT_ROOT="$FIX/nada"
    assert_status 1 audit_sshd_present
}

test_sysctl_read() {
    AUDIT_ROOT="$FIX"
    assert_eq "0" "$(audit_sysctl net.ipv4.ip_forward)"
    assert_status 1 audit_sysctl net.ipv4.no_existe
}

test_perm() {
    local tmp
    tmp=$(mktemp)
    chmod 640 "$tmp"
    AUDIT_ROOT=""
    assert_eq "640" "$(audit_perm "$tmp")"
    rm -f "$tmp"
    assert_status 1 audit_perm "$tmp"
}

test_path_prefix() {
    AUDIT_ROOT="/x"
    assert_eq "/x/etc/passwd" "$(audit_path /etc/passwd)"
    AUDIT_ROOT=""
    assert_eq "/etc/passwd" "$(audit_path /etc/passwd)"
}
