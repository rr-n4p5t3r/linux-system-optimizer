#!/usr/bin/env bash
# =============================================================================
# Linux System Optimizer (LSO)
# Framework modular y extensible para optimizar distribuciones GNU/Linux
# =============================================================================
# Versión: 0.1.0-alpha
# Autor: Ricardo Rosero <rrosero2000@gmail.com>
# GitHub: https://github.com/rr-n4p5t3r
# Licencia: MIT
# =============================================================================

# NO usar set -e — queremos manejar errores nosotros mismos
set -u
# set -o pipefail  # Desactivado para evitar fallos silenciosos en pipes

# =============================================================================
# RESOLVER DIRECTORIO BASE (incluso a través de symlinks)
# =============================================================================

SCRIPT_SOURCE="${BASH_SOURCE[0]}"

while [[ -L "$SCRIPT_SOURCE" ]]; do
    SCRIPT_DIR=$(dirname "$SCRIPT_SOURCE")
    SCRIPT_SOURCE=$(readlink "$SCRIPT_SOURCE")
    [[ "$SCRIPT_SOURCE" != /* ]] && SCRIPT_SOURCE="$SCRIPT_DIR/$SCRIPT_SOURCE"
done

SCRIPT_DIR=$(cd "$(dirname "$SCRIPT_SOURCE")" && pwd)
LSO_BASE_DIR="$SCRIPT_DIR"
export LSO_BASE_DIR

# =============================================================================
# VARIABLES GLOBALES
# =============================================================================

export LSO_DEBUG=0
export LSO_DRY_RUN=false
export LSO_FORCE=false
export LSO_AUTO_BACKUP=false
export LSO_PROFILE=""
export LSO_FULL=false

# =============================================================================
# CARGAR LIBRERÍAS CORE
# =============================================================================

for lib in colors logger utils; do
    lib_path="${LSO_BASE_DIR}/lib/${lib}.sh"
    if [[ ! -f "$lib_path" ]]; then
        echo "ERROR: No se encontró ${lib}.sh en ${LSO_BASE_DIR}/lib/" >&2
        exit 1
    fi
    source "$lib_path" || {
        echo "ERROR: No se pudo cargar ${lib}.sh" >&2
        exit 1
    }
done

for core in detector plugin_loader engine rule_engine dispatcher; do
    core_path="${LSO_BASE_DIR}/core/${core}.sh"
    if [[ ! -f "$core_path" ]]; then
        echo "ERROR: No se encontró ${core}.sh en ${LSO_BASE_DIR}/core/" >&2
        exit 1
    fi
    source "$core_path" || {
        echo "ERROR: No se pudo cargar ${core}.sh" >&2
        exit 1
    }
done

# =============================================================================
# INICIALIZACIÓN
# =============================================================================

init_logger
rotate_logs

# Banner
print_header "LINUX SYSTEM OPTIMIZER"
echo -e "${C_DIM}Framework modular para optimización de GNU/Linux${C_RESET}"
echo -e "${C_DIM}Autor: Ricardo Rosero | GitHub: https://github.com/rr-n4p5t3r${C_RESET}"
echo

# Verificar dependencias mínimas
check_deps "bash" "awk" "sed" "grep" "cat" || {
    log_error "Dependencias mínimas no satisfechas"
    exit 1
}

# Detectar sistema (con manejo de errores)
log_info "Detectando sistema..."
run_full_detection || {
    log_warn "La detección del sistema tuvo problemas, continuando con valores por defecto..."
}
export_detection_vars

# Cargar plugins
load_all_plugins

# Cargar configuración
load_config

# =============================================================================
# PROCESAR ARGUMENTOS Y EJECUTAR
# =============================================================================

parse_args "$@"

# Ejecutar comando con manejo de errores
dispatch || {
    log_error "El comando falló. Revisa los logs en: ${LSO_LOG_FILE}"
    exit 1
}

log_info "=== Linux System Optimizer finalizado ==="
exit 0
