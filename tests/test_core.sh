#!/usr/bin/env bash
# Pruebas de las utilidades del núcleo (lib/, core/) corregidas para 1.0.0
# shellcheck disable=SC2034

LSO_BASE_DIR="$LSO_BASE_DIR"
source "$LSO_BASE_DIR/lib/colors.sh"
source "$LSO_BASE_DIR/lib/logger.sh"
source "$LSO_BASE_DIR/lib/utils.sh"

# --- Directorios seguros (evitar ataques con enlaces simbólicos) ---

test_safe_dir_rejects_world_writable() {
    local d
    d=$(mktemp -d); chmod 777 "$d"
    assert_status 1 lso_safe_dir "$d"
    chmod 1777 "$d"
    assert_status 1 lso_safe_dir "$d" "ni siquiera con sticky bit: otros pueden crear archivos"
    chmod 755 "$d"
    assert_status 0 lso_safe_dir "$d"
    rm -rf "$d"
}

test_safe_dir_rejects_symlink() {
    local d
    d=$(mktemp -d); mkdir "$d/real"; ln -s "$d/real" "$d/link"
    assert_status 1 lso_safe_dir "$d/link"
    rm -rf "$d"
}

test_logger_avoids_world_writable_dir() {
    local base
    base=$(mktemp -d); mkdir "$base/logs"; chmod 777 "$base/logs"
    LSO_LOG_DIR="$base/logs"
    HOME="$base/home"; XDG_STATE_HOME=""
    init_logger
    assert_not_contains "$LSO_LOG_FILE" "$base/logs/" "no debe escribir en un directorio 777"
    assert_contains "$LSO_LOG_FILE" "$base/home/.local/state/lso/logs/"
    rm -rf "$base"
}

test_logger_uses_safe_dir() {
    local base
    base=$(mktemp -d); mkdir "$base/logs"; chmod 755 "$base/logs"
    LSO_LOG_DIR="$base/logs"
    init_logger
    assert_contains "$LSO_LOG_FILE" "$base/logs/lso-"
    rm -rf "$base"
}

test_backup_avoids_world_writable_dir() {
    local base f out
    base=$(mktemp -d); mkdir "$base/backups"; chmod 777 "$base/backups"
    LSO_BASE_DIR="$base"; HOME="$base/home"; XDG_STATE_HOME=""
    f="$base/x.conf"; echo a > "$f"
    out=$(backup_file "$f" 2>/dev/null | tail -1)
    assert_not_contains "$out" "$base/backups/"
    assert_eq "a" "$(cat "$out")"
    rm -rf "$base"
}

# --- Edición de configuración sin pisar el archivo completo ---

test_set_conf_key_replaces_and_appends() {
    local f
    f=$(mktemp)
    printf '[main]\ngpgcheck=1\nproxy=http://p:3128\nmax_parallel_downloads=3\n' > "$f"
    set_conf_key "$f" max_parallel_downloads 10
    set_conf_key "$f" fastestmirror True
    assert_contains "$(cat "$f")" "proxy=http://p:3128" "conserva lo que ya había"
    assert_contains "$(cat "$f")" "max_parallel_downloads=10"
    assert_not_contains "$(cat "$f")" "max_parallel_downloads=3"
    assert_contains "$(cat "$f")" "fastestmirror=True"
    assert_eq 1 "$(grep -c '^\[main\]' "$f")"
    rm -f "$f"
}

test_set_conf_key_creates_file_with_section() {
    local d
    d=$(mktemp -d)
    set_conf_key "$d/dnf.conf" gpgcheck 1 main
    assert_eq $'[main]\ngpgcheck=1' "$(cat "$d/dnf.conf")"
    rm -rf "$d"
}

# --- Usuario real cuando se corre con sudo ---

test_target_home_uses_sudo_user() {
    SUDO_USER="$(id -un)"
    HOME=/root
    assert_eq "$(getent passwd "$(id -un)" | cut -d: -f6)" "$(lso_target_home)"
    SUDO_USER=""
    HOME=/tmp/otro
    assert_eq "/tmp/otro" "$(lso_target_home)"
}

# --- Flags de navegador en el lanzador ---

test_browser_flags_after_executable() {
    source "$LSO_BASE_DIR/modules/browser_optimizer.sh" --lib-only 2>/dev/null
    local f
    f=$(mktemp)
    printf '[Desktop Entry]\nExec=/usr/bin/google-chrome-stable %%U\nName=Chrome\n[Desktop Action new]\nExec=/usr/bin/google-chrome-stable --incognito\n' > "$f"
    browser_add_launch_flags "$f"
    browser_add_launch_flags "$f"
    assert_contains "$(cat "$f")" "Exec=/usr/bin/google-chrome-stable --enable-features=VaapiVideoDecoder,VaapiVideoEncoder --ignore-gpu-blocklist --enable-zero-copy %U"
    assert_eq 2 "$(grep -c -- '--enable-zero-copy' "$f")" "una vez por línea Exec, sin duplicar"
    assert_not_contains "$(cat "$f")" "Exec=--enable"
    rm -f "$f"
}

test_tune_dnf_conf_keeps_user_settings() {
    local d
    d=$(mktemp -d)
    LSO_BASE_DIR="$d"; HOME="$d/home"; XDG_STATE_HOME=""
    printf '[main]\ngpgcheck=1\nproxy=http://proxy:3128\nexcludepkgs=kernel*\nmax_parallel_downloads=3\n' > "$d/dnf.conf"
    lso_tune_dnf_conf "$d/dnf.conf" deltarpm >/dev/null 2>&1
    local c
    c=$(cat "$d/dnf.conf")
    assert_contains "$c" "proxy=http://proxy:3128"
    assert_contains "$c" "excludepkgs=kernel*"
    assert_contains "$c" "max_parallel_downloads=10"
    assert_contains "$c" "deltarpm=True"
    assert_contains "$c" "installonly_limit=3"
    assert_eq 1 "$(ls "$d"/backups/dnf.conf.*.bak 2>/dev/null | wc -l)" "deja backup antes de cambiar"
    rm -rf "$d"
}
