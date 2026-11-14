#!/usr/bin/env bash
# =============================================================================
# apps.sh — Revisiones de auditoría: servicios y aplicaciones
# =============================================================================
# Linux System Optimizer (LSO)
# Autor: Ricardo Rosero <rrosero2000@gmail.com>
# GitHub: https://github.com/rr-n4p5t3r
# Licencia: GPLv3
# =============================================================================
# Cada revisión queda como "no aplica" si el servicio no está instalado.

# _app_port "Servicio" PUERTO → PASS (loopback) / FAIL (expuesto) / NA (no escucha)
_app_port() {
    local name="$1" port="$2" st
    audit_have ss || { audit_skip "No está disponible el comando ss (iproute2)"; return 0; }
    st=$(audit_port_state "$port")
    case "$st" in
        none)     audit_na "$name no está escuchando" ;;
        loopback) audit_pass "$name solo escucha en loopback (puerto $port)" ;;
        *)        audit_fail "$name escucha en todas las interfaces (puerto $port)" ;;
    esac
}

_app_docker_sock() {
    local s
    for s in /run/docker.sock /var/run/docker.sock; do
        [[ -e "$(audit_path "$s")" ]] && { echo "$s"; return 0; }
    done
    return 1
}

_chk_app_001() {
    local sock perm
    sock=$(_app_docker_sock) || { audit_na "Docker no está instalado"; return 0; }
    perm=$(audit_perm "$sock")
    if (( 8#$perm & 8#002 )); then
        audit_fail "$sock escribible por todos ($perm): cualquier usuario es root"
    else
        audit_pass "$sock con permisos $perm"
    fi
}

_chk_app_002() {
    local line members
    line=$(grep -E '^docker:' "$(audit_path /etc/group)" 2>/dev/null)
    [[ -n "$line" ]] || { audit_na "No existe el grupo docker"; return 0; }
    members="${line##*:}"
    if [[ -n "$members" ]]; then
        audit_warn "Usuarios con acceso equivalente a root vía docker: ${members//,/, }"
    else
        audit_pass "El grupo docker no tiene miembros"
    fi
}

_chk_app_003() {
    local conf
    conf=$(audit_path /etc/docker/daemon.json)
    if [[ -r "$conf" ]] && grep -qE '"tcp://' "$conf" && ! grep -qE '"tlsverify"[[:space:]]*:[[:space:]]*true' "$conf"; then
        audit_fail "daemon.json expone la API por TCP sin tlsverify"
        return 0
    fi
    if audit_have ss && [[ "$(audit_port_state 2375)" == exposed ]]; then
        audit_fail "API de Docker sin TLS escuchando en el puerto 2375"
        return 0
    fi
    if ! _app_docker_sock >/dev/null && [[ ! -e "$conf" ]]; then
        audit_na "Docker no está instalado"
        return 0
    fi
    audit_pass "La API de Docker no está expuesta sin TLS"
}

_chk_app_004() { _app_port "MySQL/MariaDB" 3306; }
_chk_app_005() { _app_port "PostgreSQL" 5432; }

_chk_app_006() {
    audit_have ss || { audit_skip "No está disponible el comando ss (iproute2)"; return 0; }
    local st conf
    st=$(audit_port_state 6379)
    case "$st" in
        none) audit_na "Redis no está escuchando"; return 0 ;;
        loopback) audit_pass "Redis solo escucha en loopback"; return 0 ;;
    esac
    conf=$(audit_first_file /etc/redis/redis.conf /etc/redis.conf /etc/redis/6379.conf) || conf=""
    if [[ -n "$conf" ]] && grep -qE '^[[:space:]]*requirepass[[:space:]]+[^[:space:]]' "$(audit_path "$conf")"; then
        audit_warn "Redis expuesto en la red (con contraseña)"
    else
        audit_fail "Redis expuesto en la red sin contraseña"
    fi
}

_chk_app_007() { _app_port "MongoDB" 27017; }

_chk_app_008() {
    local d
    d=$(audit_path /etc/nginx)
    [[ -e "$d/nginx.conf" ]] || { audit_na "nginx no está instalado"; return 0; }
    if grep -rqsE '^[[:space:]]*server_tokens[[:space:]]+off' "$d"; then
        audit_pass "server_tokens off"
    else
        audit_fail "nginx muestra su versión (falta server_tokens off)"
    fi
}

