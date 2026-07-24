#!/usr/bin/env bash
# =============================================================================
# rule_engine.sh — Motor de reglas condicionales para LSO
# =============================================================================
# Linux System Optimizer (LSO)
# Autor: Ricardo Rosero <rrosero2000@gmail.com>
# GitHub: https://github.com/rr-n4p5t3r
# Licencia: GPLv3
# =============================================================================


LSO_RULES_DIR="${LSO_BASE_DIR}/config/rules"

# Resuelve un valor de condición antes de una comparación numérica:
# sustituye la referencia simbólica "cores" por LSO_CPU_CORES (permite
# expresiones como "cores * 2") y normaliza sufijos de tamaño (GB/MB/KB/TB/B)
# a GB, la misma escala que ya usan las variables ram_total y browser_cache.
_lso_resolve_numeric_value() {
    local val="$1"

    val=$(echo "$val" | sed -E "s/\bcores\b/${LSO_CPU_CORES:-1}/g")

    if [[ "$val" =~ ^([0-9.]+)[[:space:]]*([KkMmGgTt]?[Bb])$ ]]; then
        local num="${BASH_REMATCH[1]}"
        local unit="${BASH_REMATCH[2],,}"
        case "$unit" in
            b)  val=$(awk "BEGIN {printf \"%.6f\", $num / 1073741824}") ;;
            kb) val=$(awk "BEGIN {printf \"%.6f\", $num / 1048576}") ;;
            mb) val=$(awk "BEGIN {printf \"%.6f\", $num / 1024}") ;;
            gb) val="$num" ;;
            tb) val=$(awk "BEGIN {printf \"%.6f\", $num * 1024}") ;;
        esac
    fi

    echo "$val"
}

evaluate_condition() {
    local condition="$1"
    local result=false

    local var op val
    var=$(echo "$condition" | awk '{print $1}')
    op=$(echo "$condition" | awk '{print $2}')
    val=$(echo "$condition" | cut -d' ' -f3-)

    local current_val=""
    case "$var" in
        ram_usage)
            current_val=$(free | awk '/^Mem:/{printf "%.0f", $3/$2 * 100}')
            ;;
        cpu_usage)
            current_val=$(awk '{print $1}' < /proc/loadavg)
            current_val=$(awk "BEGIN {printf \"%.0f\", $current_val / $LSO_CPU_CORES * 100}")
            ;;
        swap_usage)
            current_val=$(LC_ALL=C free | awk '/^Swap:/{if($2>0) printf "%.0f", $3/$2 * 100; else print 0}')
            ;;
        distro)
            current_val="$LSO_DISTRO_ID"
            ;;
        desktop)
            current_val="$LSO_DESKTOP"
            ;;
        browser)
            current_val="${LSO_BROWSERS[0]:-none}"
            ;;
        profile)
            current_val="$LSO_PROFILE"
            ;;
        cpu_cores)
            current_val="$LSO_CPU_CORES"
            ;;
        cpu_governor)
            current_val=$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || echo "unknown")
            ;;
        zram_available)
            [[ -d /sys/class/zram-control ]] && current_val="true" || current_val="false"
            ;;
        ram_total)
            current_val=$(free -g | awk '/^Mem:/{print $2}')
            ;;
        load_average)
            current_val=$(awk '{print $1}' < /proc/loadavg)
            ;;
        browser_cache)
            local total_bytes=0
            local cache_dir
            for cache_dir in "$HOME/.cache/mozilla" "$HOME/.cache/google-chrome" \
                "$HOME/.cache/chromium" "$HOME/.cache/BraveSoftware" \
                "$HOME/.cache/opera" "$HOME/.cache/vivaldi"; do
                if [[ -d "$cache_dir" ]]; then
                    local dsize
                    dsize=$(du -sb "$cache_dir" 2>/dev/null | cut -f1)
                    total_bytes=$((total_bytes + ${dsize:-0}))
                fi
            done
            current_val=$(awk "BEGIN {printf \"%.6f\", $total_bytes / 1073741824}")
            ;;
        *)
            current_val=""
            ;;
    esac

    case "$op" in
        ==)
            [[ "$current_val" == "$val" ]] && result=true
            ;;
        !=)
            [[ "$current_val" != "$val" ]] && result=true
            ;;
        ">")
            val=$(_lso_resolve_numeric_value "$val")
            awk "BEGIN {exit !($current_val > ($val))}" && result=true
            ;;
        "<")
            val=$(_lso_resolve_numeric_value "$val")
            awk "BEGIN {exit !($current_val < ($val))}" && result=true
            ;;
        ">=")
            val=$(_lso_resolve_numeric_value "$val")
            awk "BEGIN {exit !($current_val >= ($val))}" && result=true
            ;;
        "<=")
            val=$(_lso_resolve_numeric_value "$val")
            awk "BEGIN {exit !($current_val <= ($val))}" && result=true
            ;;
    esac

    $result
}

