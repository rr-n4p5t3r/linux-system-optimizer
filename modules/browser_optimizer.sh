#!/usr/bin/env bash
# =============================================================================
# browser_optimizer.sh — Optimización de navegadores
# =============================================================================
# Linux System Optimizer (LSO)
# Autor: Ricardo Rosero <rrosero2000@gmail.com>
# GitHub: https://github.com/rr-n4p5t3r
# Licencia: GPLv3
# =============================================================================
# Trabaja sobre el home del usuario real (con sudo, $HOME sería /root) y es
# idempotente: correrlo varias veces no duplica ajustes.

LSO_CHROMIUM_FLAGS="--enable-features=VaapiVideoDecoder,VaapiVideoEncoder --ignore-gpu-blocklist --enable-zero-copy"
LSO_FIREFOX_MARK="// LSO Optimizations"

optimize_browsers() {
    print_header "OPTIMIZACIÓN DE NAVEGADORES"

    if [[ ${#LSO_BROWSERS[@]} -eq 0 ]]; then
        print_info "No se detectaron navegadores"
        return 0
    fi

    local browser
    for browser in "${LSO_BROWSERS[@]}"; do
        print_step "Optimizando $browser..."

        case "$browser" in
            firefox|librewolf|waterfox)
                optimize_firefox "$browser"
                ;;
            google-chrome|chromium|chromium-browser|brave|brave-browser|opera|vivaldi)
                optimize_chromium "$browser"
                ;;
        esac
    done

    print_success "Navegadores optimizados"
}

# Devuelve la propiedad del archivo al usuario real si LSO corre con sudo.
_browser_give_back() {
    [[ "${EUID:-$(id -u)}" -eq 0 && -n "${SUDO_USER:-}" ]] || return 0
    chown "$(lso_target_user):" "$1" 2>/dev/null || true
}

optimize_firefox() {
    local browser="$1" home profile_dir userjs
    home=$(lso_target_home)
    profile_dir=$(find "$home/.mozilla/$browser" -maxdepth 1 -name "*.default*" -type d 2>/dev/null | head -1)

    if [[ -z "$profile_dir" ]]; then
        log_warn "Perfil de $browser no encontrado"
        return
    fi

    userjs="${profile_dir}/user.js"

    if [[ "$LSO_DRY_RUN" == "true" ]]; then
        print_info "[DRY-RUN] Se optimizaría $browser"
        return
    fi
    if grep -qF "$LSO_FIREFOX_MARK" "$userjs" 2>/dev/null; then
        print_info "$browser ya tenía los ajustes de LSO"
        return
    fi
    cat >> "$userjs" 2>/dev/null << FIREFOXEOF
${LSO_FIREFOX_MARK}
user_pref("browser.sessionstore.interval", 300000);
user_pref("browser.cache.disk.enable", true);
user_pref("browser.cache.disk.capacity", 1048576);
user_pref("browser.cache.memory.capacity", 65536);
user_pref("browser.tabs.firefox-view", false);
user_pref("browser.ping-centre.telemetry", false);
user_pref("toolkit.telemetry.enabled", false);
user_pref("toolkit.telemetry.unified", false);
user_pref("datareporting.healthreport.uploadEnabled", false);
user_pref("dom.ipc.processCount", 8);
FIREFOXEOF
    _browser_give_back "$userjs"
    log_success "$browser optimizado"
}

# browser_add_launch_flags ARCHIVO.desktop → agrega las flags después del
# ejecutable en cada línea Exec= (sin duplicarlas).
browser_add_launch_flags() {
    local file="$1"
    grep -qF -- "--enable-zero-copy" "$file" 2>/dev/null && return 0
    sed -i -E "s|^(Exec=[^ ]+)|\\1 ${LSO_CHROMIUM_FLAGS}|" "$file"
}

optimize_chromium() {
    local browser="$1" home config_dir=""
    home=$(lso_target_home)

    case "$browser" in
        google-chrome) config_dir="$home/.config/google-chrome" ;;
        chromium|chromium-browser) config_dir="$home/.config/chromium" ;;
        brave|brave-browser) config_dir="$home/.config/BraveSoftware/Brave-Browser" ;;
        opera) config_dir="$home/.config/opera" ;;
        vivaldi) config_dir="$home/.config/vivaldi" ;;
        *) config_dir="" ;;
    esac

    if [[ -z "$config_dir" ]] || [[ ! -d "$config_dir" ]]; then
        log_warn "Config de $browser no encontrada"
        return
    fi

    if [[ "$LSO_DRY_RUN" != "true" ]]; then
        # Flags de lanzamiento para mejor rendimiento
        local desktop_file="$home/.local/share/applications/${browser}.desktop"
        if [[ -f "$desktop_file" ]]; then
            browser_add_launch_flags "$desktop_file" 2>/dev/null || true
            _browser_give_back "$desktop_file"
        fi

        log_success "$browser optimizado"
    else
        print_info "[DRY-RUN] Se optimizaría $browser"
    fi
}

# "--lib-only" permite cargar las funciones sin ejecutar (pruebas).
[[ "${1:-}" == "--lib-only" ]] || optimize_browsers
