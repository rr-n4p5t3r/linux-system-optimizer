#!/usr/bin/env bash
# =============================================================================
# hardening.sh — Revisiones de auditoría: endurecimiento del sistema
# =============================================================================
# Linux System Optimizer (LSO)
# Autor: Ricardo Rosero <rrosero2000@gmail.com>
# GitHub: https://github.com/rr-n4p5t3r
# Licencia: GPLv3
# =============================================================================

_chk_hrd_001() {
    local se aa
    se=$(audit_path /sys/fs/selinux/enforce)
    if [[ -r "$se" ]]; then
        if [[ "$(tr -d '[:space:]' < "$se")" == 1 ]]; then
            audit_pass "SELinux en modo enforcing"
        else
            audit_fail "SELinux en modo permissive (no bloquea nada)"
        fi
        return 0
    fi
    aa=$(audit_path /sys/module/apparmor/parameters/enabled)
    if [[ -r "$aa" && "$(tr -d '[:space:]' < "$aa")" == Y ]]; then
        local prof
        prof=$(audit_path /sys/kernel/security/apparmor/profiles)
        if [[ -r "$prof" && ! -s "$prof" ]]; then
            audit_fail "AppArmor activo pero sin perfiles cargados"
        else
            audit_pass "AppArmor activo"
        fi
        return 0
    fi
    audit_fail "Sin MAC activo (ni SELinux ni AppArmor)"
}

# _hrd_service "descripción" SERVICIO…
_hrd_service() {
    local what="$1" rc=0
    shift
    audit_service_active "$@" || rc=$?
    case $rc in
        0) audit_pass "$what en ejecución" ;;
        2) audit_skip "No se puede consultar systemd (sin systemctl)" ;;
        *) audit_fail "$what no está en ejecución" ;;
    esac
}

_chk_hrd_002() { _hrd_service "auditd" auditd; }
_chk_hrd_003() { audit_check_sysctl kernel.randomize_va_space "2"; }
_chk_hrd_004() { _hrd_service "Sincronización horaria" systemd-timesyncd chronyd chrony ntpd ntp openntpd; }

_chk_hrd_005() {
    if [[ -d "$(audit_path /var/log/journal)" ]]; then
        audit_pass "journal persistente en /var/log/journal"
        return 0
    fi
    _hrd_service "syslog" rsyslog syslog-ng
    [[ "${AUDIT_STATUS[$AUDIT_CURRENT]:-}" == FAIL ]] && \
        AUDIT_DETAIL[$AUDIT_CURRENT]="Sin syslog ni journal persistente"
}

_chk_hrd_006() { audit_check_sysctl kernel.kptr_restrict "1 2"; }
_chk_hrd_007() { audit_check_sysctl kernel.dmesg_restrict "1"; }
_chk_hrd_008() { audit_check_sysctl kernel.yama.ptrace_scope "1 2 3"; }
_chk_hrd_009() { audit_check_sysctl kernel.unprivileged_bpf_disabled "1 2"; }

