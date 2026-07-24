#!/usr/bin/env bash
# =============================================================================
# dispatcher.sh — Enrutador de comandos y argumentos para LSO
# =============================================================================
# Linux System Optimizer (LSO)
# Autor: Ricardo Rosero <rrosero2000@gmail.com>
# GitHub: https://github.com/rr-n4p5t3r
# Licencia: MIT
# =============================================================================

show_help() {
    cat << 'EOF'
╔══════════════════════════════════════════════════════════════════════════════╗
║           LINUX SYSTEM OPTIMIZER (LSO) — Framework de Optimización          ║
╚══════════════════════════════════════════════════════════════════════════════╝

USO:
    sudo lso [COMANDO] [OPCIONES]

COMANDOS:
    analyze, -a              Analizar el sistema completo
    optimize, -o [perfil]    Ejecutar optimización (perfiles: desktop, laptop,
                             gaming, workstation, server, dev)
    module, -m <nombre>      Ejecutar módulo específico
    detect, -d               Mostrar información de detección del sistema
    restore, -r              Restaurar configuraciones desde backups
    report                   Generar reporte del último análisis
    plugins                  Listar plugins disponibles
    benchmark                Ejecutar benchmarks del sistema
    rules                    Evaluar el motor de reglas (config/rules/*.rules)
    help, -h                 Mostrar esta ayuda
    version, -v              Mostrar versión

OPCIONES:
    --dry-run                Simular ejecución sin aplicar cambios
    --force, -f              Saltar confirmaciones interactivas
    --debug                  Modo debug (salida verbosa)
    --profile <nombre>       Especificar perfil de optimización
    --backup                 Crear backup antes de cualquier cambio
    --full                   Con 'module package_optimizer': incluye
                             actualización completa del sistema (upgrade)

EJEMPLOS:
    sudo lso analyze
    sudo lso optimize --profile gaming
    sudo lso module memory_optimizer
    sudo lso module package_optimizer --full
    sudo lso rules --dry-run
    sudo lso -o laptop --dry-run

AUTOR:
    Ricardo Rosero <rrosero2000@gmail.com>
    GitHub: https://github.com/rr-n4p5t3r

EOF
}

show_version() {
    local version_file="${LSO_BASE_DIR}/VERSION"
    if [[ -f "$version_file" ]]; then
        cat "$version_file"
    else
        echo "LSO v0.1.0-alpha"
        echo "Autor: Ricardo Rosero <rrosero2000@gmail.com>"
        echo "GitHub: https://github.com/rr-n4p5t3r"
    fi
}

parse_args() {
    LSO_COMMAND=""
    LSO_ARGS=()

    if [[ $# -eq 0 ]]; then
        LSO_COMMAND="help"
        return 0
    fi

    while [[ $# -gt 0 ]]; do
        case "$1" in
            analyze|-a)
                LSO_COMMAND="analyze"
                shift
                ;;
            optimize|-o)
                LSO_COMMAND="optimize"
                shift
                ;;
            module|-m)
                LSO_COMMAND="module"
                if [[ -n "${2:-}" ]]; then
                    LSO_ARGS+=("$2")
                    shift 2
                else
                    log_error "Debes especificar un nombre de módulo. Ej: lso module memory_optimizer"
                    exit 1
                fi
                ;;
            detect|-d)
                LSO_COMMAND="detect"
                shift
                ;;
            restore|-r)
                LSO_COMMAND="restore"
                shift
                ;;
            report)
                LSO_COMMAND="report"
                shift
                ;;
            plugins)
                LSO_COMMAND="plugins"
                shift
                ;;
            benchmark)
                LSO_COMMAND="benchmark"
                shift
                ;;
            rules)
                LSO_COMMAND="rules"
                shift
                ;;
            help|-h|--help)
                LSO_COMMAND="help"
                shift
                ;;
            version|-v|--version)
                LSO_COMMAND="version"
                shift
                ;;
            --dry-run)
                LSO_DRY_RUN=true
                shift
                ;;
            --force|-f)
                LSO_FORCE=true
                shift
                ;;
            --debug)
                LSO_DEBUG=1
                shift
                ;;
            --profile)
                if [[ -n "${2:-}" ]]; then
                    LSO_PROFILE="$2"
                    shift 2
                else
                    log_error "Debes especificar un nombre de perfil después de --profile"
                    exit 1
                fi
                ;;
            --backup)
                LSO_AUTO_BACKUP=true
                shift
                ;;
            --full)
                LSO_FULL=true
                shift
                ;;
            *)
                LSO_ARGS+=("$1")
                shift
                ;;
        esac
    done
}

dispatch() {
    set +e  # No fallar si un comando retorna error

    case "$LSO_COMMAND" in
        analyze)
            run_analysis
            ;;
        optimize)
            run_optimization "${LSO_PROFILE:-desktop}"
            ;;
        module)
            if [[ ${#LSO_ARGS[@]} -eq 0 ]]; then
                log_error "Debes especificar un nombre de módulo. Ej: lso module memory_optimizer"
                exit 1
            fi
            run_module "${LSO_ARGS[0]}"
            ;;
        detect)
            run_full_detection
            print_header "RESUMEN DE DETECCIÓN"
            echo -e "  Distribución:   ${C_CYAN}${LSO_DISTRO:-N/A}${C_RESET}"
            echo -e "  Escritorio:     ${C_CYAN}${LSO_DESKTOP:-N/A}${C_RESET}"
            echo -e "  Gestor pkg:     ${C_CYAN}${LSO_PACKAGE_MANAGER:-N/A}${C_RESET}"
            echo -e "  CPU:            ${C_CYAN}${LSO_CPU_MODEL:-N/A}${C_RESET}"
            echo -e "  Cores/Threads:  ${C_CYAN}${LSO_CPU_CORES:-N/A} / ${LSO_CPU_THREADS:-N/A}${C_RESET}"
            echo -e "  RAM:            ${C_CYAN}$(human_size "${LSO_RAM_TOTAL:-0}")${C_RESET}"
            echo -e "  GPU:            ${C_CYAN}${LSO_GPU:-N/A}${C_RESET}"
            echo -e "  Disco:          ${C_CYAN}${LSO_DISK_TYPE:-N/A}${C_RESET}"
            echo -e "  Laptop:         ${C_CYAN}${LSO_IS_LAPTOP:-false}${C_RESET}"
            echo -e "  Navegadores:    ${C_CYAN}${LSO_BROWSERS[*]:-Ninguno}${C_RESET}"
            echo -e "  Virtualización: ${C_CYAN}${LSO_VIRTUALIZATION:-N/A}${C_RESET}"
            ;;
        restore)
            run_module "restore"
            ;;
        report)
            run_module "report"
            ;;
        plugins)
            list_plugins
            ;;
        benchmark)
            run_module "benchmark"
            ;;
        rules)
            run_rule_engine
            ;;
        version)
            show_version
            ;;
        help|*)
            show_help
            ;;
    esac

    set -e
    return 0
}
