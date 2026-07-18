#!/usr/bin/env bash
# browser_optimizer.sh — Optimización de navegadores
optimize_browsers() {
    print_header "OPTIMIZACIÓN DE NAVEGADORES"

    if [[ ${#LSO_BROWSERS[@]} -eq 0 ]]; then
        print_info "No se detectaron navegadores"
        return 0
    fi

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

optimize_firefox() {
    local browser="$1"
    local profile_dir
    profile_dir=$(find "$HOME/.mozilla/$browser" -maxdepth 1 -name "*.default*" -type d 2>/dev/null | head -1)

    if [[ -z "$profile_dir" ]]; then
        log_warn "Perfil de $browser no encontrado"
        return
    fi

    local prefs="${profile_dir}/prefs.js"
    local userjs="${profile_dir}/user.js"

    if [[ "$LSO_DRY_RUN" != "true" ]]; then
        cat >> "$userjs" 2>/dev/null << 'FIREFOXEOF'
// LSO Optimizations
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
        log_success "$browser optimizado"
    else
        print_info "[DRY-RUN] Se optimizaría $browser"
    fi
}

optimize_chromium() {
    local browser="$1"
    local config_dir

    case "$browser" in
        google-chrome) config_dir="$HOME/.config/google-chrome" ;;
        chromium|chromium-browser) config_dir="$HOME/.config/chromium" ;;
        brave|brave-browser) config_dir="$HOME/.config/BraveSoftware/Brave-Browser" ;;
        opera) config_dir="$HOME/.config/opera" ;;
        vivaldi) config_dir="$HOME/.config/vivaldi" ;;
        *) config_dir="" ;;
    esac

    if [[ -z "$config_dir" ]] || [[ ! -d "$config_dir" ]]; then
        log_warn "Config de $browser no encontrada"
        return
    fi

    if [[ "$LSO_DRY_RUN" != "true" ]]; then
        # Flags de lanzamiento para mejor rendimiento
        local desktop_file="$HOME/.local/share/applications/${browser}.desktop"
        if [[ -f "$desktop_file" ]]; then
            sed -i 's|Exec=|Exec=--enable-features=VaapiVideoDecoder,VaapiVideoEncoder --ignore-gpu-blocklist --enable-zero-copy |' "$desktop_file" 2>/dev/null || true
        fi

        log_success "$browser optimizado"
    else
        print_info "[DRY-RUN] Se optimizaría $browser"
    fi
}

optimize_browsers
