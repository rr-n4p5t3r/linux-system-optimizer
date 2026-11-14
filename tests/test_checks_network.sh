#!/usr/bin/env bash
# Pruebas de las revisiones de red (modules/audit/checks/network.sh)
# shellcheck disable=SC2034

source "$LSO_BASE_DIR/modules/audit/engine.sh"
source "$LSO_BASE_DIR/modules/audit/helpers.sh"
source "$LSO_BASE_DIR/modules/audit/checks/network.sh"

# Por defecto: ninguna herramienta disponible.
audit_have() { return 1; }
audit_is_root() { return 0; }

_sysctl_tree() { # _sysctl_tree good|bad
    local r v
    r=$(mktemp -d)
    local -A good=(
        [ip_forward]=0 [conf/all/accept_redirects]=0 [conf/all/send_redirects]=0
        [conf/all/rp_filter]=1 [tcp_syncookies]=1 [conf/all/log_martians]=1
        [conf/all/accept_source_route]=0 [icmp_echo_ignore_broadcasts]=1
    )
    local -A bad=(
        [ip_forward]=1 [conf/all/accept_redirects]=1 [conf/all/send_redirects]=1
        [conf/all/rp_filter]=0 [tcp_syncookies]=0 [conf/all/log_martians]=0
        [conf/all/accept_source_route]=1 [icmp_echo_ignore_broadcasts]=0
    )
    local k
    for k in "${!good[@]}"; do
        mkdir -p "$(dirname "$r/proc/sys/net/ipv4/$k")"
        if [[ "$1" == good ]]; then v="${good[$k]}"; else v="${bad[$k]}"; fi
        printf '%s\n' "$v" > "$r/proc/sys/net/ipv4/$k"
    done
    echo "$r"
}

_run() { AUDIT_ROOT="$1"; audit_run_all network; }

test_sysctl_good() {
    local r id
    r=$(_sysctl_tree good)
    _run "$r"
    for id in NET-002 NET-003 NET-004 NET-005 NET-006 NET-007 NET-008 NET-009; do
        assert_eq PASS "${AUDIT_STATUS[$id]}" "$id"
    done
    rm -rf "$r"
}

test_sysctl_bad() {
    local r id
    r=$(_sysctl_tree bad)
    _run "$r"
    for id in NET-002 NET-003 NET-004 NET-005 NET-006 NET-007 NET-008 NET-009; do
        assert_eq FAIL "${AUDIT_STATUS[$id]}" "$id"
    done
    assert_contains "${AUDIT_DETAIL[NET-003]}" "net.ipv4.conf.all.accept_redirects = 1"
    rm -rf "$r"
}

test_sysctl_missing_is_skip() {
    local r
    r=$(mktemp -d)
    _run "$r"
    assert_eq SKIP "${AUDIT_STATUS[NET-006]}"
    assert_contains "${AUDIT_DETAIL[NET-006]}" "net.ipv4.tcp_syncookies"
    rm -rf "$r"
}

test_docker_makes_forward_na() {
    local r
    r=$(_sysctl_tree bad)
    audit_have() { [[ "$1" == docker ]]; }
    _run "$r"
    assert_eq NA "${AUDIT_STATUS[NET-002]}"
    rm -rf "$r"
}

test_firewall_ufw_active() {
    audit_have() { [[ "$1" == ufw ]]; }
    audit_cmd_ufw_status() { printf 'Status: active\n'; }
    _run "$(mktemp -d)"
    assert_eq PASS "${AUDIT_STATUS[NET-001]}"
}

test_firewall_ufw_inactive() {
    audit_have() { [[ "$1" == ufw ]]; }
    audit_cmd_ufw_status() { printf 'Status: inactive\n'; }
    _run "$(mktemp -d)"
    assert_eq FAIL "${AUDIT_STATUS[NET-001]}"
}

test_firewall_no_tools_fails() {
    _run "$(mktemp -d)"
    assert_eq FAIL "${AUDIT_STATUS[NET-001]}"
}

test_firewall_nft_policy_drop() {
    audit_have() { [[ "$1" == nft ]]; }
    audit_cmd_nft_ruleset() { printf 'table inet filter {\n chain input {\n  type filter hook input priority 0; policy drop;\n }\n}\n'; }
    _run "$(mktemp -d)"
    assert_eq PASS "${AUDIT_STATUS[NET-001]}"
}

test_firewall_no_root_is_skip() {
    audit_have() { [[ "$1" == nft || "$1" == iptables ]]; }
    audit_is_root() { return 1; }
    audit_cmd_nft_ruleset() { return 1; }
    audit_cmd_iptables_rules() { return 1; }
    _run "$(mktemp -d)"
    assert_eq SKIP "${AUDIT_STATUS[NET-001]}"
}

test_firewall_iptables_accept_all_fails() {
    audit_have() { [[ "$1" == iptables ]]; }
    audit_cmd_iptables_rules() { printf -- '-P INPUT ACCEPT\n-P FORWARD ACCEPT\n-P OUTPUT ACCEPT\n'; }
    _run "$(mktemp -d)"
    assert_eq FAIL "${AUDIT_STATUS[NET-001]}"
}

test_insecure_listener() {
    audit_have() { [[ "$1" == ss ]]; }
    audit_cmd_ss() { printf 'tcp LISTEN 0 128 0.0.0.0:23 0.0.0.0:*\ntcp LISTEN 0 128 127.0.0.1:631 0.0.0.0:*\n'; }
    _run "$(mktemp -d)"
    assert_eq FAIL "${AUDIT_STATUS[NET-010]}"
    assert_contains "${AUDIT_DETAIL[NET-010]}" "23"
    assert_eq WARN "${AUDIT_STATUS[NET-011]}"
    assert_contains "${AUDIT_DETAIL[NET-011]}" "tcp/23"
    assert_not_contains "${AUDIT_DETAIL[NET-011]}" "631" "631 solo escucha en loopback"
}

test_exposed_listener_warns() {
    audit_have() { [[ "$1" == ss ]]; }
    audit_cmd_ss() { printf 'tcp LISTEN 0 128 0.0.0.0:22 0.0.0.0:*\ntcp LISTEN 0 128 [::]:80 [::]:*\nudp UNCONN 0 0 *:5353 *:*\n'; }
    _run "$(mktemp -d)"
    assert_eq PASS "${AUDIT_STATUS[NET-010]}"
    assert_eq WARN "${AUDIT_STATUS[NET-011]}"
    assert_contains "${AUDIT_DETAIL[NET-011]}" "tcp/22"
    assert_contains "${AUDIT_DETAIL[NET-011]}" "tcp/80"
}

test_no_ss_is_skip() {
    _run "$(mktemp -d)"
    assert_eq SKIP "${AUDIT_STATUS[NET-010]}"
    assert_eq SKIP "${AUDIT_STATUS[NET-011]}"
}
