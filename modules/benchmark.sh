#!/usr/bin/env bash
# =============================================================================
# benchmark.sh — Benchmarks básicos del sistema
# =============================================================================
# Linux System Optimizer (LSO)
# Autor: Ricardo Rosero <rrosero2000@gmail.com>
# GitHub: https://github.com/rr-n4p5t3r
# Licencia: GPLv3
# =============================================================================

run_benchmarks() {
    print_header "BENCHMARKS DEL SISTEMA"

    print_step "Benchmark de CPU (10M de operaciones)..."
    local cpu_time
    cpu_time=$(time (
        for i in {1..10000000}; do
            : $((i * 2))
        done
    ) 2>&1 | grep real | awk '{print $2}')
    echo -e "  ${C_DIM}Tiempo CPU:${C_RESET} ${C_CYAN}${cpu_time}${C_RESET}"

    print_step "Benchmark de RAM (escritura/lectura)..."
    local ram_test_file="/tmp/lso_ram_test_$$"
    dd if=/dev/zero of="$ram_test_file" bs=1M count=100 2>&1 | grep -E "copied|MB/s" |         sed 's/^/  /' | while read line; do echo -e "${C_CYAN}$line${C_RESET}"; done
    rm -f "$ram_test_file"

    print_step "Benchmark de disco (escritura secuencial)..."
    local disk_test_file="/tmp/lso_disk_test_$$"
    dd if=/dev/zero of="$disk_test_file" bs=1M count=100 oflag=direct 2>&1 | grep -E "copied|MB/s" |         sed 's/^/  /' | while read line; do echo -e "${C_CYAN}$line${C_RESET}"; done
    rm -f "$disk_test_file"

    print_step "Verificando conectividad de red..."
    if ping -c 1 -W 2 1.1.1.1 &>/dev/null; then
        echo -e "  ${C_GREEN}✓ Conectividad a Internet: OK${C_RESET}"
        local latency
        latency=$(ping -c 3 1.1.1.1 2>/dev/null | tail -1 | awk -F'/' '{print $5}' || echo "N/A")
        echo -e "  ${C_DIM}Latencia promedio (1.1.1.1):${C_RESET} ${C_CYAN}${latency}ms${C_RESET}"
    else
        echo -e "  ${C_RED}✗ Sin conectividad a Internet${C_RESET}"
    fi

    print_success "Benchmarks completados"
}

run_benchmarks
