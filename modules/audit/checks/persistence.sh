#!/usr/bin/env bash
# =============================================================================
# persistence.sh — Revisiones de auditoría: mecanismos de persistencia
# =============================================================================
# Linux System Optimizer (LSO)
# Autor: Ricardo Rosero <rrosero2000@gmail.com>
# GitHub: https://github.com/rr-n4p5t3r
# Licencia: GPLv3
# =============================================================================
# Busca señales típicas de un equipo comprometido o mal configurado:
# bibliotecas precargadas, binarios en directorios temporales, tareas que
# descargan y ejecutan código, y PAM que acepta cualquier autenticación.

_PER_TMPDIRS=(/tmp /var/tmp /dev/shm)

# _per_find_tmp ARGS… → rutas (sin prefijo) en los directorios temporales
_per_find_tmp() {
    local d
    for d in "${_PER_TMPDIRS[@]}"; do
        [[ -d "$(audit_path "$d")" ]] || continue
        find "$(audit_path "$d")" -xdev "$@" 2>/dev/null | while IFS= read -r f; do audit_rel "$f"; echo; done
    done
}

_chk_per_001() {
    local f libs
    f=$(audit_path /etc/ld.so.preload)
    [[ -e "$f" ]] || { audit_pass "No existe /etc/ld.so.preload"; return 0; }
    libs=$(grep -vE '^[[:space:]]*(#|$)' "$f" 2>/dev/null | audit_short_list 3)
    if [[ -n "$libs" ]]; then
        audit_fail "Bibliotecas precargadas en todos los procesos: $libs"
    else
        audit_pass "/etc/ld.so.preload está vacío"
    fi
}

_chk_per_002() {
    local list
    list=$(_per_find_tmp -type f \( -perm -4000 -o -perm -2000 \) | audit_short_list 5)
    if [[ -n "$list" ]]; then
        audit_fail "Archivos SUID/SGID en directorios temporales: $list"
    else
        audit_pass "Sin archivos SUID/SGID en directorios temporales"
    fi
}

_chk_per_003() {
    local list
    [[ -d "$(audit_path /dev/shm)" ]] || { audit_na "No existe /dev/shm"; return 0; }
    list=$(find "$(audit_path /dev/shm)" -xdev -type f -perm /111 2>/dev/null \
        | while IFS= read -r f; do audit_rel "$f"; echo; done | audit_short_list 5)
    if [[ -n "$list" ]]; then
        audit_fail "Ejecutables en /dev/shm: $list"
    else
        audit_pass "Sin ejecutables en /dev/shm"
    fi
}

