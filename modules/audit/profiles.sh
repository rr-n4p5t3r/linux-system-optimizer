#!/usr/bin/env bash
# shellcheck disable=SC2154  # variables y arreglos definidos en otros archivos del módulo
# =============================================================================
# profiles.sh — Clase de perfil de auditoría y ajustes de gravedad
# =============================================================================
# Linux System Optimizer (LSO)
# Autor: Ricardo Rosero <rrosero2000@gmail.com>
# GitHub: https://github.com/rr-n4p5t3r
# Licencia: GPLv3
# =============================================================================
# Un perfil nunca oculta una revisión: solo cambia su gravedad o la marca
# como "no aplica", y el ajuste queda registrado en AUDIT_ADJ.
# shellcheck disable=SC2034  # variables consumidas por los renderizadores

# Reglas: "clase ID gravedad|na [motivo]"
AUDIT_PROFILE_RULES=(
    "desktop SSH-002 medium"
    "desktop SSH-005 low"
    "desktop ACC-005 low"
    "desktop ACC-006 low"
    "desktop ACC-010 medium"
    "desktop NET-001 medium"
    "desktop HRD-002 low"
    "desktop PAT-003 low"
    "desktop APP-002 low"
)
for _id in HRD-011 HRD-012 APP-014; do
    AUDIT_PROFILE_RULES+=("desktop $_id na No aplica a equipos personales")
done
# En un contenedor, el kernel, el firewall, el reloj y los registros son del host.
for _id in NET-001 NET-002 NET-003 NET-004 NET-005 NET-006 NET-007 NET-008 NET-009 \
           FS-001 FS-002 FS-003 FS-012 FS-013 FS-014 FS-015 FS-016 \
           HRD-001 HRD-002 HRD-003 HRD-004 HRD-005 HRD-006 HRD-007 HRD-008 HRD-009 \
           HRD-010 HRD-011 HRD-012 HRD-013 PAT-005; do
    AUDIT_PROFILE_RULES+=("container $_id na Lo gestiona el host del contenedor")
done
unset _id

# audit_profile_class_for PERFIL_LSO → server|desktop
audit_profile_class_for() {
    case "$1" in
        server|database|docker) echo server ;;
        desktop|laptop|gaming|dev|workstation) echo desktop ;;
        *) return 1 ;;
    esac
}

# audit_profile_resolve [PERFIL_LSO]
audit_profile_resolve() {
    local chosen="${1:-}"
    if [[ -n "$chosen" ]]; then
        AUDIT_PROFILE_CLASS=$(audit_profile_class_for "$chosen") || return 1
        AUDIT_PROFILE_SOURCE="chosen"
        if [[ "$AUDIT_PROFILE_CLASS" == desktop ]]; then
            AUDIT_PROFILE_LABEL="Escritorio / $chosen"
        else
            AUDIT_PROFILE_LABEL="Servidor"
            [[ "$chosen" != server ]] && AUDIT_PROFILE_LABEL="Servidor / $chosen"
        fi
        return 0
    fi
    AUDIT_PROFILE_SOURCE="detected"
    local desk="${LSO_DESKTOP:-}"
    if audit_is_container; then
        AUDIT_PROFILE_CLASS="container"; AUDIT_PROFILE_LABEL="Contenedor"
    elif [[ -n "$desk" && "${desk,,}" != none && "${desk,,}" != unknown ]]; then
        AUDIT_PROFILE_CLASS="desktop"; AUDIT_PROFILE_LABEL="Escritorio"
    else
        AUDIT_PROFILE_CLASS="server"; AUDIT_PROFILE_LABEL="Servidor"
    fi
}

audit_profile_apply() {
    local rule cls id sev reason
    for rule in "${AUDIT_PROFILE_RULES[@]}"; do
        read -r cls id sev reason <<< "$rule"
        [[ "$cls" != "${AUDIT_PROFILE_CLASS:-}" ]] && continue
        [[ -z "${AUDIT_CAT[$id]:-}" ]] && continue
        if [[ "$sev" == na ]]; then
            AUDIT_FORCE_NA[$id]="${reason:-No aplica a este perfil}"
        else
            AUDIT_SEV[$id]="$sev"
        fi
        AUDIT_ADJ[$id]="${cls}:${sev}"
    done
    return 0
}
