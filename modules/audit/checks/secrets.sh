#!/usr/bin/env bash
# shellcheck disable=SC2154  # variables y arreglos definidos en otros archivos del módulo
# =============================================================================
# secrets.sh — Revisiones de auditoría: credenciales expuestas
# =============================================================================
# Linux System Optimizer (LSO)
# Autor: Ricardo Rosero <rrosero2000@gmail.com>
# GitHub: https://github.com/rr-n4p5t3r
# Licencia: GPLv3
# =============================================================================
# Regla de oro: nunca se muestra el valor de un secreto, solo archivo y línea.
# Algunas revisiones son heurísticas y pueden dar falsos positivos.

# _sec_home_paths RUTA_RELATIVA… → rutas existentes (sin prefijo) en cada home
_sec_home_paths() {
    local user home rel
    while read -r user home; do
        for rel in "$@"; do
            [[ -e "$(audit_path "$home/$rel")" ]] && echo "$home/$rel"
        done
    done < <(audit_user_homes)
}

# _sec_perm_check MASCARA "qué" RUTA… → FAIL si alguna tiene bits de la máscara
_sec_perm_check() {
    local mask="$1" what="$2" p perm bad=() n=0
    shift 2
    for p in "$@"; do
        perm=$(audit_perm "$p") || continue
        n=$((n + 1))
        (( 8#$perm & 8#$mask )) && bad+=("$p ($perm)")
    done
    if (( ${#bad[@]} )); then
        audit_fail "Legibles por otros usuarios: ${bad[*]}"
    elif (( n == 0 )); then
        audit_pass "No se encontraron $what"
    else
        audit_pass "$n $what protegidos"
    fi
}

_chk_sec_001() {
    local -a keys=()
    local user home f
    while read -r user home; do
        for f in "$(audit_path "$home/.ssh")"/id_*; do
            [[ -f "$f" && "$f" != *.pub ]] && keys+=("$(audit_rel "$f")")
        done
    done < <(audit_user_homes)
    _sec_perm_check 077 "llaves SSH privadas" "${keys[@]}"
}

_chk_sec_002() {
    local user home d list
    local -a roots=(/var/www /srv /opt)
    while read -r user home; do roots+=("$home"); done < <(audit_user_homes)
    list=$(for d in "${roots[@]}"; do
        [[ -d "$(audit_path "$d")" ]] || continue
        find "$(audit_path "$d")" -xdev -maxdepth 5 -type f -perm -004 \
            \( -name '.env' -o -name '.env.*' -o -name 'credentials*.json' -o -name 'secrets.y*ml' -o -name 'wp-config.php' \) \
            ! -name '*.example' ! -name '*.sample' ! -name '*.dist' ! -name '*.template' 2>/dev/null
    done | while IFS= read -r f; do audit_rel "$f"; echo; done | audit_short_list 5)
    if [[ -n "$list" ]]; then
        audit_fail "Archivos de configuración con secretos legibles por todos: $list"
    else
        audit_pass "No hay archivos .env ni de credenciales legibles por todos"
    fi
}

_chk_sec_003() {
    local -a files
    mapfile -t files < <(_sec_home_paths .aws/credentials .config/gcloud/credentials.db \
        .config/gcloud/application_default_credentials.json .azure/accessTokens.json .azure/msal_token_cache.json)
    _sec_perm_check 044 "archivos de credenciales de nube" "${files[@]}"
}

_SEC_HIST_RE='(mysql[^|]*[[:space:]]-p[^[:space:]]|sshpass[[:space:]]+-p|PASSWORD=[^[:space:]]|PASSWD=[^[:space:]]|curl[^|]*[[:space:]](-u|--user)[[:space:]]+[^[:space:]:]+:[^[:space:]]|://[^/[:space:]:@]+:[^/[:space:]@]+@)'

_chk_sec_004() {
    local -a files
    local f hits=()
    mapfile -t files < <(_sec_home_paths .bash_history .zsh_history .history .mysql_history .psql_history)
    for f in "${files[@]}"; do
        [[ -r "$(audit_path "$f")" ]] || continue
        while IFS=: read -r line _; do
            hits+=("$f:$line")
        done < <(grep -nE "$_SEC_HIST_RE" "$(audit_path "$f")" 2>/dev/null | cut -d: -f1 | sed 's/$/:/')
    done
    if (( ${#hits[@]} )); then
        audit_warn "Posibles contraseñas en el historial: $(printf '%s\n' "${hits[@]}" | audit_short_list 5)"
    else
        audit_pass "No se encontraron contraseñas en los historiales legibles"
    fi
}

_chk_sec_005() {
    local -a files
    mapfile -t files < <(_sec_home_paths .netrc .pgpass .my.cnf)
    _sec_perm_check 077 "archivos .netrc/.pgpass/.my.cnf" "${files[@]}"
}

_chk_sec_006() {
    local f mounts
    f=$(audit_path /etc/fstab)
    [[ -r "$f" ]] || { audit_skip "No se pudo leer /etc/fstab"; return 0; }
    mounts=$(awk '!/^[[:space:]]*#/ && $4 ~ /(^|,)(password|pass)=/ {print $2}' "$f" | audit_short_list 5)
    if [[ -n "$mounts" ]]; then
        audit_fail "Contraseñas escritas en /etc/fstab para: $mounts"
    else
        audit_pass "/etc/fstab no contiene contraseñas"
    fi
}

_chk_sec_007() {
    local list
    [[ -d "$(audit_path /var/www)" ]] || { audit_na "No existe /var/www"; return 0; }
    list=$(find "$(audit_path /var/www)" -xdev -maxdepth 5 -type d -name .git 2>/dev/null \
        | while IFS= read -r f; do audit_rel "$f"; echo; done | audit_short_list 5)
    if [[ -n "$list" ]]; then
        audit_fail "Repositorios git dentro del sitio web: $list"
    else
        audit_pass "No hay repositorios .git en /var/www"
    fi
}

_chk_sec_008() {
    local -a files
    mapfile -t files < <(_sec_home_paths .kube/config .docker/config.json)
    _sec_perm_check 044 "kubeconfig/config de Docker" "${files[@]}"
}

audit_register SEC-001 high secrets "Llaves SSH privadas protegidas" _chk_sec_001 "chmod 600 ~/.ssh/id_* (excepto los .pub) && chmod 700 ~/.ssh"
audit_register SEC-002 high secrets "Archivos .env no legibles por otros" _chk_sec_002 "chmod 600 <archivo> (o 640 con el grupo del servicio que lo lee)" slow
audit_register SEC-003 critical secrets "Credenciales de nube protegidas" _chk_sec_003 "chmod 600 ~/.aws/credentials ~/.config/gcloud/* ~/.azure/* y rota las llaves si estuvieron expuestas"
audit_register SEC-004 medium secrets "Historial sin contraseñas" _chk_sec_004 "Borra esas líneas del historial (history -d <n>) y cambia las contraseñas expuestas; usa archivos de opciones o variables en vez de -p" slow
audit_register SEC-005 high secrets ".netrc, .pgpass y .my.cnf protegidos" _chk_sec_005 "chmod 600 ~/.netrc ~/.pgpass ~/.my.cnf"
audit_register SEC-006 high secrets "/etc/fstab sin contraseñas" _chk_sec_006 "Mueve usuario y contraseña a un archivo root:root 600 y usa credentials=/ruta en /etc/fstab"
audit_register SEC-007 medium secrets "Sin repositorios .git en el sitio web" _chk_sec_007 "Mueve el .git fuera de la raíz web o bloquea /.git en el servidor web (location ~ /\\.git { deny all; })"
audit_register SEC-008 medium secrets "kubeconfig y config de Docker protegidos" _chk_sec_008 "chmod 600 ~/.kube/config ~/.docker/config.json"
