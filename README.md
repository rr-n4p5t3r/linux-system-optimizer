# Linux System Optimizer (LSO)

Framework modular y extensible para analizar, optimizar y mantener distribuciones GNU/Linux de forma segura.

## Autor

**Ricardo Rosero** — [rrosero2000@gmail.com](mailto:rrosero2000@gmail.com)  
GitHub: [@rr-n4p5t3r](https://github.com/rr-n4p5t3r)

## Características

- **Detección automática** de distribución, escritorio, hardware y software
- **Perfiles de optimización** preconfigurados (desktop, laptop, gaming, workstation, server)
- **Módulos independientes** que pueden ejecutarse por separado
- **Backups automáticos** antes de cualquier cambio permanente
- **Sistema de plugins** extensible
- **Logs detallados** de todas las operaciones
- **Restauración completa** de configuraciones

## Requisitos

- Bash 4.0+
- Privilegios de root (para módulos que modifican el sistema)
- Dependencias: `awk`, `sed`, `grep`, `free`, `df`, `systemctl`

## Instalación

```bash
git clone https://github.com/rr-n4p5t3r/linux-system-optimizer.git
cd linux-system-optimizer
chmod +x install.sh
sudo ./install.sh
```

## Uso

```bash
# Analizar el sistema
sudo lso analyze

# Optimizar con perfil desktop
sudo lso optimize

# Optimizar con perfil gaming
sudo lso optimize --profile gaming

# Ejecutar módulo específico
sudo lso module memory_optimizer

# Ver información del sistema
sudo lso detect

# Simular optimización (sin aplicar cambios)
sudo lso optimize --dry-run
```

## Arquitectura

```
linux-system-optimizer/
├── optimizer.sh          # Entry point
├── core/                 # Motor principal
│   ├── engine.sh         # Orquestador de módulos
│   ├── detector.sh       # Detección automática
│   ├── dispatcher.sh     # Enrutador de comandos
│   └── plugin_loader.sh # Cargador de plugins
├── lib/                  # Librerías base
│   ├── colors.sh         # Colores y formato
│   ├── logger.sh         # Sistema de logging
│   ├── utils.sh          # Utilidades generales
│   └── ...
├── modules/              # Módulos de optimización
├── distros/              # Scripts específicos por distro
├── desktops/             # Scripts específicos por escritorio
├── config/               # Configuraciones y perfiles
└── plugins/              # Plugins de terceros
```

## Licencia

MIT License — ver archivo LICENSE

---

Desarrollado con ❤️ por [Ricardo Rosero](https://github.com/rr-n4p5t3r)
