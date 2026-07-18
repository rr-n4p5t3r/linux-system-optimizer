#!/usr/bin/env bash
# =============================================================================
# uninstall.sh — Desinstalador de Linux System Optimizer
# =============================================================================
# Autor: Ricardo Rosero <rrosero2000@gmail.com>
# GitHub: https://github.com/rr-n4p5t3r
# =============================================================================

set -euo pipefail

INSTALL_DIR="/opt/linux-system-optimizer"
BIN_LINK="/usr/local/bin/lso"

echo "╔══════════════════════════════════════════════════════════════════════════════╗"
echo "║           LINUX SYSTEM OPTIMIZER — Desinstalador                             ║"
echo "╚══════════════════════════════════════════════════════════════════════════════╝"
echo

if [[ $EUID -ne 0 ]]; then
    echo "❌ Este desinstalador requiere privilegios de root."
    echo "   Ejecuta: sudo ./uninstall.sh"
    exit 1
fi

if [[ ! -d "$INSTALL_DIR" ]]; then
    echo "⚠️  LSO no parece estar instalado en $INSTALL_DIR"
    read -rp "¿Deseas eliminar el enlace $BIN_LINK de todos modos? [s/N]: " response
    if [[ "$response" =~ ^[Ss]$ ]]; then
        rm -f "$BIN_LINK" 2>/dev/null || true
        echo "✅ Enlace eliminado"
    fi
    exit 0
fi

echo "⚠️  Esto eliminará:"
echo "   • $INSTALL_DIR"
echo "   • $BIN_LINK"
echo "   • Backups en $INSTALL_DIR/backups"
echo "   • Logs en $INSTALL_DIR/logs"
echo "   • Reportes en $INSTALL_DIR/reports"
echo

read -rp "¿Deseas continuar? [s/N]: " response
if [[ ! "$response" =~ ^[Ss]$ ]]; then
    echo "❌ Desinstalación cancelada"
    exit 0
fi

if [[ -d "$INSTALL_DIR/backups" ]] && [[ "$(ls -A "$INSTALL_DIR/backups" 2>/dev/null)" ]]; then
    BACKUP_SAVE="/tmp/lso-backups-$(date +%s)"
    mkdir -p "$BACKUP_SAVE"
    cp -r "$INSTALL_DIR/backups"/* "$BACKUP_SAVE"/ 2>/dev/null || true
    echo "📦 Backups guardados en: $BACKUP_SAVE"
fi

rm -rf "$INSTALL_DIR"
rm -f "$BIN_LINK"

echo
echo "✅ Linux System Optimizer desinstalado correctamente"
echo
echo "📝 Nota: Las configuraciones del sistema modificadas por LSO"
echo "   NO se restauran automáticamente. Usa 'lso restore' antes de"
echo "   desinstalar si deseas revertir los cambios."
echo
echo "👤 Autor: Ricardo Rosero"
echo "📧 Email: rrosero2000@gmail.com"
echo "🔗 GitHub: https://github.com/rr-n4p5t3r"
