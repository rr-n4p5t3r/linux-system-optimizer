#!/usr/bin/env bash
# =============================================================================
# analyzer.sh — Analizador completo del sistema
# =============================================================================
# Linux System Optimizer (LSO)
# Autor: Ricardo Rosero <rrosero2000@gmail.com>
# GitHub: https://github.com/rr-n4p5t3r
# Licencia: GPLv3
# =============================================================================

analyze_system() {
    print_header "ANÁLISIS DEL SISTEMA"

    LSO_ANALYSIS_REPORT=""
    LSO_ANALYSIS_REPORT+="=== ANÁLISIS DEL SISTEMA ===\n"
    LSO_ANALYSIS_REPORT+="Autor: Ricardo Rosero <rrosero2000@gmail.com>\n"
    LSO_ANALYSIS_REPORT+="GitHub: https://github.com/rr-n4p5t3r\n"
    LSO_ANALYSIS_REPORT+="Fecha: $(date)\n\n"

    print_step "Analizando CPU..."
    local cpu_usage=""
    cpu_usage=$(awk '{print $1}' < /proc/loadavg)
    local cpu_percent=""
    cpu_percent=$(awk "BEGIN {printf \"%.1f\", ($cpu_usage / $LSO_CPU_CORES) * 100}")

    LSO_ANALYSIS_CPU_PERCENT="$cpu_percent"

    echo -e "  ${C_DIM}Uso promedio (1m):${C_RESET} ${C_CYAN}${cpu_percent}%${C_RESET}"
    echo -e "  ${C_DIM}Load average:${C_RESET} ${C_CYAN}$(cat /proc/loadavg)${C_RESET}"

    LSO_ANALYSIS_REPORT+="[CPU]\n"
    LSO_ANALYSIS_REPORT+="  Uso: ${cpu_percent}%\n"
    LSO_ANALYSIS_REPORT+="  Load: $(cat /proc/loadavg)\n\n"

    print_step "Analizando Memoria..."
    local ram_used ram_total ram_percent
    ram_total=$(free -m | awk '/^Mem:/{print $2}')
    ram_used=$(free -m | awk '/^Mem:/{print $3}')
    ram_percent=$(awk "BEGIN {printf \"%.1f\", ($ram_used / $ram_total) * 100}")

    local ram_color="$C_GREEN"
    if awk "BEGIN {exit !($ram_percent > 85)}"; then
        ram_color="$C_RED"
    elif awk "BEGIN {exit !($ram_percent > 70)}"; then
        ram_color="$C_YELLOW"
    fi

    LSO_ANALYSIS_RAM_PERCENT="$ram_percent"

    echo -e "  ${C_DIM}Total:${C_RESET} ${C_CYAN}${ram_total}MB${C_RESET}"
    echo -e "  ${C_DIM}Usada:${C_RESET} ${ram_color}${ram_used}MB (${ram_percent}%)${C_RESET}"
    echo -e "  ${C_DIM}Libre:${C_RESET} ${C_CYAN}$(free -m | awk '/^Mem:/{print $7}')MB${C_RESET}"

    LSO_ANALYSIS_REPORT+="[MEMORIA]\n"
    LSO_ANALYSIS_REPORT+="  Total: ${ram_total}MB\n"
    LSO_ANALYSIS_REPORT+="  Usada: ${ram_used}MB (${ram_percent}%)\n\n"

    print_step "Analizando Disco..."
    LSO_ANALYSIS_REPORT+="[DISCO]\n"

    # Usar df con formato personalizado para evitar problemas con idiomas
    while IFS= read -r line; do
        # Saltar línea de encabezado
        [[ "$line" =~ ^Filesystem ]] && continue
        [[ "$line" =~ ^S.ficheros ]] && continue
        [[ "$line" =~ ^Sistema ]] && continue
        [[ -z "$line" ]] && continue

        # Extraer campos con awk (más robusto que read con variables fijas)
        local filesystem size used percent mount
        filesystem=$(echo "$line" | awk '{print $1}')
        size=$(echo "$line" | awk '{print $2}')
        used=$(echo "$line" | awk '{print $3}')
        percent=$(echo "$line" | awk '{print $5}')
        mount=$(echo "$line" | awk '{print $6}')

        # Validar que tenemos datos
        [[ -z "$filesystem" ]] && continue
        [[ "$filesystem" == "Filesystem" ]] && continue
        [[ "$filesystem" == "S.ficheros" ]] && continue
        [[ "$filesystem" == "Sistema" ]] && continue

        local pnum="${percent%%%}"
        LSO_ANALYSIS_DISK_PERCENT="$pnum"
        local disk_color="$C_GREEN"
        [[ "$pnum" -gt 85 ]] && disk_color="$C_RED"
        [[ "$pnum" -gt 70 ]] && [[ "$pnum" -le 85 ]] && disk_color="$C_YELLOW"

        echo -e "  ${C_DIM}${mount}:${C_RESET} ${disk_color}${used}/${size} (${percent})${C_RESET}"
        LSO_ANALYSIS_REPORT+="  ${mount}: ${used}/${size} (${percent})\n"
    done < <(df -h / 2>/dev/null)

    LSO_ANALYSIS_REPORT+="\n"

    print_step "Top 10 procesos por uso de RAM..."
    echo -e "  ${C_DIM}PID    %MEM   COMMAND${C_RESET}"
    ps aux --sort=-%mem 2>/dev/null | head -11 | tail -10 | \
        awk '{printf "  %-6s %-6s %s\n", $2, $4, $11}' | \
        while read line; do echo -e "${C_CYAN}$line${C_RESET}"; done

    LSO_ANALYSIS_REPORT+="[TOP PROCESOS RAM]\n"
    LSO_ANALYSIS_REPORT+=$(ps aux --sort=-%mem 2>/dev/null | head -11 | tail -10 | awk '{print "  " $2 " " $4 "% " $11}')
    LSO_ANALYSIS_REPORT+="\n\n"

    print_step "Servicios activos..."
    local active_services=""
    active_services=$(systemctl list-units --type=service --state=active --no-pager --no-legend 2>/dev/null | wc -l)
    echo -e "  ${C_DIM}Servicios activos:${C_RESET} ${C_CYAN}${active_services}${C_RESET}"
    LSO_ANALYSIS_REPORT+="[SERVICIOS] Activos: ${active_services}\n\n"

    print_step "Analizando cachés..."
    local cache_size=0

    if [[ -d /var/cache/apt/archives ]]; then
        local apt_cache=""
        apt_cache=$(du -sb /var/cache/apt/archives 2>/dev/null | cut -f1)
        cache_size=$((cache_size + apt_cache))
    fi

    if [[ -d /var/cache/dnf ]]; then
        local dnf_cache=""
        dnf_cache=$(du -sb /var/cache/dnf 2>/dev/null | cut -f1)
        cache_size=$((cache_size + dnf_cache))
    fi

    if [[ -d /var/cache/pacman/pkg ]]; then
        local pacman_cache=""
        pacman_cache=$(du -sb /var/cache/pacman/pkg 2>/dev/null | cut -f1)
        cache_size=$((cache_size + pacman_cache))
    fi

    local journal_size=""
    journal_size=$(journalctl --disk-usage 2>/dev/null | grep -oP '\d+\.?\d*[KMGT]?' | head -1 || echo "0")

    echo -e "  ${C_DIM}Caché de paquetes:${C_RESET} ${C_CYAN}$(human_size "$cache_size")${C_RESET}"
    echo -e "  ${C_DIM}Journald:${C_RESET} ${C_CYAN}${journal_size}${C_RESET}"
    LSO_ANALYSIS_REPORT+="[CACHÉS]\n"
    LSO_ANALYSIS_REPORT+="  Paquetes: $(human_size "$cache_size")\n"
    LSO_ANALYSIS_REPORT+="  Journal: ${journal_size}\n\n"

    if [[ -d /sys/class/thermal ]]; then
        print_step "Temperaturas..."
        for temp in /sys/class/thermal/thermal_zone*/temp; do
            [[ -f "$temp" ]] || continue
            local temp_val=""
            temp_val=$(cat "$temp" 2>/dev/null)
            [[ -z "$temp_val" ]] && continue
            local temp_c=""
            temp_c=$(awk "BEGIN {printf \"%.1f\", $temp_val / 1000}")
            local zone=""
            zone=$(basename "$(dirname "$temp")")
            local type=""
            type=$(cat "$(dirname "$temp")/type" 2>/dev/null || echo "$zone")
            echo -e "  ${C_DIM}${type}:${C_RESET} ${C_CYAN}${temp_c}°C${C_RESET}"
        done
    fi

    print_success "Análisis completado"
}

analyze_system