_chk_hrd_010() {
    local cfg perm
    cfg=$(audit_first_file /boot/grub/grub.cfg /boot/grub2/grub.cfg /boot/efi/EFI/*/grub.cfg /boot/loader/loader.conf) \
        || { audit_skip "No se encontró la configuración del gestor de arranque"; return 0; }
    perm=$(audit_perm "$cfg")
    if (( 8#$perm & 8#022 )); then
        audit_fail "$cfg tiene permisos $perm (modificable por otros)"
    elif (( 8#$perm & 8#044 )); then
        audit_warn "$cfg legible por otros usuarios ($perm)"
    else
        audit_pass "$cfg con permisos $perm"
    fi
}

_chk_hrd_011() {
    local f
    f=$(audit_path /etc/issue.net)
    if [[ -r "$f" ]] && grep -qiE 'autoriz|authori[sz]|prohib|monitor' "$f"; then
        audit_pass "Banner legal configurado en /etc/issue.net"
    else
        audit_fail "/etc/issue.net no tiene un aviso legal"
    fi
}

_chk_hrd_012() {
    audit_have systemctl || { audit_skip "No se puede consultar systemd (sin systemctl)"; return 0; }
    local st
    st=$(audit_cmd_systemctl_is_enabled ctrl-alt-del.target)
    if [[ "$st" == masked ]]; then
        audit_pass "ctrl-alt-del.target enmascarado"
    else
        audit_fail "ctrl-alt-del.target está ${st:-activo}: Ctrl+Alt+Supr reinicia el equipo"
    fi
}

_chk_hrd_013() {
    local fs missing=() conf
    conf=$(cat "$(audit_path /etc/modprobe.d)"/*.conf 2>/dev/null)
    for fs in cramfs freevxfs hfs hfsplus jffs2 udf; do
        grep -qE "^[[:space:]]*(install[[:space:]]+$fs[[:space:]]+/(usr/)?bin/(true|false)|blacklist[[:space:]]+$fs)([[:space:]]|$)" <<< "$conf" \
            || missing+=("$fs")
    done
    if (( ${#missing[@]} )); then
        audit_fail "Sin deshabilitar: ${missing[*]}"
    else
        audit_pass "Sistemas de archivos poco usados deshabilitados"
    fi
}

_chk_hrd_014() {
    local f
    for f in "$(audit_path /etc/security/limits.conf)" "$(audit_path /etc/security/limits.d)"/*.conf; do
        [[ -r "$f" ]] || continue
        if grep -qE '^[[:space:]]*\*[[:space:]]+hard[[:space:]]+core[[:space:]]+0' "$f"; then
            audit_pass "Core dumps limitados en $(audit_rel "$f")"
            return 0
        fi
    done
    for f in "$(audit_path /etc/systemd/coredump.conf)" "$(audit_path /etc/systemd/coredump.conf.d)"/*.conf; do
        [[ -r "$f" ]] || continue
        if grep -qiE '^[[:space:]]*Storage[[:space:]]*=[[:space:]]*none' "$f"; then
            audit_pass "systemd-coredump con Storage=none"
            return 0
        fi
    done
    audit_fail "Los core dumps no están limitados"
}

_hrd_sysctl_fix() { printf 'sysctl -w %s=%s y agrega "%s = %s" a /etc/sysctl.d/99-lso-hardening.conf' "$1" "$2" "$1" "$2"; }

audit_register HRD-001 high hardening "MAC activo (SELinux o AppArmor)" _chk_hrd_001 "Debian/Ubuntu: apt install apparmor apparmor-profiles && systemctl enable --now apparmor · Fedora/RHEL: SELINUX=enforcing en /etc/selinux/config y reinicia"
audit_register HRD-002 medium hardening "auditd en ejecución" _chk_hrd_002 "apt install auditd (o dnf install audit) && systemctl enable --now auditd"
audit_register HRD-003 medium hardening "ASLR completo" _chk_hrd_003 "$(_hrd_sysctl_fix kernel.randomize_va_space 2)"
audit_register HRD-004 medium hardening "Sincronización horaria activa" _chk_hrd_004 "timedatectl set-ntp true (o instala y activa chrony)"
audit_register HRD-005 medium hardening "Registro de eventos persistente" _chk_hrd_005 "mkdir -p /var/log/journal && systemctl restart systemd-journald (o instala rsyslog)"
audit_register HRD-006 low hardening "kptr_restrict activo" _chk_hrd_006 "$(_hrd_sysctl_fix kernel.kptr_restrict 1)"
audit_register HRD-007 low hardening "dmesg restringido" _chk_hrd_007 "$(_hrd_sysctl_fix kernel.dmesg_restrict 1)"
audit_register HRD-008 medium hardening "ptrace restringido" _chk_hrd_008 "$(_hrd_sysctl_fix kernel.yama.ptrace_scope 1)"
audit_register HRD-009 low hardening "BPF sin privilegios desactivado" _chk_hrd_009 "$(_hrd_sysctl_fix kernel.unprivileged_bpf_disabled 1)"
audit_register HRD-010 medium hardening "Configuración de arranque protegida" _chk_hrd_010 "chown root:root /boot/grub/grub.cfg && chmod 600 /boot/grub/grub.cfg"
audit_register HRD-011 low hardening "Banner legal en accesos remotos" _chk_hrd_011 "Escribe un aviso de uso autorizado en /etc/issue.net y agrega 'Banner /etc/issue.net' a sshd_config"
audit_register HRD-012 low hardening "Ctrl+Alt+Supr no reinicia" _chk_hrd_012 "systemctl mask ctrl-alt-del.target"
audit_register HRD-013 low hardening "Sistemas de archivos poco usados deshabilitados" _chk_hrd_013 "Agrega 'install <fs> /bin/false' para cramfs, freevxfs, hfs, hfsplus, jffs2 y udf en /etc/modprobe.d/lso-hardening.conf"
audit_register HRD-014 low hardening "Core dumps limitados" _chk_hrd_014 "Agrega '* hard core 0' a /etc/security/limits.conf (o Storage=none en /etc/systemd/coredump.conf)"