_chk_per_004() {
    local perm
    [[ -x "$(audit_path /root)" ]] || { audit_skip "Se requiere root para revisar /root/.ssh"; return 0; }
    perm=$(audit_perm /root/.ssh/authorized_keys) || { audit_pass "root no tiene authorized_keys"; return 0; }
    if (( 8#$perm & 8#077 )); then
        audit_fail "/root/.ssh/authorized_keys tiene permisos $perm"
    else
        audit_pass "/root/.ssh/authorized_keys con permisos $perm"
    fi
}

_chk_per_005() {
    local user home f perm bad=() n=0
    while read -r user home; do
        [[ "$user" == root ]] && continue
        for f in "$home/.ssh/authorized_keys" "$home/.ssh/authorized_keys2"; do
            perm=$(audit_perm "$f") || continue
            n=$((n + 1))
            (( 8#$perm & 8#022 )) && bad+=("$f ($perm)")
        done
    done < <(audit_user_homes)
    if (( ${#bad[@]} )); then
        audit_fail "Modificables por otros usuarios: ${bad[*]}"
    elif (( n == 0 )); then
        audit_pass "Ningún usuario tiene authorized_keys"
    else
        audit_pass "$n archivos authorized_keys protegidos"
    fi
}

_PER_BAD_CMD='((curl|wget)[^|#]*\|[[:space:]]*(ba|da|z)?sh|(/tmp/|/var/tmp/|/dev/shm/))'

_chk_per_006() {
    local f hits=() unreadable=0
    for f in "$(audit_path /etc/crontab)" "$(audit_path /etc/cron.d)"/* \
             "$(audit_path /var/spool/cron/crontabs)"/* "$(audit_path /var/spool/cron)"/*; do
        [[ -f "$f" ]] || continue
        [[ -r "$f" ]] || { unreadable=1; continue; }
        grep -vE '^[[:space:]]*#' "$f" | grep -qE "$_PER_BAD_CMD" && hits+=("$(audit_rel "$f")")
    done
    [[ -d "$(audit_path /var/spool/cron/crontabs)" && ! -r "$(audit_path /var/spool/cron/crontabs)" ]] && unreadable=1
    if (( ${#hits[@]} )); then
        audit_fail "Tareas que ejecutan desde temporales o descargan y ejecutan: ${hits[*]}"
    elif (( unreadable )); then
        audit_skip "Se requiere root para leer las tareas cron de los usuarios"
    else
        audit_pass "Ninguna tarea cron sospechosa"
    fi
}

_chk_per_007() {
    local f hits=() user home
    local -a dirs=(/etc/systemd/system)
    while read -r user home; do dirs+=("$home/.config/systemd/user"); done < <(audit_user_homes)
    local d
    for d in "${dirs[@]}"; do
        [[ -d "$(audit_path "$d")" ]] || continue
        while IFS= read -r f; do
            grep -qE '^[[:space:]]*Exec[A-Za-z]*=[-@+!]*[^#]*(/tmp/|/var/tmp/|/dev/shm/)' "$f" 2>/dev/null \
                && hits+=("$(audit_rel "$f")")
        done < <(find "$(audit_path "$d")" -type f \( -name '*.service' -o -name '*.timer' \) 2>/dev/null)
    done
    if (( ${#hits[@]} )); then
        audit_fail "Unidades que ejecutan desde directorios temporales: ${hits[*]}"
    else
        audit_pass "Ninguna unidad systemd ejecuta desde directorios temporales"
    fi
}

_chk_per_008() {
    local list
    list=$(_per_find_tmp -type f -name '.*' -perm /111 | audit_short_list 5)
    if [[ -n "$list" ]]; then
        audit_warn "Ejecutables ocultos: $list"
    else
        audit_pass "Sin ejecutables ocultos en directorios temporales"
    fi
}

_chk_per_009() {
    local hits
    [[ -d "$(audit_path /etc/pam.d)" ]] || { audit_na "PAM no está instalado"; return 0; }
    hits=$(grep -lE '^[[:space:]]*auth[[:space:]]+(sufficient|\[[^]]*success=(done|ok)[^]]*\])[[:space:]]+([^[:space:]]*/)?pam_permit\.so' \
        "$(audit_path /etc/pam.d)"/* 2>/dev/null | while IFS= read -r f; do audit_rel "$f"; echo; done | audit_short_list 5)
    if [[ -n "$hits" ]]; then
        audit_fail "PAM acepta cualquier autenticación (auth sufficient pam_permit.so) en: $hits"
    else
        audit_pass "PAM no tiene atajos con pam_permit.so"
    fi
}

_chk_per_010() {
    local f perm uid bad=()
    for f in "$(audit_path /etc/profile)" "$(audit_path /etc/bash.bashrc)" "$(audit_path /etc/bashrc)" \
             "$(audit_path /etc/zsh/zshrc)" "$(audit_path /etc/environment)" "$(audit_path /etc/profile.d)"/*; do
        [[ -e "$f" ]] || continue
        f=$(audit_rel "$f")
        perm=$(audit_perm "$f") || continue
        uid=$(audit_owner_uid "$f") || uid=""
        if [[ "$uid" != 0 ]] || (( 8#$perm & 8#022 )); then
            bad+=("$f ($perm)")
        fi
    done
    if (( ${#bad[@]} )); then
        audit_fail "Modificables por usuarios que no son root: ${bad[*]}"
    else
        audit_pass "Los scripts de inicio de shell solo los modifica root"
    fi
}

_chk_per_011() {
    local f n
    f=$(audit_path /etc/rc.local)
    [[ -f "$f" ]] || { audit_pass "No existe /etc/rc.local"; return 0; }
    n=$(grep -vcE '^[[:space:]]*(#|$|exit[[:space:]]+0[[:space:]]*$)' "$f")
    if (( n > 0 )); then
        audit_warn "/etc/rc.local ejecuta $n comando(s) al arrancar; revisa que sean legítimos"
    else
        audit_pass "/etc/rc.local no ejecuta comandos"
    fi
}

audit_register PER-001 critical persistence "Sin bibliotecas precargadas globalmente" _chk_per_001 "Revisa el contenido de /etc/ld.so.preload; si no lo pusiste tú, el equipo puede estar comprometido. Vacíalo: : > /etc/ld.so.preload"
audit_register PER-002 high persistence "Sin SUID/SGID en directorios temporales" _chk_per_002 "Elimina los archivos listados e investiga cómo llegaron ahí; monta /tmp con nosuid"
audit_register PER-003 high persistence "Sin ejecutables en /dev/shm" _chk_per_003 "Revisa y elimina los ejecutables listados; monta /dev/shm con noexec"
audit_register PER-004 high persistence "authorized_keys de root protegido" _chk_per_004 "chmod 600 /root/.ssh/authorized_keys && chmod 700 /root/.ssh"
audit_register PER-005 high persistence "authorized_keys de usuarios protegidos" _chk_per_005 "chmod 600 ~usuario/.ssh/authorized_keys && chmod 700 ~usuario/.ssh"
audit_register PER-006 medium persistence "Tareas cron sin descargas ni temporales" _chk_per_006 "Revisa las tareas listadas con crontab -l -u <usuario> o en /etc/cron.d y elimina las que no reconozcas"
audit_register PER-007 medium persistence "Unidades systemd sin ejecutables temporales" _chk_per_007 "Revisa las unidades listadas (systemctl cat <unidad>) y desactívalas si no son legítimas: systemctl disable --now <unidad>"
audit_register PER-008 medium persistence "Sin ejecutables ocultos en temporales" _chk_per_008 "Revisa los archivos listados (file, sha256sum) y elimínalos si no los reconoces"
audit_register PER-009 critical persistence "PAM no acepta cualquier autenticación" _chk_per_009 "Quita la línea 'auth sufficient pam_permit.so' del archivo indicado en /etc/pam.d/ (cuidado: ten una sesión root abierta mientras lo corriges)"
audit_register PER-010 high persistence "Scripts de inicio de shell protegidos" _chk_per_010 "chown root:root <archivo> && chmod 644 <archivo>"
audit_register PER-011 medium persistence "rc.local sin comandos inesperados" _chk_per_011 "Revisa /etc/rc.local y migra lo legítimo a una unidad systemd"