_chk_app_009() {
    local f found=0
    for f in /etc/apache2/conf-enabled/security.conf /etc/apache2/apache2.conf /etc/httpd/conf/httpd.conf /etc/httpd/conf.d/*.conf; do
        for f in $(audit_path "$f"); do
            [[ -r "$f" ]] || continue
            found=1
            grep -qiE '^[[:space:]]*ServerTokens[[:space:]]+(Prod|ProductOnly)' "$f" && { audit_pass "ServerTokens Prod"; return 0; }
        done
    done
    (( found )) || { audit_na "Apache no está instalado"; return 0; }
    audit_fail "Apache muestra versión y sistema (falta ServerTokens Prod)"
}

_chk_app_010() {
    local f bad=() n=0
    for f in "$(audit_path /etc/php.ini)" "$(audit_path /etc/php)"/*/*/php.ini; do
        [[ -r "$f" ]] || continue
        n=$((n + 1))
        grep -qiE '^[[:space:]]*expose_php[[:space:]]*=[[:space:]]*(off|0|false)' "$f" || bad+=("$(audit_rel "$f")")
    done
    if (( n == 0 )); then
        audit_na "PHP no está instalado"
    elif (( ${#bad[@]} )); then
        audit_fail "expose_php activo en: ${bad[*]}"
    else
        audit_pass "expose_php = Off"
    fi
}

_chk_app_011() {
    local f lines
    f=$(audit_path /etc/exports)
    [[ -r "$f" ]] && grep -qvE '^[[:space:]]*(#|$)' "$f" || { audit_na "No hay exportaciones NFS"; return 0; }
    lines=$(grep -vE '^[[:space:]]*#' "$f" | grep 'no_root_squash' | awk '{print $1}' | audit_short_list 5)
    if [[ -n "$lines" ]]; then
        audit_fail "Exportaciones con no_root_squash: $lines"
    else
        audit_pass "Ninguna exportación usa no_root_squash"
    fi
}

_chk_app_012() {
    local f
    f=$(audit_first_file /etc/vsftpd.conf /etc/vsftpd/vsftpd.conf) || { audit_na "vsftpd no está instalado"; return 0; }
    if grep -qiE '^[[:space:]]*anonymous_enable[[:space:]]*=[[:space:]]*YES' "$(audit_path "$f")"; then
        audit_fail "vsftpd permite acceso anónimo"
    else
        audit_pass "vsftpd sin acceso anónimo"
    fi
}

_chk_app_013() {
    local f
    f=$(audit_path /etc/snmp/snmpd.conf)
    [[ -r "$f" ]] || { audit_na "snmpd no está instalado"; return 0; }
    if grep -qiE '^[[:space:]]*(r[ow]community6?|com2sec6?[[:space:]]+[^[:space:]]+[[:space:]]+[^[:space:]]+)[[:space:]]+(public|private)([[:space:]]|$)' "$f"; then
        audit_fail "SNMP usa una comunidad por defecto (public/private)"
    else
        audit_pass "SNMP sin comunidades por defecto"
    fi
}

_chk_app_014() {
    local rc=0
    audit_service_active avahi-daemon || rc=$?
    case $rc in
        0) audit_warn "avahi-daemon anuncia el equipo en la red local" ;;
        2) audit_skip "No se puede consultar systemd (sin systemctl)" ;;
        *) audit_pass "avahi-daemon no está en ejecución" ;;
    esac
}

_chk_app_015() { _app_port "CUPS" 631; }

audit_register APP-001 high apps "Socket de Docker protegido" _chk_app_001 "chmod 660 /run/docker.sock && chown root:docker /run/docker.sock"
audit_register APP-002 medium apps "Grupo docker controlado" _chk_app_002 "Quita a quien no lo necesite: gpasswd -d <usuario> docker (o usa Docker rootless)"
audit_register APP-003 critical apps "API de Docker sin TLS no expuesta" _chk_app_003 "Quita tcp:// de 'hosts' en /etc/docker/daemon.json o configura tlsverify con certificados"
audit_register APP-004 medium apps "MySQL/MariaDB no expuesto" _chk_app_004 "bind-address = 127.0.0.1 en la configuración de mysqld (o filtra el puerto 3306 con el firewall)"
audit_register APP-005 medium apps "PostgreSQL no expuesto" _chk_app_005 "listen_addresses = 'localhost' en postgresql.conf (o filtra el puerto 5432 con el firewall)"
audit_register APP-006 high apps "Redis no expuesto sin contraseña" _chk_app_006 "bind 127.0.0.1 -::1 y requirepass <clave> en redis.conf; activa protected-mode yes"
audit_register APP-007 high apps "MongoDB no expuesto" _chk_app_007 "net.bindIp: 127.0.0.1 y security.authorization: enabled en /etc/mongod.conf"
audit_register APP-008 low apps "nginx sin versión visible" _chk_app_008 "Agrega 'server_tokens off;' en el bloque http de /etc/nginx/nginx.conf"
audit_register APP-009 low apps "Apache sin versión visible" _chk_app_009 "ServerTokens Prod y ServerSignature Off en la configuración de Apache"
audit_register APP-010 low apps "PHP sin versión visible" _chk_app_010 "expose_php = Off en cada php.ini"
audit_register APP-011 high apps "NFS sin no_root_squash" _chk_app_011 "Cambia no_root_squash por root_squash en /etc/exports y ejecuta exportfs -ra"
audit_register APP-012 high apps "FTP sin acceso anónimo" _chk_app_012 "anonymous_enable=NO en vsftpd.conf y reinicia vsftpd"
audit_register APP-013 high apps "SNMP sin comunidades por defecto" _chk_app_013 "Cambia 'public'/'private' por una comunidad difícil de adivinar, o migra a SNMPv3"
audit_register APP-014 low apps "Avahi (mDNS) desactivado" _chk_app_014 "systemctl disable --now avahi-daemon avahi-daemon.socket"
audit_register APP-015 low apps "CUPS solo en loopback" _chk_app_015 "Listen localhost:631 en /etc/cups/cupsd.conf (o desinstala CUPS en servidores)"
