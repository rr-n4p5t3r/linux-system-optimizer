#!/usr/bin/env bash
# shellcheck disable=SC2154  # variables y arreglos definidos en otros archivos del módulo
# Pruebas de perfiles y excepciones (profiles.sh, waivers.sh)
# shellcheck disable=SC2034

source "$LSO_BASE_DIR/modules/audit/engine.sh"
source "$LSO_BASE_DIR/modules/audit/helpers.sh"
source "$LSO_BASE_DIR/modules/audit/profiles.sh"
source "$LSO_BASE_DIR/modules/audit/waivers.sh"

_noop() { audit_pass "ok"; }

test_class_mapping() {
    assert_eq "desktop" "$(audit_profile_class_for laptop)"
    assert_eq "server" "$(audit_profile_class_for database)"
    assert_eq "server" "$(audit_profile_class_for docker)"
    assert_eq "desktop" "$(audit_profile_class_for gaming)"
    assert_status 1 audit_profile_class_for xyz
}

test_detect_container_wins() {
    audit_is_container() { return 0; }
    LSO_DESKTOP="gnome"
    audit_profile_resolve
    assert_eq "container" "$AUDIT_PROFILE_CLASS"
    assert_eq "detected" "$AUDIT_PROFILE_SOURCE"
    assert_eq "Contenedor" "$AUDIT_PROFILE_LABEL"
}

test_detect_desktop_and_server() {
    audit_is_container() { return 1; }
    LSO_DESKTOP="KDE"
    audit_profile_resolve
    assert_eq "desktop" "$AUDIT_PROFILE_CLASS"
    assert_eq "Escritorio" "$AUDIT_PROFILE_LABEL"
    LSO_DESKTOP="Unknown"
    audit_profile_resolve
    assert_eq "server" "$AUDIT_PROFILE_CLASS"
    assert_eq "Servidor" "$AUDIT_PROFILE_LABEL"
}

test_chosen_profile_label() {
    audit_is_container() { return 1; }
    audit_profile_resolve laptop
    assert_eq "desktop" "$AUDIT_PROFILE_CLASS"
    assert_eq "chosen" "$AUDIT_PROFILE_SOURCE"
    assert_eq "Escritorio / laptop" "$AUDIT_PROFILE_LABEL"
}

test_desktop_adjusts_severity() {
    audit_reset
    audit_register NET-001 high network "t" _noop "f"
    AUDIT_PROFILE_CLASS="desktop"
    audit_profile_apply
    assert_eq "medium" "${AUDIT_SEV[NET-001]}"
    assert_eq "high" "${AUDIT_BASE_SEV[NET-001]}"
    assert_eq "desktop:medium" "${AUDIT_ADJ[NET-001]}"
}

test_server_keeps_severity() {
    audit_reset
    audit_register NET-001 high network "t" _noop "f"
    AUDIT_PROFILE_CLASS="server"
    assert_status 0 audit_profile_apply
    audit_profile_apply
    assert_eq "high" "${AUDIT_SEV[NET-001]}"
    assert_eq "" "${AUDIT_ADJ[NET-001]}"
}

test_container_forces_na() {
    audit_reset
    audit_register NET-005 medium network "t" _noop "f"
    AUDIT_PROFILE_CLASS="container"
    audit_profile_apply
    assert_eq "Lo gestiona el host del contenedor" "${AUDIT_FORCE_NA[NET-005]}"
    assert_eq "container:na" "${AUDIT_ADJ[NET-005]}"
}

test_waivers_parse() {
    audit_reset
    audit_register NET-001 high network "t" _noop "f"
    audit_register SSH-002 high ssh "t" _noop "f"
    local tmp
    tmp=$(mktemp)
    printf '# comentario\n\nNET-001   # firewall perimetral\nSSH-002\nXXX-999 # no existe\n' > "$tmp"
    audit_load_waivers "$tmp"
    assert_eq "firewall perimetral" "${AUDIT_WAIVED[NET-001]}"
    assert_eq "Excepción sin motivo" "${AUDIT_WAIVED[SSH-002]}"
    assert_eq "XXX-999" "${AUDIT_WAIVER_UNKNOWN[*]}"
    rm -f "$tmp"
}

test_waivers_missing_file() {
    audit_reset
    assert_status 0 audit_load_waivers /no/existe
    assert_eq "0" "${#AUDIT_WAIVED[@]}"
}

test_phase3_rules() {
    audit_reset
    local id
    for id in HRD-011 HRD-012 APP-014 HRD-002 PAT-003 APP-002 FS-012 HRD-001 PAT-005; do
        audit_register "$id" medium x "t" _noop "f"
    done
    AUDIT_PROFILE_CLASS="desktop"
    audit_profile_apply
    assert_eq "No aplica a equipos personales" "${AUDIT_FORCE_NA[HRD-011]}"
    assert_eq "No aplica a equipos personales" "${AUDIT_FORCE_NA[APP-014]}"
    assert_eq "low" "${AUDIT_SEV[HRD-002]}"
    assert_eq "low" "${AUDIT_SEV[PAT-003]}"
    assert_eq "low" "${AUDIT_SEV[APP-002]}"
    audit_reset
    for id in FS-012 HRD-001 PAT-005 HRD-011; do
        audit_register "$id" medium x "t" _noop "f"
    done
    AUDIT_PROFILE_CLASS="container"
    audit_profile_apply
    assert_eq "Lo gestiona el host del contenedor" "${AUDIT_FORCE_NA[FS-012]}"
    assert_eq "Lo gestiona el host del contenedor" "${AUDIT_FORCE_NA[HRD-001]}"
    assert_eq "Lo gestiona el host del contenedor" "${AUDIT_FORCE_NA[PAT-005]}"
}
