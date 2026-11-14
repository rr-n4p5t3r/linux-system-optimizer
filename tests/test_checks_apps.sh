#!/usr/bin/env bash
# Pruebas de las revisiones de servicios y aplicaciones (checks/apps.sh)
# shellcheck disable=SC2034

source "$LSO_BASE_DIR/modules/audit/engine.sh"
source "$LSO_BASE_DIR/modules/audit/helpers.sh"
source "$LSO_BASE_DIR/modules/audit/checks/apps.sh"

audit_have() { [[ "$1" == ss || "$1" == systemctl ]]; }
LISTEN=""
audit_cmd_ss() { printf '%b' "$LISTEN"; }
ACTIVE=""
audit_cmd_systemctl_is_active() { [[ " $ACTIVE " == *" $1 "* ]]; }

_all="APP-001 APP-002 APP-003 APP-004 APP-005 APP-006 APP-007 APP-008 APP-009 APP-010 APP-011 APP-012 APP-013 APP-014 APP-015"
_run() { AUDIT_ROOT="$1"; audit_run_all apps; }

_tree() { # good|bad
    local r
    r=$(mktemp -d)
    mkdir -p "$r/etc/nginx" "$r/etc/apache2/conf-enabled" "$r/etc/php/8.3/fpm" "$r/etc/redis" "$r/etc/snmp" "$r/run" "$r/etc/docker"
    printf 'root:x:0:\ndocker:x:998:%s\n' "$([[ $1 == bad ]] && echo ana)" > "$r/etc/group"
    printf 'x' > "$r/run/docker.sock"
    if [[ "$1" == good ]]; then
        chmod 660 "$r/run/docker.sock"
        printf 'http {\n    server_tokens off;\n}\n' > "$r/etc/nginx/nginx.conf"
        printf 'ServerTokens Prod\n' > "$r/etc/apache2/conf-enabled/security.conf"
        printf 'expose_php = Off\n' > "$r/etc/php/8.3/fpm/php.ini"
        printf 'bind 127.0.0.1\nrequirepass x\n' > "$r/etc/redis/redis.conf"
        printf '/srv/nfs 10.0.0.0/24(rw,root_squash)\n' > "$r/etc/exports"
        printf 'anonymous_enable=NO\n' > "$r/etc/vsftpd.conf"
        printf 'rocommunity Xk29s 10.0.0.0/24\n' > "$r/etc/snmp/snmpd.conf"
    else
        chmod 666 "$r/run/docker.sock"
        printf 'http {\n}\n' > "$r/etc/nginx/nginx.conf"
        printf 'ServerTokens OS\n' > "$r/etc/apache2/conf-enabled/security.conf"
        printf 'expose_php = On\n' > "$r/etc/php/8.3/fpm/php.ini"
        printf 'bind 0.0.0.0\n' > "$r/etc/redis/redis.conf"
        printf '/srv/nfs *(rw,no_root_squash)\n' > "$r/etc/exports"
        printf 'anonymous_enable=YES\n' > "$r/etc/vsftpd.conf"
        printf 'rocommunity public\n' > "$r/etc/snmp/snmpd.conf"
    fi
    echo "$r"
}

test_apps_good() {
    local r id
    r=$(_tree good)
    LISTEN='tcp LISTEN 0 128 127.0.0.1:3306 0.0.0.0:*\ntcp LISTEN 0 128 127.0.0.1:5432 0.0.0.0:*\ntcp LISTEN 0 128 127.0.0.1:6379 0.0.0.0:*\ntcp LISTEN 0 128 127.0.0.1:27017 0.0.0.0:*\ntcp LISTEN 0 128 127.0.0.1:631 0.0.0.0:*\n'
    ACTIVE=""
    _run "$r"
    for id in $_all; do
        assert_eq PASS "${AUDIT_STATUS[$id]}" "$id: ${AUDIT_DETAIL[$id]}"
    done
    rm -rf "$r"
}

test_apps_bad() {
    local r id
    r=$(_tree bad)
    LISTEN='tcp LISTEN 0 128 0.0.0.0:2375 0.0.0.0:*\ntcp LISTEN 0 128 0.0.0.0:3306 0.0.0.0:*\ntcp LISTEN 0 128 [::]:5432 [::]:*\ntcp LISTEN 0 128 0.0.0.0:6379 0.0.0.0:*\ntcp LISTEN 0 128 0.0.0.0:27017 0.0.0.0:*\ntcp LISTEN 0 128 0.0.0.0:631 0.0.0.0:*\n'
    ACTIVE="avahi-daemon"
    _run "$r"
    for id in APP-001 APP-003 APP-004 APP-005 APP-006 APP-007 APP-008 APP-009 APP-010 APP-011 APP-012 APP-013 APP-015; do
        assert_eq FAIL "${AUDIT_STATUS[$id]}" "$id: ${AUDIT_DETAIL[$id]}"
    done
    assert_eq WARN "${AUDIT_STATUS[APP-002]}" "APP-002: ${AUDIT_DETAIL[APP-002]}"
    assert_contains "${AUDIT_DETAIL[APP-002]}" "ana"
    assert_eq WARN "${AUDIT_STATUS[APP-014]}" "APP-014: ${AUDIT_DETAIL[APP-014]}"
    rm -rf "$r"
}

test_apps_absent_is_na() {
    local r id
    r=$(mktemp -d); mkdir -p "$r/etc"; printf 'root:x:0:\n' > "$r/etc/group"
    LISTEN=""; ACTIVE=""
    _run "$r"
    for id in APP-001 APP-002 APP-003 APP-004 APP-005 APP-006 APP-007 APP-008 APP-009 APP-010 APP-011 APP-012 APP-013 APP-015; do
        assert_eq NA "${AUDIT_STATUS[$id]}" "$id: ${AUDIT_DETAIL[$id]}"
    done
    rm -rf "$r"
}

test_redis_exposed_with_password_warns() {
    local r
    r=$(_tree good)
    LISTEN='tcp LISTEN 0 128 0.0.0.0:6379 0.0.0.0:*\n'
    _run "$r"
    assert_eq WARN "${AUDIT_STATUS[APP-006]}"
    rm -rf "$r"
}
