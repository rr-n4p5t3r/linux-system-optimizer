#!/usr/bin/env bash
# Pruebas de las revisiones de credenciales (checks/secrets.sh)
# shellcheck disable=SC2034

source "$LSO_BASE_DIR/modules/audit/engine.sh"
source "$LSO_BASE_DIR/modules/audit/helpers.sh"
source "$LSO_BASE_DIR/modules/audit/checks/secrets.sh"

_base() {
    local r h
    r=$(mktemp -d); h="$r/home/ana"
    mkdir -p "$r/etc" "$h/.ssh" "$h/.aws" "$h/.kube" "$h/proj" "$r/var/www/site"
    printf 'root:x:0:0::/root:/bin/bash\nana:x:1000:1000::/home/ana:/bin/bash\n' > "$r/etc/passwd"
    printf 'UUID=1 / ext4 defaults 0 1\n//nas/share /mnt/nas cifs credentials=/root/.smb,uid=1000 0 0\n' > "$r/etc/fstab"
    printf 'k\n' > "$h/.ssh/id_ed25519"; chmod 600 "$h/.ssh/id_ed25519"
    printf 'k\n' > "$h/.ssh/id_ed25519.pub"; chmod 644 "$h/.ssh/id_ed25519.pub"
    printf '[default]\n' > "$h/.aws/credentials"; chmod 600 "$h/.aws/credentials"
    printf 'k\n' > "$h/.kube/config"; chmod 600 "$h/.kube/config"
    printf 'DB_PASS=x\n' > "$h/proj/.env"; chmod 600 "$h/proj/.env"
    printf 'EXAMPLE=1\n' > "$h/proj/.env.example"; chmod 644 "$h/proj/.env.example"
    printf 'h:5432:*:u:p\n' > "$h/.pgpass"; chmod 600 "$h/.pgpass"
    printf 'ls\ncd /tmp\n' > "$h/.bash_history"
    echo "$r"
}

_run() { AUDIT_ROOT="$1"; audit_run_all secrets; }
_all="SEC-001 SEC-002 SEC-003 SEC-004 SEC-005 SEC-006 SEC-007 SEC-008"

test_secrets_clean() {
    local r id
    r=$(_base); _run "$r"
    for id in $_all; do
        assert_eq PASS "${AUDIT_STATUS[$id]}" "$id: ${AUDIT_DETAIL[$id]}"
    done
    rm -rf "$r"
}

test_secrets_exposed() {
    local r h id
    r=$(_base); h="$r/home/ana"
    chmod 644 "$h/.ssh/id_ed25519" "$h/.aws/credentials" "$h/.kube/config" "$h/proj/.env" "$h/.pgpass"
    printf 'ls\nmysql -u root -pSuperSecreta123 db\nsshpass -p otra ssh x\n' > "$h/.bash_history"
    printf '//nas/share /mnt/nas cifs username=u,password=Secreta 0 0\n' >> "$r/etc/fstab"
    mkdir -p "$r/var/www/site/.git"
    _run "$r"
    for id in SEC-001 SEC-002 SEC-003 SEC-005 SEC-006 SEC-007 SEC-008; do
        assert_eq FAIL "${AUDIT_STATUS[$id]}" "$id: ${AUDIT_DETAIL[$id]}"
    done
    assert_eq WARN "${AUDIT_STATUS[SEC-004]}" "SEC-004: ${AUDIT_DETAIL[SEC-004]}"
    assert_contains "${AUDIT_DETAIL[SEC-004]}" "/home/ana/.bash_history:2"
    local all_details=""
    for id in $_all; do all_details+="${AUDIT_DETAIL[$id]} "; done
    assert_not_contains "$all_details" "SuperSecreta123" "nunca mostrar el secreto"
    assert_not_contains "$all_details" "Secreta 0" "nunca mostrar el secreto del fstab"
    assert_contains "${AUDIT_DETAIL[SEC-002]}" "/home/ana/proj/.env"
    assert_not_contains "${AUDIT_DETAIL[SEC-002]}" ".env.example"
    assert_contains "${AUDIT_DETAIL[SEC-006]}" "/mnt/nas"
    rm -rf "$r"
}

test_secrets_slow_flags() {
    assert_eq 1 "${AUDIT_SLOW[SEC-002]}"
    assert_eq 1 "${AUDIT_SLOW[SEC-004]}"
}
