#!/usr/bin/env bash
# =============================================================================
# detector.sh — Motor de detección automática del sistema
# =============================================================================
# Linux System Optimizer (LSO)
# Autor: Ricardo Rosero <rrosero2000@gmail.com>
# GitHub: https://github.com/rr-n4p5t3r
# Licencia: GPLv3
# =============================================================================

LSO_DISTRO=""
LSO_DISTRO_ID=""
LSO_DISTRO_VERSION=""
LSO_DESKTOP=""
LSO_PACKAGE_MANAGER=""
LSO_CPU_MODEL=""
LSO_CPU_CORES=0
LSO_CPU_THREADS=0
LSO_RAM_TOTAL=0
LSO_RAM_AVAILABLE=0
LSO_GPU=""
LSO_DISK_TYPE=""
LSO_IS_LAPTOP=false
LSO_BROWSERS=()
LSO_IDES=()
LSO_LANGUAGES=()
LSO_CONTAINERS=()
LSO_VIRTUALIZATION=""

_lso_log() {
    local msg="$1"
    if command -v log_info &>/dev/null; then
        log_info "$msg"
    else
        echo "[INFO] $msg"
    fi
}

detect_distro() {
    LSO_DISTRO="Unknown"
    LSO_DISTRO_ID="unknown"
    LSO_DISTRO_VERSION="unknown"

    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        LSO_DISTRO="${NAME:-Unknown}"
        LSO_DISTRO_ID="${ID:-unknown}"
        LSO_DISTRO_VERSION="${VERSION_ID:-unknown}"
    elif command -v lsb_release &>/dev/null; then
        LSO_DISTRO=$(lsb_release -si 2>/dev/null || echo "Unknown")
        LSO_DISTRO_ID=$(lsb_release -si 2>/dev/null | tr '[:upper:]' '[:lower:]' || echo "unknown")
        LSO_DISTRO_VERSION=$(lsb_release -sr 2>/dev/null || echo "unknown")
    fi

    case "$LSO_DISTRO_ID" in
        ubuntu)        LSO_DISTRO_ID="ubuntu" ;;
        debian)        LSO_DISTRO_ID="debian" ;;
        linuxmint|mint) LSO_DISTRO_ID="mint" ;;
        fedora)        LSO_DISTRO_ID="fedora" ;;
        pop)           LSO_DISTRO_ID="popos" ;;
        neon)          LSO_DISTRO_ID="neon" ;;
        zorin)         LSO_DISTRO_ID="zorin" ;;
        elementary)    LSO_DISTRO_ID="elementary" ;;
        mx)            LSO_DISTRO_ID="mxlinux" ;;
        nobara)        LSO_DISTRO_ID="nobara" ;;
        arch)          LSO_DISTRO_ID="arch" ;;
        manjaro)       LSO_DISTRO_ID="manjaro" ;;
        endeavouros)   LSO_DISTRO_ID="endeavouros" ;;
        opensuse*|suse*) LSO_DISTRO_ID="opensuse" ;;
        rocky)         LSO_DISTRO_ID="rocky" ;;
        almalinux)     LSO_DISTRO_ID="almalinux" ;;
    esac

    _lso_log "Distribución detectada: $LSO_DISTRO ($LSO_DISTRO_ID $LSO_DISTRO_VERSION)"
}

