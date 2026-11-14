#!/usr/bin/env bash
# =============================================================================
# filesystem.sh — Revisiones de auditoría: sistema de archivos
# =============================================================================
# Linux System Optimizer (LSO)
# Autor: Ricardo Rosero <rrosero2000@gmail.com>
# GitHub: https://github.com/rr-n4p5t3r
# Licencia: GPLv3
# =============================================================================

# _fs_mount_has PUNTO OPCION… → PASS/FAIL según las opciones del montaje
_fs_mount_has() {
    local mp="$1" opts o missing=()
    shift
    if ! opts=$(audit_mount_opts "$mp"); then
        audit_fail "$mp no es un montaje propio (hereda las opciones de /)"
        return 0
    fi
    for o in "$@"; do
        [[ ",$opts," == *",$o,"* ]] || missing+=("$o")
    done
    if (( ${#missing[@]} )); then
        audit_fail "$mp sin: ${missing[*]}"
    else
        audit_pass "$mp montado con ${*}"
    fi
}

_chk_fs_001() { _fs_mount_has /tmp nodev nosuid; }
_chk_fs_002() { _fs_mount_has /var/tmp nodev nosuid; }
_chk_fs_003() { _fs_mount_has /dev/shm nodev nosuid noexec; }

_chk_fs_004() {
    local list
    list=$(find "$(audit_path /etc)" -xdev -type f -perm -0002 2>/dev/null \
        | while read -r f; do audit_rel "$f"; echo; done | audit_short_list 5)
    if [[ -n "$list" ]]; then
        audit_fail "Escribibles por todos: $list"
    else
        audit_pass "Ningún archivo de /etc es escribible por todos"
    fi
}

_chk_fs_005() {
    local list
    audit_disk_scan_ensure
    list=$(audit_disk_lines W | audit_short_list 5)
    if [[ -n "$list" ]]; then
        audit_fail "Directorios escribibles por todos sin sticky bit: $list"
    else
        audit_pass "Todos los directorios escribibles por todos tienen sticky bit"
    fi
}

_chk_fs_006() {
    local perm uid
    perm=$(audit_perm /etc/gshadow) || { audit_na "No existe /etc/gshadow"; return 0; }
    uid=$(audit_owner_uid /etc/gshadow) || uid=""
    if [[ "$uid" != 0 ]]; then
        audit_fail "/etc/gshadow pertenece al UID ${uid:-?}, no a root"
    elif (( 8#$perm & 8#037 )); then
        audit_fail "/etc/gshadow tiene permisos $perm (máximo recomendado 640)"
    else
        audit_pass "/etc/gshadow con permisos $perm"
    fi
}

_chk_fs_007() {
    local perm
    perm=$(audit_perm /etc/group) || { audit_skip "No existe /etc/group"; return 0; }
    if (( 8#$perm & 8#022 )); then
        audit_fail "/etc/group tiene permisos $perm (escribible por grupo u otros)"
    else
        audit_pass "/etc/group con permisos $perm"
    fi
}

# Binarios que con SUID permiten escalar a root (lista tipo GTFOBins).
_FS_GTFO='^(find|vim?|vim\.[a-z]+|nano|less|more|awk|gawk|mawk|nawk|python[0-9.]*|perl[0-9.]*|ruby[0-9.]*|php[0-9.]*|bash|sh|dash|zsh|ksh|tcsh|csh|env|nmap|cp|mv|tar|zip|gdb|node|nodejs|lua[0-9.]*|tee|dd|rsync|socat|nc|ncat|busybox|xargs|ed|sed|tclsh|wish|expect|strace|taskset|flock|ionice|nice|time|timeout|stdbuf|docker|systemctl|journalctl|openssl)$'

_chk_fs_008() {
    local list
    audit_disk_scan_ensure
    list=$(audit_disk_lines S | while read -r f; do
        [[ "$(basename "$f")" =~ $_FS_GTFO ]] && echo "$f"
    done | audit_short_list 5)
    if [[ -n "$list" ]]; then
        audit_fail "SUID en binarios aprovechables: $list"
    else
        audit_pass "Ningún binario aprovechable para escalar tiene SUID"
    fi
}

_chk_fs_009() {
    local list
    audit_disk_scan_ensure
    list=$(audit_disk_lines U | audit_short_list 5)
    if [[ -n "$list" ]]; then
        audit_fail "Archivos sin dueño o grupo: $list"
    else
        audit_pass "Todos los archivos tienen dueño y grupo válidos"
    fi
}

_chk_fs_010() {
    local user home perm bad=() n=0
    while read -r user home; do
        [[ "$user" == root ]] && continue
        perm=$(audit_perm "$home") || continue
        n=$((n + 1))
        (( 8#$perm & 8#005 )) && bad+=("$home ($perm)")
    done < <(audit_user_homes)
    if (( n == 0 )); then
        audit_na "No hay directorios de usuario"
    elif (( ${#bad[@]} )); then
        audit_fail "Legibles por otros usuarios: ${bad[*]}"
    else
        audit_pass "$n directorios de usuario protegidos"
    fi
}

_chk_fs_011() {
    local p perm uid bad=() readable=() n=0
    for p in /etc/crontab /etc/cron.d /etc/cron.hourly /etc/cron.daily /etc/cron.weekly /etc/cron.monthly; do
        perm=$(audit_perm "$p") || continue
        n=$((n + 1))
        uid=$(audit_owner_uid "$p") || uid=""
        if [[ "$uid" != 0 ]] || (( 8#$perm & 8#022 )); then
            bad+=("$p ($perm)")
        elif (( 8#$perm & 8#004 )); then
            readable+=("$p")
        fi
    done
    if (( n == 0 )); then
        audit_na "cron no está instalado"
    elif (( ${#bad[@]} )); then
        audit_fail "Modificables por otros usuarios: ${bad[*]}"
    elif (( ${#readable[@]} )); then
        audit_warn "Legibles por todos: ${readable[*]}"
    else
        audit_pass "Configuración de cron solo accesible por root"
    fi
}

_chk_fs_012() { audit_check_sysctl fs.suid_dumpable "0"; }
_chk_fs_013() { audit_check_sysctl fs.protected_symlinks "1"; }
_chk_fs_014() { audit_check_sysctl fs.protected_hardlinks "1"; }
_chk_fs_015() { audit_check_sysctl fs.protected_fifos "1 2"; }
_chk_fs_016() { audit_check_sysctl fs.protected_regular "1 2"; }

_fs_sysctl_fix() { printf 'sysctl -w %s=%s y agrega "%s = %s" a /etc/sysctl.d/99-lso-hardening.conf' "$1" "$2" "$1" "$2"; }

audit_register FS-001 medium filesystem "/tmp con opciones seguras" _chk_fs_001 "Monta /tmp como tmpfs con nodev,nosuid: systemctl enable --now tmp.mount, o agrega a /etc/fstab: tmpfs /tmp tmpfs defaults,nodev,nosuid 0 0"
audit_register FS-002 medium filesystem "/var/tmp con opciones seguras" _chk_fs_002 "Agrega a /etc/fstab un montaje propio para /var/tmp con nodev,nosuid (o un bind de /tmp)"
audit_register FS-003 medium filesystem "/dev/shm con opciones seguras" _chk_fs_003 "En /etc/fstab: tmpfs /dev/shm tmpfs defaults,nodev,nosuid,noexec 0 0 y luego: mount -o remount /dev/shm"
audit_register FS-004 high filesystem "Sin archivos escribibles por todos en /etc" _chk_fs_004 "chmod o-w <archivo> para cada archivo listado"
audit_register FS-005 medium filesystem "Directorios compartidos con sticky bit" _chk_fs_005 "chmod +t <directorio> para cada directorio listado" slow
audit_register FS-006 high filesystem "/etc/gshadow protegido" _chk_fs_006 "chown root:shadow /etc/gshadow && chmod 640 /etc/gshadow"
audit_register FS-007 medium filesystem "/etc/group sin escritura ajena" _chk_fs_007 "chown root:root /etc/group && chmod 644 /etc/group"
audit_register FS-008 high filesystem "Sin SUID en binarios aprovechables" _chk_fs_008 "chmod u-s <binario> para cada binario listado" slow
audit_register FS-009 medium filesystem "Sin archivos sin dueño" _chk_fs_009 "Asigna dueño (chown usuario:grupo <archivo>) o elimina los archivos huérfanos" slow
audit_register FS-010 low filesystem "Homes no legibles por otros usuarios" _chk_fs_010 "chmod 750 /home/<usuario> (y DIR_MODE=0750 en /etc/adduser.conf para cuentas nuevas)"
audit_register FS-011 medium filesystem "Configuración de cron protegida" _chk_fs_011 "chown root:root /etc/crontab /etc/cron.* && chmod 600 /etc/crontab && chmod 700 /etc/cron.d /etc/cron.hourly /etc/cron.daily /etc/cron.weekly /etc/cron.monthly"
audit_register FS-012 low filesystem "Volcados de procesos SUID desactivados" _chk_fs_012 "$(_fs_sysctl_fix fs.suid_dumpable 0)"
audit_register FS-013 medium filesystem "Protección de enlaces simbólicos" _chk_fs_013 "$(_fs_sysctl_fix fs.protected_symlinks 1)"
audit_register FS-014 medium filesystem "Protección de enlaces duros" _chk_fs_014 "$(_fs_sysctl_fix fs.protected_hardlinks 1)"
audit_register FS-015 low filesystem "Protección de FIFOs en directorios compartidos" _chk_fs_015 "$(_fs_sysctl_fix fs.protected_fifos 1)"
audit_register FS-016 low filesystem "Protección de archivos en directorios compartidos" _chk_fs_016 "$(_fs_sysctl_fix fs.protected_regular 2)"