load_rules() {
    local rules_file="$1"

    if [[ ! -f "$rules_file" ]]; then
        log_warn "Archivo de reglas no encontrado: $rules_file"
        return 0
    fi

    log_info "Evaluando reglas: $(basename "$rules_file")"

    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ "$line" =~ ^#.*$ ]] && continue
        [[ -z "${line// /}" ]] && continue

        local condition action
        condition=$(echo "$line" | sed 's/ *->.*//')
        action=$(echo "$line" | sed 's/.*-> *//')

        if [[ "$condition" == *"&&"* ]]; then
            local all_match=true
            local parts=()
            mapfile -t parts <<< "${condition//&&/$'\n'}"
            for part in "${parts[@]}"; do
                part=$(echo "$part" | sed 's/^ *//;s/ *$//')
                [[ -z "$part" ]] && continue
                if ! evaluate_condition "$part"; then
                    all_match=false
                    break
                fi
            done

            if $all_match; then
                log_info "Regla activada: $condition -> $action"
                execute_rule_action "$action"
            fi
        else
            if evaluate_condition "$condition"; then
                log_info "Regla activada: $condition -> $action"
                execute_rule_action "$action"
            fi
        fi
    done < "$rules_file"
}

execute_rule_action() {
    local action="$1"

    case "$action" in
        analyze_processes)
            run_module "process_manager" 2>/dev/null || true
            ;;
        clean_caches)
            run_module "cache_cleaner" 2>/dev/null || true
            ;;
        optimize_swap)
            run_module "swap" 2>/dev/null || true
            ;;
        increase_swappiness)
            if [[ "$LSO_DRY_RUN" != "true" ]]; then
                sysctl -w vm.swappiness=30 &>/dev/null || true
            fi
            ;;
        setup_zram)
            run_module "zram" 2>/dev/null || true
            ;;
        optimize_processes)
            run_module "process_manager" 2>/dev/null || true
            ;;
        set_governor_performance)
            if [[ "$LSO_DRY_RUN" != "true" ]]; then
                for cpu in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
                    echo "performance" > "$cpu" 2>/dev/null || true
                done
            fi
            ;;
        enable_parallel_jobs)
            log_info "Sistema tiene múltiples cores — compilaciones paralelas habilitadas"
            ;;
        alert_high_load)
            log_warn "ALTA CARGA: Load average excede capacidad de CPU"
            ;;
        clean_browser_cache)
            run_module "cache_cleaner" 2>/dev/null || true
            ;;
        optimize_firefox|optimize_chromium)
            run_module "browser_optimizer" 2>/dev/null || true
            ;;
        optimize_*)
            local target="${action#optimize_}"
            if [[ -f "${LSO_BASE_DIR}/modules/${target}_optimizer.sh" ]]; then
                run_module "${target}_optimizer" 2>/dev/null || true
            elif [[ -f "${LSO_BASE_DIR}/distros/${target}.sh" ]]; then
                # shellcheck source=/dev/null
                source "${LSO_BASE_DIR}/distros/${target}.sh" 2>/dev/null || true
            elif [[ -f "${LSO_BASE_DIR}/desktops/${target}.sh" ]]; then
                # shellcheck source=/dev/null
                source "${LSO_BASE_DIR}/desktops/${target}.sh" 2>/dev/null || true
            fi
            ;;
        *)
            log_warn "Acción desconocida: $action"
            ;;
    esac
}

run_rule_engine() {
    print_header "MOTOR DE REGLAS"

    if [[ ! -d "$LSO_RULES_DIR" ]]; then
        log_warn "Directorio de reglas no encontrado"
        return 0
    fi

    for rules_file in "$LSO_RULES_DIR"/*.rules; do
        [[ -f "$rules_file" ]] || continue
        load_rules "$rules_file"
    done

    print_success "Motor de reglas completado"
}
