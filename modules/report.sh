#!/usr/bin/env bash
# =============================================================================
# report.sh — Generador de reportes de LSO
# =============================================================================

generate_report() {
    print_header "GENERANDO REPORTE"

    local report_file="${LSO_BASE_DIR}/reports/lso-report-$(date +%Y%m%d-%H%M%S).html"
    mkdir -p "${LSO_BASE_DIR}/reports"

    # Recopilar datos
    local hostname
    hostname=$(hostname)
    local uptime_info
    uptime_info=$(uptime -p 2>/dev/null || uptime)
    local kernel
    kernel=$(uname -r)

    cat > "$report_file" << EOF
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="UTF-8">
    <title>LSO Report - $hostname</title>
    <style>
        body { font-family: 'Segoe UI', system-ui, sans-serif; max-width: 900px; margin: 0 auto; padding: 20px; background: #f5f5f5; }
        h1 { color: #1a73e8; border-bottom: 3px solid #1a73e8; padding-bottom: 10px; }
        h2 { color: #333; margin-top: 30px; border-left: 4px solid #1a73e8; padding-left: 10px; }
        .card { background: white; border-radius: 8px; padding: 20px; margin: 15px 0; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        .grid { display: grid; grid-template-columns: 1fr 1fr; gap: 15px; }
        .stat { display: flex; justify-content: space-between; padding: 8px 0; border-bottom: 1px solid #eee; }
        .stat:last-child { border-bottom: none; }
        .label { color: #666; font-weight: 500; }
        .value { color: #1a73e8; font-weight: 600; }
        .success { color: #0f9d58; }
        .warning { color: #f4b400; }
        .error { color: #db4437; }
        .footer { text-align: center; color: #999; margin-top: 40px; font-size: 0.9em; }
        pre { background: #f8f9fa; padding: 15px; border-radius: 4px; overflow-x: auto; font-size: 0.85em; }
        table { width: 100%; border-collapse: collapse; margin-top: 10px; }
        th, td { padding: 10px; text-align: left; border-bottom: 1px solid #eee; }
        th { background: #f8f9fa; font-weight: 600; }
    </style>
</head>
<body>
    <h1>🐧 Linux System Optimizer — Reporte</h1>

    <div class="card">
        <h2>📋 Información General</h2>
        <div class="grid">
            <div class="stat"><span class="label">Hostname</span><span class="value">$hostname</span></div>
            <div class="stat"><span class="label">Fecha</span><span class="value">$(date)</span></div>
            <div class="stat"><span class="label">Uptime</span><span class="value">$uptime_info</span></div>
            <div class="stat"><span class="label">Kernel</span><span class="value">$kernel</span></div>
        </div>
    </div>

    <div class="card">
        <h2>💻 Hardware</h2>
        <div class="grid">
            <div class="stat"><span class="label">CPU</span><span class="value">${LSO_CPU_MODEL:-N/A}</span></div>
            <div class="stat"><span class="label">Cores/Threads</span><span class="value">${LSO_CPU_CORES:-N/A} / ${LSO_CPU_THREADS:-N/A}</span></div>
            <div class="stat"><span class="label">RAM Total</span><span class="value">$(human_size "${LSO_RAM_TOTAL:-0}")</span></div>
            <div class="stat"><span class="label">GPU</span><span class="value">${LSO_GPU:-N/A}</span></div>
            <div class="stat"><span class="label">Disco Raíz</span><span class="value">${LSO_DISK_TYPE:-N/A}</span></div>
            <div class="stat"><span class="label">Laptop</span><span class="value">${LSO_IS_LAPTOP:-false}</span></div>
        </div>
    </div>

    <div class="card">
        <h2>🖥️ Sistema</h2>
        <div class="grid">
            <div class="stat"><span class="label">Distribución</span><span class="value">${LSO_DISTRO:-N/A}</span></div>
            <div class="stat"><span class="label">Versión</span><span class="value">${LSO_DISTRO_VERSION:-N/A}</span></div>
            <div class="stat"><span class="label">Escritorio</span><span class="value">${LSO_DESKTOP:-N/A}</span></div>
            <div class="stat"><span class="label">Gestor de Paquetes</span><span class="value">${LSO_PACKAGE_MANAGER:-N/A}</span></div>
        </div>
    </div>

    <div class="card">
        <h2>📊 Uso Actual</h2>
        <pre>$(free -h 2>/dev/null || echo "No disponible")

$(df -h / 2>/dev/null || echo "No disponible")

Load Average: $(cat /proc/loadavg 2>/dev/null || echo "N/A")</pre>
    </div>

    <div class="card">
        <h2>🔧 Software Detectado</h2>
        <div class="grid">
            <div class="stat"><span class="label">Navegadores</span><span class="value">${LSO_BROWSERS[*]:-Ninguno}</span></div>
            <div class="stat"><span class="label">IDEs</span><span class="value">${LSO_IDES[*]:-Ninguno}</span></div>
            <div class="stat"><span class="label">Contenedores</span><span class="value">${LSO_CONTAINERS[*]:-Ninguno}</span></div>
            <div class="stat"><span class="label">Virtualización</span><span class="value">${LSO_VIRTUALIZATION:-N/A}</span></div>
        </div>
    </div>

    <div class="footer">
        <p>Generado por Linux System Optimizer v$(cat "${LSO_BASE_DIR}/VERSION" 2>/dev/null | grep -oP '\d+\.\d+\.\d+' || echo "0.1.0")</p>
        <p>Reporte guardado en: $report_file</p>
    </div>
</body>
</html>
EOF

    log_success "Reporte HTML generado: $report_file"

    # También generar versión de texto
    local txt_report="${report_file%.html}.txt"
    cat > "$txt_report" << EOF
================================================================================
                    LINUX SYSTEM OPTIMIZER — REPORTE
================================================================================

Fecha:        $(date)
Hostname:     $hostname
Uptime:       $uptime_info
Kernel:       $kernel

--- HARDWARE ---
CPU:          ${LSO_CPU_MODEL:-N/A}
Cores:        ${LSO_CPU_CORES:-N/A}
Threads:      ${LSO_CPU_THREADS:-N/A}
RAM Total:    $(human_size "${LSO_RAM_TOTAL:-0}")
GPU:          ${LSO_GPU:-N/A}
Disco:        ${LSO_DISK_TYPE:-N/A}
Laptop:       ${LSO_IS_LAPTOP:-false}

--- SISTEMA ---
Distribución: ${LSO_DISTRO:-N/A} (${LSO_DISTRO_ID:-N/A})
Versión:      ${LSO_DISTRO_VERSION:-N/A}
Escritorio:   ${LSO_DESKTOP:-N/A}
Pkg Manager:  ${LSO_PACKAGE_MANAGER:-N/A}

--- USO ---
$(free -h 2>/dev/null || echo "No disponible")

$(df -h / 2>/dev/null || echo "No disponible")

--- SOFTWARE ---
Navegadores:  ${LSO_BROWSERS[*]:-Ninguno}
IDEs:         ${LSO_IDES[*]:-Ninguno}
Lenguajes:    ${LSO_LANGUAGES[*]:-Ninguno}
Contenedores: ${LSO_CONTAINERS[*]:-Ninguno}
Virtualización: ${LSO_VIRTUALIZATION:-N/A}

================================================================================
EOF

    log_success "Reporte TXT generado: $txt_report"
    print_info "Abre el reporte HTML en tu navegador: file://$report_file"
}

generate_report
