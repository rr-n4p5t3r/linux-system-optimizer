#!/usr/bin/env bash
# =============================================================================
# install.sh — Instalador de Linux System Optimizer
# =============================================================================
# Autor: Ricardo Rosero <rrosero2000@gmail.com>
# GitHub: https://github.com/rr-n4p5t3r
# =============================================================================

set -euo pipefail

INSTALL_DIR="/opt/linux-system-optimizer"
BIN_LINK="/usr/local/bin/lso"

echo "╔══════════════════════════════════════════════════════════════════════════════╗"
echo "║           LINUX SYSTEM OPTIMIZER — Instalador                                ║"
echo "╚══════════════════════════════════════════════════════════════════════════════╝"
echo

if [[ $EUID -ne 0 ]]; then
    echo "❌ Este instalador requiere privilegios de root."
    echo "   Ejecuta: sudo ./install.sh"
    exit 1
fi

echo "📋 Verificando dependencias..."
DEPS=("bash" "awk" "sed" "grep" "cat" "free" "df" "ps" "systemctl" "readlink" "whoami" "date" "uptime" "uname" "findmnt" "dd" "ping")
MISSING=()

for dep in "${DEPS[@]}"; do
    if ! command -v "$dep" &>/dev/null; then
        MISSING+=("$dep")
    fi
done

if [[ ${#MISSING[@]} -gt 0 ]]; then
    echo "⚠️  Dependencias opcionales faltantes: ${MISSING[*]}"
    echo "   Algunas funciones pueden no estar disponibles."
fi

echo "✅ Dependencias principales satisfechas"

echo "📁 Instalando en: $INSTALL_DIR"

if [[ -d "$INSTALL_DIR" ]]; then
    echo "⚠️  El directorio $INSTALL_DIR ya existe."
    read -rp "¿Deseas sobrescribir? [s/N]: " response
    if [[ ! "$response" =~ ^[Ss]$ ]]; then
        echo "❌ Instalación cancelada"
        exit 0
    fi
    rm -rf "$INSTALL_DIR"
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cp -r "$SCRIPT_DIR" "$INSTALL_DIR"

if [[ -L "$BIN_LINK" ]]; then
    rm -f "$BIN_LINK"
fi
ln -sf "$INSTALL_DIR/optimizer.sh" "$BIN_LINK"

echo "🔧 Ajustando permisos..."
find "$INSTALL_DIR" -name "*.sh" -exec chmod +x {} \;

for dir in logs backups reports; do
    mkdir -p "$INSTALL_DIR/$dir"
    chmod 777 "$INSTALL_DIR/$dir"
done

mkdir -p "$INSTALL_DIR/plugins"
chmod 755 "$INSTALL_DIR/plugins"
chmod 755 "$INSTALL_DIR"
chmod -R 755 "$INSTALL_DIR/config"
chmod -R 755 "$INSTALL_DIR/core"
chmod -R 755 "$INSTALL_DIR/lib"
chmod -R 755 "$INSTALL_DIR/modules"
chmod -R 755 "$INSTALL_DIR/distros"
chmod -R 755 "$INSTALL_DIR/desktops"
chmod -R 755 "$INSTALL_DIR/package_managers"

echo "🔍 Verificando instalación..."
if [[ -L "$BIN_LINK" ]] && [[ -x "$BIN_LINK" ]]; then
    echo "✅ Enlace simbólico creado correctamente"
else
    echo "❌ Error creando el enlace simbólico"
    exit 1
fi

if [[ -w "$INSTALL_DIR/logs" ]]; then
    echo "✅ Directorio de logs tiene permisos de escritura"
else
    echo "⚠️  Advertencia: El directorio de logs no tiene permisos de escritura"
fi

echo
echo "✅ Linux System Optimizer instalado correctamente"
echo
echo "📖 Uso:"
echo "   sudo lso analyze          # Analizar sistema"
echo "   sudo lso optimize           # Optimizar con perfil desktop"
echo "   sudo lso optimize --profile gaming"
echo "   sudo lso detect             # Ver información del sistema"
echo "   sudo lso -h                 # Ayuda completa"
echo
echo "🗂️  Instalado en: $INSTALL_DIR"
echo "🔗 Comando: lso"
echo
echo "👤 Autor: Ricardo Rosero"
echo "📧 Email: rrosero2000@gmail.com"
echo "🔗 GitHub: https://github.com/rr-n4p5t3r"
echo
echo "💡 Nota: Si lso no funciona, ejecuta: hash -r"
