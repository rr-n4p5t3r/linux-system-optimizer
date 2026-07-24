# Changelog

Todos los cambios notables de este proyecto serán documentados aquí.

## [0.2.0-alpha] - 2026-07-24

Implementa piezas que estaban documentadas en el diseño original del proyecto
pero nunca se terminaron de construir o quedaron desconectadas del flujo real.

### Añadido
- **Motor de reglas conectado al flujo real**: `core/rule_engine.sh` existía
  pero no se cargaba desde `optimizer.sh` ni se invocaba desde ningún otro
  archivo — los 5 `.rules` de `config/rules/` no tenían efecto. Ahora se
  carga en `optimizer.sh`, se ejecuta automáticamente al final de
  `lso optimize` (después de los módulos del perfil, antes del reporte), y
  se agregó el comando `lso rules` para evaluarlo de forma aislada
  (`sudo lso rules --dry-run`).
- **`modules/startup_manager.sh`**: gestiona aplicaciones de autoarranque
  (`~/.config/autostart/*.desktop`), listándolas y ofreciendo deshabilitar
  las no esenciales (con confirmación por ítem, igual que
  `service_manager.sh`). Agregado a los perfiles `desktop`, `laptop`,
  `gaming` y `workstation`.
- **`modules/package_optimizer.sh`**: reutiliza las funciones ya existentes
  en `package_managers/{apt,dnf,pacman,zypper}.sh`. En los perfiles
  automáticos solo hace limpieza segura (`clean` + `autoremove`); la
  actualización completa del sistema (`upgrade`) solo corre con la nueva
  flag `--full` (`sudo lso module package_optimizer --full`), nunca de
  forma automática. Agregado a los 5 perfiles.
- **`distros/manjaro.sh`** y **`distros/endeavouros.sh`**: las dos distros
  que el documento de diseño listaba como "soporte futuro" y nunca se
  implementaron. `core/detector.sh` ya reconocía `manjaro` pero no
  `endeavouros` (agregado); `config/rules/distro.rules` ahora cubre las 16
  distros documentadas.
- **`man/lso.1`**: página de manual completa (formato `groff`/`man(7)`) con
  comandos, opciones, perfiles y sintaxis del motor de reglas. `install.sh`
  la instala en `/usr/share/man/man1` (o `/usr/local/share/man/man1`) y
  ejecuta `mandb`/`makewhatis` si están disponibles, para que `man lso`
  funcione tras instalar.
- Nueva flag global `--full`, documentada en `lso -h` y en la página de
  manual.
- **Perfil `dev`** (`config/profiles/dev.conf`), para estaciones de
  desarrollo: `analyzer`, `memory_optimizer`, `cpu_optimizer`,
  `process_manager`, `service_manager`, `startup_manager`, el nuevo módulo
  `dev_environment`, `cache_cleaner` y `package_optimizer`.
- **`modules/dev_environment.sh`**: ajusta `fs.inotify.max_user_watches`
  (límite que VS Code, webpack y herramientas similares suelen agotar en una
  máquina de desarrollo), detecta motores de base de datos instalados
  (MySQL/MariaDB, PostgreSQL, MongoDB, Redis) y ofrece iniciarlos y
  habilitarlos con confirmación por servicio (nunca automático), y reporta
  herramientas de entornos virtuales/gestores de versiones presentes (venv,
  conda, pyenv, nvm, rbenv, rvm, docker, podman). Configurable vía
  `LSO_DEV_START_DATABASES`, `LSO_DEV_INCREASE_INOTIFY` y
  `LSO_DEV_INOTIFY_WATCHES` en `config/profiles/dev.conf`.
- `sudo lso optimize --profile dev` documentado en `lso -h`, `README.md` y
  `man/lso.1` (sección `PERFILES`, con ejemplo en `EJEMPLOS` y las variables
  de `dev.conf` referenciadas en `ARCHIVOS`).

### Corregido
- **`core/rule_engine.sh` — split de condiciones `&&` roto**: usaba
  `IFS='&&' read -ra parts <<< "$condition"`, pero `IFS` es un *conjunto* de
  caracteres, no un separador de string — equivalía a partir por cada `&`
  individual y generaba un campo vacío entre los dos `&`. Ese campo vacío
  hacía que la condición completa evaluara siempre `false`, así que
  **ninguna regla con `&&` se activaba jamás** (afectaba `cpu.rules` y
  `memory.rules`), sin importar si la condición real era verdadera.
  Confirmado antes y después con una prueba aislada de
  `evaluate_condition()`.
- **`core/rule_engine.sh` — valor de condición truncado**: `evaluate_condition()`
  solo tomaba el 3er token como valor, así que `load_average > cores * 2`
  descartaba silenciosamente `* 2`. Ahora captura todo lo que sigue al
  operador y sustituye la referencia simbólica `cores` por `LSO_CPU_CORES`
  antes de evaluar.
- **`core/rule_engine.sh` — sufijos de tamaño no soportados**: condiciones
  como `ram_total < 4GB` o `browser_cache > 1GB` fallaban en el `awk` de
  comparación porque `4GB`/`1GB` no son números. Ahora se normalizan a GB
  antes de comparar.
