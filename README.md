# Linux System Optimizer (LSO)

Framework modular y extensible para analizar, optimizar y mantener distribuciones GNU/Linux de forma segura.

## Autor

**Ricardo Rosero** — [rrosero2000@gmail.com](mailto:rrosero2000@gmail.com)  
GitHub: [@rr-n4p5t3r](https://github.com/rr-n4p5t3r)

## Características

- **Detección automática** de distribución, escritorio, hardware y software
- **23 distribuciones soportadas** (22 Linux + soporte experimental de FreeBSD — ver nota abajo)
- **Perfiles de optimización** preconfigurados (desktop, laptop, gaming, workstation, server, dev, docker, database)
- **Módulos independientes** que pueden ejecutarse por separado
- **Backups automáticos** antes de cualquier cambio permanente
- **Sistema de plugins** extensible
- **Logs detallados** de todas las operaciones
- **Restauración completa** de configuraciones
- **Auditoría de seguridad** (`lso audit`): 101 revisiones de solo lectura, puntaje de 1 a 10 y tablero interactivo en la terminal

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

# Optimizar con perfil dev (bases de datos, entornos virtuales, lenguajes)
sudo lso optimize --profile dev

# Optimizar un host de contenedores
sudo lso optimize --profile docker

# Optimizar un servidor dedicado de base de datos
sudo lso optimize --profile database

# Ejecutar módulo específico
sudo lso module memory_optimizer

# Ver información del sistema
sudo lso detect

# Simular optimización (sin aplicar cambios)
sudo lso optimize --dry-run
```

Para la referencia completa de comandos, opciones, perfiles y el motor de reglas, consulta la página de manual (instalada por `install.sh`, o localmente con `man ./man/lso.1`):

```bash
man lso
```

### Nota sobre FreeBSD y GPU

- **FreeBSD es soporte experimental.** No es una distro de Linux — es otro sistema operativo. LSO detecta FreeBSD y soporta su gestor de paquetes (`pkg`), pero la mayoría de los módulos del core (`service_manager`, `swap`, `zram`, `journal_optimizer`, `memory_optimizer`, `security`) son Linux-específicos y no funcionan ahí. En FreeBSD, usa `lso detect` y `lso module package_optimizer`, pero evita correr perfiles completos (`lso optimize`) por ahora.
- **`gpu_optimizer` es solo diagnóstico.** Reporta vendor, modelo y driver en uso, y sugiere en texto qué comando correr — nunca instala ni cambia drivers de GPU automáticamente. Cambiar el driver de una GPU puede romper la sesión gráfica, y ese riesgo no se automatiza en LSO.

## Auditoría de seguridad

`lso audit` revisa el sistema **sin cambiar nada** y lo califica de 1 a 10.
Cada hallazgo trae la corrección sugerida para que la apliques tú.

```bash
sudo lso audit                       # tablero interactivo
sudo lso audit --plain               # informe en texto
sudo lso audit --json --output informe.json
sudo lso audit --fast                # omite las revisiones que recorren el disco
sudo lso audit --min-score 7         # código 1 si el puntaje es menor (cron/CI)
```

- **101 revisiones** en 9 categorías: cuentas, SSH, red, sistema de archivos,
  endurecimiento, persistencia, actualizaciones, credenciales expuestas y
  servicios. Catálogo completo en [docs/audit-checks.md](docs/audit-checks.md).
- **Puntaje con topes**: un hallazgo crítico abierto limita el puntaje a 6/10,
  aunque todo lo demás esté bien. El informe dice qué tope se aplicó.
- **Perfiles**: escritorio, servidor o contenedor (se detecta solo). Ajustan la
  gravedad de lo que no aplica igual en cada caso, sin ocultar revisiones.
- **Excepciones**: los riesgos aceptados van en `/etc/lso/audit-waivers.conf`
  (`ID  # motivo`); siguen en el informe, pero no restan.
- **Sin root** también funciona: lo que requiere permisos queda como "no
  evaluable" y el puntaje tiene un tope de 6/10.
- Los secretos nunca se muestran: solo el archivo y la línea.

Inspirado en [linaudit](https://github.com/alexiarstein/linaudit); implementación
propia en Bash, sin dependencias.

## Pruebas

```bash
bash tests/run.sh            # toda la suite
bash tests/run.sh audit      # solo las de un grupo (filtro por nombre)
```

## Arquitectura

```
linux-system-optimizer/
├── optimizer.sh          # Entry point
├── core/                 # Motor principal
│   ├── engine.sh         # Orquestador de módulos
│   ├── detector.sh       # Detección automática
│   ├── dispatcher.sh     # Enrutador de comandos
│   ├── plugin_loader.sh  # Cargador de plugins
│   └── rule_engine.sh    # Motor de reglas condicionales
├── lib/                  # Librerías base
│   ├── colors.sh         # Colores y formato
│   ├── logger.sh         # Sistema de logging
│   ├── utils.sh          # Utilidades generales
│   └── ...
├── modules/              # Módulos de optimización
│   └── audit/            # Auditoría de seguridad (lso audit)
│       ├── checks/       # Revisiones, un archivo por categoría
│       └── render_*.sh   # Salidas: tablero, texto y JSON
├── tests/                # Pruebas (bash tests/run.sh)
├── docs/                 # Documentación (catálogo de revisiones, diseño)
├── distros/              # Scripts específicos por distro
├── desktops/             # Scripts específicos por escritorio
├── config/               # Configuraciones, perfiles y reglas
├── man/                  # Página de manual (man lso)
└── plugins/              # Plugins de terceros
```

## Licencia

GNU General Public License v3.0 (GPLv3) — ver archivo LICENSE

Software libre: puedes usarlo, estudiarlo, modificarlo y redistribuirlo. Si
distribuyes una versión modificada, debes liberarla también bajo GPLv3, con
el código fuente disponible.

---

Desarrollado con ❤️ por [Ricardo Rosero](https://github.com/rr-n4p5t3r)
