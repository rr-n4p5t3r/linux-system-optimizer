#!/usr/bin/env bash
# =============================================================================
# gpu_optimizer.sh — Diagnóstico de GPU (solo lectura)
# =============================================================================
# Este módulo es INTENCIONALMENTE solo diagnóstico: reporta vendor, modelo y
# driver en uso, y como mucho sugiere en texto el comando que el usuario
# debería correr manualmente. NUNCA instala, cambia ni reconfigura drivers
# de GPU de forma automática — hacerlo puede romper la sesión gráfica, y ese
# riesgo no vale la pena automatizarlo, ni siquiera con confirmación.
# =============================================================================

optimize_gpu() {
    print_header "DIAGNÓSTICO DE GPU"

    if ! command -v lspci &>/dev/null; then
        print_info "lspci no disponible — no se puede diagnosticar la GPU"
        return 0
    fi

    print_step "GPU detectada..."
    local gpu_line=""
    gpu_line=$(lspci -k 2>/dev/null | grep -iE 'vga|3d|display' | head -1)

    if [[ -z "$gpu_line" ]]; then
        print_info "No se detectó GPU"
        return 0
    fi

    echo -e "  ${C_CYAN}${gpu_line#*: }${C_RESET}"

    local driver=""
    driver=$(lspci -k 2>/dev/null | grep -A3 -iE 'vga|3d|display' | grep "Kernel driver in use" | head -1 | cut -d: -f2 | sed 's/^ *//')
    echo -e "  ${C_DIM}Driver en uso:${C_RESET} ${C_CYAN}${driver:-desconocido}${C_RESET}"

    case "$gpu_line" in
        *NVIDIA*|*nvidia*)
            if command -v nvidia-smi &>/dev/null; then
                print_step "Estado del driver propietario NVIDIA..."
                nvidia-smi --query-gpu=name,temperature.gpu,utilization.gpu,memory.used,memory.total --format=csv,noheader 2>/dev/null | \
                    while read -r line; do echo -e "  ${C_CYAN}${line}${C_RESET}"; done
            elif [[ "$driver" == "nouveau" ]] && command -v ubuntu-drivers &>/dev/null; then
                print_info "Usando el driver libre 'nouveau'. Si quieres el driver propietario NVIDIA,"
                print_info "revisa las opciones disponibles con: ubuntu-drivers devices"
                print_info "LSO no lo instala automáticamente — cambiar de driver de GPU puede romper la sesión gráfica."
            fi
            ;;
        *AMD*|*Radeon*|*ATI*)
            print_info "GPU AMD — el driver libre 'amdgpu'/'radeon' generalmente es la mejor opción en Linux"
            ;;
        *Intel*)
            print_info "GPU Intel — el driver libre 'i915' generalmente es suficiente, no requiere driver propietario"
            ;;
    esac

    print_success "Diagnóstico de GPU completado (solo lectura, no se modificó nada)"
}
optimize_gpu
