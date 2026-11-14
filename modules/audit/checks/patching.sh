#!/usr/bin/env bash
# shellcheck disable=SC2154  # variables y arreglos definidos en otros archivos del módulo
# =============================================================================
# patching.sh — Revisiones de auditoría: actualizaciones del sistema
# =============================================================================
# Linux System Optimizer (LSO)
# Autor: Ricardo Rosero <rrosero2000@gmail.com>
# GitHub: https://github.com/rr-n4p5t3r
# Licencia: GPLv3
# =============================================================================
# Solo consulta: nunca actualiza índices ni instala nada.

_chk_pat_001() {
    local pm n
    pm=$(audit_pkg_manager)
    case "$pm" in
        apt)    n=$(audit_cmd_apt_upgrade_sim | grep -E '^Inst ' | grep -c -- '-security') ;;
        dnf)    n=$(audit_cmd_dnf_security | grep -cE '[Ss]ec') ;;
        zypper) n=$(audit_cmd_zypper_security | grep -cE '\|[[:space:]]*security[[:space:]]*\|') ;;
        pacman) audit_na "pacman no distingue actualizaciones de seguridad"; return 0 ;;
        *)      audit_na "Gestor de paquetes no soportado"; return 0 ;;
    esac
    if (( n > 0 )); then
        audit_fail "$n actualización(es) de seguridad pendientes ($pm)"
    else
        audit_pass "Sin actualizaciones de seguridad pendientes ($pm)"
    fi
}

_chk_pat_002() {
    local pm p days=""
    pm=$(audit_pkg_manager)
    local -a stamps
    case "$pm" in
        apt)    stamps=(/var/lib/apt/periodic/update-success-stamp /var/lib/apt/lists) ;;
        dnf)    stamps=(/var/cache/dnf /var/cache/libdnf5) ;;
        zypper) stamps=(/var/cache/zypp/raw) ;;
        pacman) stamps=(/var/lib/pacman/sync) ;;
        *)      audit_na "Gestor de paquetes no soportado"; return 0 ;;
    esac
    for p in "${stamps[@]}"; do
        days=$(audit_age_days "$p") && break
    done
    if [[ -z "$days" ]]; then
        audit_skip "No se encontró la fecha de la última actualización del índice"
    elif (( days <= 7 )); then
        audit_pass "Índice de paquetes actualizado hace $days día(s)"
    else
        audit_fail "Índice de paquetes sin actualizar hace $days días"
    fi
}

_chk_pat_003() {
    local pm t
    pm=$(audit_pkg_manager)
    case "$pm" in
        apt)
            if grep -qsE 'APT::Periodic::Unattended-Upgrade[[:space:]]+"1"' "$(audit_path /etc/apt/apt.conf.d)"/* \
                && [[ -e "$(audit_path /usr/bin/unattended-upgrade)" ]]; then
                audit_pass "unattended-upgrades activo"
            else
                audit_fail "unattended-upgrades no está activo"
            fi
            ;;
        dnf)
            for t in dnf-automatic.timer dnf-automatic-install.timer dnf5-automatic.timer; do
                if [[ "$(audit_cmd_systemctl_is_enabled "$t")" == enabled ]]; then
                    audit_pass "$t activo"
                    return 0
                fi
            done
            audit_fail "dnf-automatic no está activo"
            ;;
        *) audit_na "Sin mecanismo estándar de actualizaciones automáticas para ${pm:-este sistema}" ;;
    esac
}

_chk_pat_004() {
    local pm f pkgs
    pm=$(audit_pkg_manager)
    for f in /run/reboot-required /var/run/reboot-required; do
        if [[ -e "$(audit_path "$f")" ]]; then
            pkgs=$(audit_short_list 3 < "$(audit_path "$f.pkgs")" 2>/dev/null)
            audit_fail "Reinicio pendiente${pkgs:+ por: $pkgs}"
            return 0
        fi
    done
    if [[ "$pm" == dnf ]]; then
        audit_have needs-restarting || { audit_skip "Falta needs-restarting (dnf-utils)"; return 0; }
        audit_cmd_needs_restarting || { audit_fail "Reinicio pendiente (needs-restarting -r)"; return 0; }
    elif [[ "$pm" != apt ]]; then
        audit_na "No disponible para ${pm:-este sistema}; ver PAT-005"
        return 0
    fi
    audit_pass "No hay reinicio pendiente"
}

_chk_pat_005() {
    local running newest
    running=$(audit_cmd_uname_r)
    newest=$(find "$(audit_path /boot)" -maxdepth 1 -name 'vmlinuz-[0-9]*' 2>/dev/null \
        | sed 's|.*/vmlinuz-||' | sort -V | tail -1)
    if [[ -z "$newest" ]]; then
        audit_skip "No se pudieron comparar las versiones del kernel en /boot"
    elif [[ "$running" == "$newest" ]]; then
        audit_pass "Kernel en ejecución $running (el más reciente)"
    else
        audit_fail "Kernel en ejecución $running; instalado más reciente: $newest"
    fi
}

_chk_pat_006() {
    local f hits=()
    for f in "$(audit_path /etc/apt/sources.list)" "$(audit_path /etc/apt/sources.list.d)"/*; do
        [[ -r "$f" ]] || continue
        grep -qiE '^[^#]*(trusted=yes|allow-insecure=yes|Trusted:[[:space:]]*yes)' "$f" && hits+=("$(audit_rel "$f")")
    done
    for f in "$(audit_path /etc/yum.repos.d)"/*.repo "$(audit_path /etc/zypp/repos.d)"/*.repo "$(audit_path /etc/dnf/dnf.conf)"; do
        [[ -r "$f" ]] || continue
        grep -qE '^[[:space:]]*(gpgcheck|repo_gpgcheck)[[:space:]]*=[[:space:]]*(0|false|no)' "$f" && hits+=("$(audit_rel "$f")")
    done
    f=$(audit_path /etc/pacman.conf)
    [[ -r "$f" ]] && grep -qE '^[[:space:]]*SigLevel[[:space:]]*=[[:space:]]*Never' "$f" && hits+=("/etc/pacman.conf")
    if (( ${#hits[@]} )); then
        audit_fail "Repositorios sin verificación de firma: ${hits[*]}"
    else
        audit_pass "Todos los repositorios verifican firmas"
    fi
}

audit_register PAT-001 high patching "Sin actualizaciones de seguridad pendientes" _chk_pat_001 "apt upgrade · dnf upgrade --security · zypper patch --category security" slow
audit_register PAT-002 medium patching "Índice de paquetes reciente" _chk_pat_002 "apt update · dnf makecache · zypper refresh · pacman -Sy (o activa la actualización automática del índice)"
audit_register PAT-003 medium patching "Actualizaciones automáticas de seguridad" _chk_pat_003 "Debian/Ubuntu: apt install unattended-upgrades && dpkg-reconfigure -plow unattended-upgrades · Fedora/RHEL: dnf install dnf-automatic && systemctl enable --now dnf-automatic-install.timer"
audit_register PAT-004 medium patching "Sin reinicio pendiente" _chk_pat_004 "Programa un reinicio para aplicar las actualizaciones"
audit_register PAT-005 medium patching "Kernel en ejecución actualizado" _chk_pat_005 "Reinicia para usar el kernel más reciente instalado"
audit_register PAT-006 high patching "Repositorios con verificación de firma" _chk_pat_006 "Quita trusted=yes / allow-insecure=yes de las fuentes APT, o pon gpgcheck=1 en los .repo"