- **`core/rule_engine.sh` — variable y acción faltantes**: no existía la
  variable `browser_cache` (usada en `browser.rules`, caía siempre a vacío)
  ni la acción `clean_browser_cache` (cadía en "Acción desconocida"). Ambas
  implementadas.
- **`core/rule_engine.sh` — acciones `optimize_firefox`/`optimize_chromium`
  eran no-ops**: usaban el patrón genérico `optimize_*`, que busca
  `modules/firefox_optimizer.sh`, `distros/firefox.sh` o
  `desktops/firefox.sh` — ninguno existe. Ahora se mapean explícitamente a
  `modules/browser_optimizer.sh`, que ya contiene la lógica real.
- **`core/engine.sh` — `memory_optimizer` dejaba de tener efecto perceptible
  al final de `lso optimize`**: en todos los perfiles corría 2do en la lista
  (justo después de `analyzer`), vaciando la caché de página del kernel muy
  temprano. El resto de módulos que corrían después — y, desde que se
  conectó el motor de reglas en esta misma versión, también sus acciones
  (re-escaneo de cachés de navegador con `du -sb` para la variable
  `browser_cache`, re-aplicación de scripts de distro/escritorio, y
  `package_optimizer`/`startup_manager`, nuevos en 0.2.0) generan bastante
  E/S de disco, que el kernel vuelve a reclamar como caché de página. El
  resultado: al terminar la optimización completa, el uso de RAM volvía a
  verse alto, aunque `memory_optimizer` sí había liberado memoria en su
  momento — el orden de ejecución, no el módulo, era el problema. Ya
  ocurría en 0.1.0 (mismo orden), pero pasaba desapercibido porque corrían
  muchos menos módulos después. Corregido moviendo `memory_optimizer` para
  que corra al final de `run_optimization()`, después del motor de reglas y
  justo antes del reporte, en los 6 perfiles.
- **Parseo de `free` sensible al locale**: en sistemas con locale no-inglés,
  la fila de swap de `free` no siempre se llama `Swap:` en la salida
  formateada por columnas, así que `awk '/^Swap:/'` no matcheaba y
  `swap_usage`/`swap_total`/`swap_used` quedaban vacíos — esto rompía la
  comparación aritmética del motor de reglas (`awk: syntax error`) en
  cuanto se conectó al flujo real. Corregido forzando `LC_ALL=C` en las
  llamadas a `free` de `core/rule_engine.sh` y `modules/swap.sh`.

## [0.1.1-alpha] - 2026-07-24

### Corregido
- **core/rule_engine.sh**: error de sintaxis fatal en `evaluate_condition()` — los patrones `>`, `<`, `>=`, `<=` del `case "$op"` no estaban entrecomillados, y bash los interpretaba como operadores de redirección en vez de literales. El archivo no podía ni siquiera parsearse (`bash -n` fallaba). Ahora los patrones van entre comillas (`">"`, `"<"`, `">="`, `"<="`).
- **modules/analyzer.sh**: error de comillas anidadas en tres llamadas a `awk "BEGIN {printf "%.1f", ...}"` (cálculo de `cpu_percent`, `ram_percent` y `temp_c`). Al no escapar las comillas internas, bash cerraba la cadena antes de tiempo y `awk` recibía `printf %.1f, ...` sin comillas alrededor del formato, lo que producía `awk: syntax error` en cada ejecución y dejaba esos valores vacíos en el análisis. Corregido escapando las comillas internas (`\"%.1f\"`), igual que ya se hacía correctamente en `lib/utils.sh`.
- **core/rule_engine.sh**: mismo bug de comillas anidadas en el cálculo de `cpu_usage` dentro de `evaluate_condition()`.
- **core/detector.sh**: `detect_virtualization()` devolvía el valor duplicado `"none\nnone"` cuando no había virtualización. Causa: `systemd-detect-virt` imprime `none` en stdout pero termina con código de salida `1`, por lo que el fallback `|| echo "none"` también se ejecutaba y ambas salidas quedaban concatenadas en `LSO_VIRTUALIZATION`. Esto rompía cualquier comparación posterior contra ese valor (p. ej. reglas del motor de reglas, resumen de `lso detect`). Corregido capturando la salida por separado y aplicando el fallback solo si está vacía.

## [0.1.0-alpha] - 2026-07-18

### Añadido
- Motor de detección automática del sistema (distro, escritorio, hardware, software)
- Motor de ejecución de módulos con perfiles (desktop, laptop, gaming, workstation, server)
- Sistema de logging con rotación automática y fallback a /tmp
- Sistema de backups antes de cambios permanentes con fallback a /tmp
- Sistema de plugins extensible
- 18 módulos de optimización
- Soporte para 14 distribuciones y 8 escritorios
- 4 gestores de paquetes: APT, DNF, Pacman, Zypper
- Modo dry-run para simular cambios
- Confirmaciones interactivas antes de cambios permanentes
- Reportes detallados en HTML y texto plano
- Script de instalación y desinstalación

### Autor
- Ricardo Rosero <rrosero2000@gmail.com>
- GitHub: https://github.com/rr-n4p5t3r