detect_desktop() {
    LSO_DESKTOP="unknown"

    if [[ -n "${XDG_CURRENT_DESKTOP:-}" ]]; then
        LSO_DESKTOP="${XDG_CURRENT_DESKTOP,,}"
    elif [[ -n "${DESKTOP_SESSION:-}" ]]; then
        LSO_DESKTOP="${DESKTOP_SESSION,,}"
    elif command -v wmctrl &>/dev/null; then
        LSO_DESKTOP=$(wmctrl -m 2>/dev/null | grep -i "Name:" | awk '{print $2}' | tr '[:upper:]' '[:lower:]' || echo "unknown")
    fi

    case "$LSO_DESKTOP" in
        *cinnamon*)  LSO_DESKTOP="cinnamon" ;;
        *gnome*)     LSO_DESKTOP="gnome" ;;
        *kde*|*plasma*) LSO_DESKTOP="kde" ;;
        *xfce*)      LSO_DESKTOP="xfce" ;;
        *mate*)      LSO_DESKTOP="mate" ;;
        *lxqt*)      LSO_DESKTOP="lxqt" ;;
        *budgie*)    LSO_DESKTOP="budgie" ;;
        *cosmic*)    LSO_DESKTOP="cosmic" ;;
    esac

    _lso_log "Escritorio detectado: $LSO_DESKTOP"
}

detect_package_manager() {
    LSO_PACKAGE_MANAGER="unknown"

    if command -v apt &>/dev/null; then
        LSO_PACKAGE_MANAGER="apt"
    elif command -v dnf &>/dev/null; then
        LSO_PACKAGE_MANAGER="dnf"
    elif command -v pacman &>/dev/null; then
        LSO_PACKAGE_MANAGER="pacman"
    elif command -v zypper &>/dev/null; then
        LSO_PACKAGE_MANAGER="zypper"
    fi

    _lso_log "Gestor de paquetes: $LSO_PACKAGE_MANAGER"
}

detect_cpu() {
    LSO_CPU_MODEL="Unknown"
    LSO_CPU_CORES=1
    LSO_CPU_THREADS=1

    if [[ -f /proc/cpuinfo ]]; then
        LSO_CPU_MODEL=$(grep -m1 'model name' /proc/cpuinfo 2>/dev/null | cut -d':' -f2 | sed 's/^ *//' || echo "Unknown")
        LSO_CPU_CORES=$(nproc --all 2>/dev/null || grep -c '^processor' /proc/cpuinfo 2>/dev/null || echo "1")
        LSO_CPU_THREADS=$LSO_CPU_CORES

        local siblings
        siblings=$(grep 'siblings' /proc/cpuinfo 2>/dev/null | head -1 | awk '{print $3}')
        [[ -n "$siblings" ]] && LSO_CPU_THREADS=$siblings
    fi

    _lso_log "CPU: $LSO_CPU_MODEL | Cores: $LSO_CPU_CORES | Threads: $LSO_CPU_THREADS"
}

detect_ram() {
    LSO_RAM_TOTAL=0
    LSO_RAM_AVAILABLE=0

    if command -v free &>/dev/null; then
        LSO_RAM_TOTAL=$(free -b 2>/dev/null | awk '/^Mem:/{print $2}' || echo "0")
        LSO_RAM_AVAILABLE=$(free -b 2>/dev/null | awk '/^Mem:/{print $7}' || echo "0")
    elif [[ -f /proc/meminfo ]]; then
        LSO_RAM_TOTAL=$(awk '/MemTotal/{print $2 * 1024}' /proc/meminfo 2>/dev/null || echo "0")
        LSO_RAM_AVAILABLE=$(awk '/MemAvailable/{print $2 * 1024}' /proc/meminfo 2>/dev/null || echo "0")
    fi

    _lso_log "RAM Total: $(human_size "$LSO_RAM_TOTAL") | Disponible: $(human_size "$LSO_RAM_AVAILABLE")"
}

detect_gpu() {
    LSO_GPU="Unknown"

    if command -v lspci &>/dev/null; then
        LSO_GPU=$(lspci 2>/dev/null | grep -iE 'vga|3d|display' | head -1 | sed 's/.*: //' || echo "Unknown")
    elif [[ -d /sys/class/drm ]]; then
        LSO_GPU=$(cat /sys/class/drm/card*/device/vendor 2>/dev/null | head -1 || echo "Unknown")
    fi

    _lso_log "GPU: $LSO_GPU"
}

