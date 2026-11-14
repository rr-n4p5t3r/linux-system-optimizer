#!/usr/bin/env bash
# shellcheck disable=SC2154  # variables y arreglos definidos en otros archivos del módulo
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

test_mount_opts() {
    local r
    r=$(mktemp -d)
    mkdir -p "$r/proc"
    printf '/dev/sda1 / ext4 rw,relatime 0 0\ntmpfs /tmp tmpfs rw,nosuid,nodev 0 0\ntmpfs /dev/shm tmpfs rw,nosuid,nodev,noexec 0 0\n' > "$r/proc/mounts"
    AUDIT_ROOT="$r"
    assert_eq "rw,nosuid,nodev" "$(audit_mount_opts /tmp)"
    assert_status 1 audit_mount_opts /var/tmp
    rm -rf "$r"
}

test_service_active() {
    audit_have() { [[ "$1" == systemctl ]]; }
    audit_cmd_systemctl_is_active() { [[ "$1" == chronyd.service || "$1" == chronyd ]]; }
    assert_status 0 audit_service_active systemd-timesyncd chronyd
    assert_status 1 audit_service_active auditd
    audit_have() { return 1; }
    assert_status 2 audit_service_active auditd
}

test_user_homes() {
    local r
    r=$(mktemp -d)
    mkdir -p "$r/etc"
    printf 'root:x:0:0::/root:/bin/bash\ndaemon:x:1:1::/usr/sbin:/usr/sbin/nologin\nana:x:1000:1000::/home/ana:/bin/bash\nnobody:x:65534:65534::/nonexistent:/usr/sbin/nologin\n' > "$r/etc/passwd"
    AUDIT_ROOT="$r"
    assert_eq "root /root|ana /home/ana" "$(audit_user_homes | paste -sd'|' -)"
    rm -rf "$r"
}

test_user_homes_skips_service_accounts() {
    local r
    r=$(mktemp -d); mkdir -p "$r/etc"
    printf 'root:x:0:0::/root:/bin/bash\nlibvirt-qemu:x:64055:108::/var/lib/libvirt:/usr/sbin/nologin\nana:x:1000:1000::/home/ana:/bin/zsh\nsvc:x:1001:1001::/srv/svc:/bin/false\n' > "$r/etc/passwd"
    AUDIT_ROOT="$r"
    assert_eq "root /root|ana /home/ana" "$(audit_user_homes | paste -sd'|' -)"
    rm -rf "$r"
}