detect_disk_type() {
    LSO_DISK_TYPE="Unknown"

    # Método 1: Usar findmnt
    local root_dev
    root_dev=$(findmnt -n -o SOURCE / 2>/dev/null | sed 's/\[.*\]//' || echo "")

    # Método 2: Usar df como fallback
    if [[ -z "$root_dev" ]]; then
        root_dev=$(df / 2>/dev/null | tail -1 | awk '{print $1}')
    fi

    # Método 3: Usar /proc/mounts
    if [[ -z "$root_dev" ]]; then
        root_dev=$(awk '$2 == "/" {print $1}' /proc/mounts 2>/dev/null | head -1)
    fi

    if [[ -n "$root_dev" ]]; then
        local disk_name

        # Si es un dispositivo mapper (LVM), obtener el dispositivo subyacente
        if [[ "$root_dev" == /dev/mapper/* ]]; then
            # Intentar resolver el dispositivo real
            if command -v dmsetup &>/dev/null; then
                disk_name=$(dmsetup deps "$root_dev" 2>/dev/null | grep -oP '\(\K[^,)]+' | head -1 | sed 's/[0-9]*$//')
            fi
            # Fallback: usar lsblk
            if [[ -z "$disk_name" ]] && command -v lsblk &>/dev/null; then
                disk_name=$(lsblk -no PKNAME "$root_dev" 2>/dev/null | head -1)
            fi
        else
            disk_name=$(basename "$root_dev" | sed 's/[0-9]*$//')
        fi

        # Si aún no tenemos disk_name, intentar con lsblk
        if [[ -z "$disk_name" ]] && command -v lsblk &>/dev/null; then
            disk_name=$(lsblk -ndo PKNAME "$root_dev" 2>/dev/null | head -1)
        fi

        if [[ -n "$disk_name" ]]; then
            # Verificar si es NVMe
            if [[ "$disk_name" == nvme* ]]; then
                LSO_DISK_TYPE="NVMe"
            elif [[ -f "/sys/block/${disk_name}/queue/rotational" ]]; then
                local rotational
                rotational=$(cat "/sys/block/${disk_name}/queue/rotational" 2>/dev/null || echo "1")
                if [[ "$rotational" == "0" ]]; then
                    LSO_DISK_TYPE="SSD"
                else
                    LSO_DISK_TYPE="HDD"
                fi
            elif [[ "$disk_name" == sd* ]] || [[ "$disk_name" == hd* ]]; then
                # Intentar con hdparm o smartctl
                if command -v hdparm &>/dev/null; then
                    local hdparm_out
                    hdparm_out=$(hdparm -I "/dev/${disk_name}" 2>/dev/null | grep -i "solid state" || echo "")
                    if [[ -n "$hdparm_out" ]]; then
                        LSO_DISK_TYPE="SSD"
                    else
                        LSO_DISK_TYPE="HDD"
                    fi
                else
                    LSO_DISK_TYPE="Unknown"
                fi
            fi
        fi
    fi

    _lso_log "Tipo de disco raíz: $LSO_DISK_TYPE"
}

detect_browsers() {
    LSO_BROWSERS=()
    local browsers=("firefox" "chromium" "chromium-browser" "google-chrome" "brave" "brave-browser" "opera" "vivaldi" "librewolf" "waterfox" "tor-browser")

    for browser in "${browsers[@]}"; do
        if command -v "$browser" &>/dev/null; then
            LSO_BROWSERS+=("$browser")
        fi
    done

    if [[ ${#LSO_BROWSERS[@]} -gt 0 ]]; then
        _lso_log "Navegadores detectados: ${LSO_BROWSERS[*]}"
    else
        _lso_log "Ningún navegador detectado"
    fi
}

detect_ides() {
    LSO_IDES=()
    local ides=("code" "code-oss" "codium" "idea" "pycharm" "webstorm" "phpstorm" "eclipse" "netbeans" "atom" "sublime_text" "geany" "kate" "gedit")

    for ide in "${ides[@]}"; do
        if command -v "$ide" &>/dev/null; then
            LSO_IDES+=("$ide")
        fi
    done

    [[ ${#LSO_IDES[@]} -gt 0 ]] && _lso_log "IDEs detectados: ${LSO_IDES[*]}"
}

detect_languages() {
    LSO_LANGUAGES=()
    local langs=("python3" "python" "node" "nodejs" "ruby" "php" "java" "go" "rustc" "cargo" "gcc" "g++" "clang")

    for lang in "${langs[@]}"; do
        if command -v "$lang" &>/dev/null; then
            LSO_LANGUAGES+=("$lang")
        fi
    done

    [[ ${#LSO_LANGUAGES[@]} -gt 0 ]] && _lso_log "Lenguajes detectados: ${LSO_LANGUAGES[*]}"
}

detect_containers() {
    LSO_CONTAINERS=()

    if command -v docker &>/dev/null; then
        LSO_CONTAINERS+=("docker")
    fi
    if command -v podman &>/dev/null; then
        LSO_CONTAINERS+=("podman")
    fi
    if command -v lxc &>/dev/null; then
        LSO_CONTAINERS+=("lxc")
    fi

    [[ ${#LSO_CONTAINERS[@]} -gt 0 ]] && _lso_log "Contenedores detectados: ${LSO_CONTAINERS[*]}"
}

detect_virtualization() {
    LSO_VIRTUALIZATION="none"

    if [[ -d /proc/xen ]] || [[ -f /proc/xen/capabilities ]]; then
        LSO_VIRTUALIZATION="Xen"
    elif [[ -f /proc/1/cgroup ]] && grep -q "docker" /proc/1/cgroup 2>/dev/null; then
        LSO_VIRTUALIZATION="Docker"
    elif command -v systemd-detect-virt &>/dev/null; then
        local detected_virt
        detected_virt=$(systemd-detect-virt 2>/dev/null)
        LSO_VIRTUALIZATION="${detected_virt:-none}"
    elif [[ -f /sys/class/dmi/id/product_name ]]; then
        local product
        product=$(cat /sys/class/dmi/id/product_name 2>/dev/null || echo "")
        if [[ "$product" == *"VMware"* ]]; then
            LSO_VIRTUALIZATION="vmware"
        elif [[ "$product" == *"VirtualBox"* ]]; then
            LSO_VIRTUALIZATION="oracle"
        elif [[ "$product" == *"KVM"* ]] || [[ "$product" == *"QEMU"* ]]; then
            LSO_VIRTUALIZATION="kvm"
        fi
    fi

    _lso_log "Virtualización: $LSO_VIRTUALIZATION"
}

run_full_detection() {
    if command -v print_header &>/dev/null; then
        print_header "DETECCIÓN DEL SISTEMA"
    else
        echo ""
        echo "=== DETECCIÓN DEL SISTEMA ==="
    fi

    detect_distro
    detect_desktop
    detect_package_manager
    detect_cpu
    detect_ram
    detect_gpu
    detect_disk_type
    detect_browsers
    detect_ides
    detect_languages
    detect_containers
    detect_virtualization

    LSO_IS_LAPTOP=$(is_laptop 2>/dev/null && echo "true" || echo "false")
    _lso_log "Es laptop: $LSO_IS_LAPTOP"

    if command -v print_success &>/dev/null; then
        print_success "Detección completada"
    else
        echo "✓ Detección completada"
    fi
}

export_detection_vars() {
    export LSO_DISTRO LSO_DISTRO_ID LSO_DISTRO_VERSION
    export LSO_DESKTOP LSO_PACKAGE_MANAGER
    export LSO_CPU_MODEL LSO_CPU_CORES LSO_CPU_THREADS
    export LSO_RAM_TOTAL LSO_RAM_AVAILABLE
    export LSO_GPU LSO_DISK_TYPE LSO_IS_LAPTOP
    export LSO_BROWSERS LSO_IDES LSO_LANGUAGES LSO_CONTAINERS LSO_VIRTUALIZATION
}
