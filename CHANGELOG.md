# Changelog

Todos los cambios notables de este proyecto serán documentados aquí.

## [0.3.0-alpha] - 2026-07-29

Amplía distros, gestores de paquetes, módulos y perfiles siguiendo el roadmap
publicado por el autor. Compara ese roadmap contra el estado real del
proyecto: varios ítems ya estaban resueltos (reportes, logs, perfil `dev`,
infraestructura de plugins) y se descartaron de esta ronda; el resto —lo que
sí era trabajo nuevo— se implementó acá.

### Añadido — Distros y gestores de paquetes
- **7 distros nuevas**: Kali, Gentoo, Void Linux, Slackware, RHEL, Amazon
  Linux (todas Linux) y **FreeBSD** (soporte **experimental**, ver
  limitación abajo). Total: 23 distros (openSUSE ya estaba soportado desde
  antes, no se contó como nueva).
- **4 gestores de paquetes nuevos**: `package_managers/portage.sh` (Gentoo),
  `xbps.sh` (Void), `slackpkg.sh` (Slackware, sin equivalente real de
  autoremove — Slackware no rastrea dependencias, se documenta con
  `log_warn`), `pkg.sh` (FreeBSD).
- `core/detector.sh`: detección de los 6 IDs de distro Linux nuevos, de los
  4 gestores de paquetes nuevos, y **detección real de FreeBSD** (que no
  tiene `/etc/os-release` en la instalación base, se detecta vía
  `uname -s`), con fallback a `sysctl` para CPU/RAM cuando `/proc` no existe.

### Añadido — Módulos nuevos
- **`modules/bluetooth_optimizer.sh`**: reporta dispositivos emparejados: si
  el servicio está activo pero no hay ninguno, ofrece deshabilitarlo.
- **`modules/power_optimizer.sh`**: si TLP está instalado, asegura que esté
  activo; si powertop está instalado, ofrece `powertop --auto-tune`. No
  instala ninguno de los dos si no están presentes — igual que el resto de
  LSO, solo ajusta software que el usuario ya tiene.
- **`modules/gpu_optimizer.sh`** — **solo diagnóstico, deliberadamente**:
  reporta vendor/modelo/driver en uso y sugiere en texto el comando a correr
  manualmente si hay un driver propietario disponible. **Nunca instala ni
  cambia drivers de GPU automáticamente** — automatizar eso puede romper la
  sesión gráfica, y ese riesgo no vale la pena ni con confirmación. Auditado
  manualmente: no contiene ningún comando de instalación/cambio de driver.
- **`modules/virtualization_optimizer.sh`** (KVM): reporta `/dev/kvm` y
  estado de `libvirtd`; ofrece iniciarlo y agregar al usuario invocador a
  los grupos `libvirt`/`kvm`; ajusta `vm.nr_hugepages` con el mismo patrón
  de backup que `memory_optimizer.sh`.
- Los 4 se agregaron a los perfiles donde tienen sentido: `bluetooth_optimizer`
  y `gpu_optimizer` en `desktop`/`laptop`/`gaming`/`workstation`;
  `power_optimizer` en `laptop`; `virtualization_optimizer` en `workstation`
  y `dev`.

### Añadido — Perfiles Docker y Base de Datos
- **`modules/docker_optimizer.sh`** + **`config/profiles/docker.conf`**:
  reporta uso de disco (`docker/podman system df`) y ofrece limpiar
  contenedores/redes/imágenes *dangling* no usados. La limpieza de
  **volúmenes** requiere una **segunda confirmación separada y explícita**,
  dejando claro que implica posible pérdida de datos — nunca se limpia junto
  con lo demás por defecto.
- **`modules/database_optimizer.sh`** + **`config/profiles/database.conf`**:
  detecta y ofrece iniciar motores de BD instalados (MySQL/MariaDB,
  PostgreSQL, MongoDB, Redis — mismo patrón que ya usa `dev_environment.sh`)
  y ajusta parámetros de kernel específicos para cargas de base de datos
  (`vm.swappiness` muy bajo, `vm.dirty_ratio`/`vm.dirty_background_ratio`,
  opcionalmente `kernel.shmmax`/`shmall`).

### Limitaciones conocidas (documentadas a propósito, no son bugs)
- **FreeBSD es soporte experimental.** No es una distro de Linux — es otro
  SO (sin systemd, sin `/proc`/`/sys`). Se detecta correctamente y se
  soporta su gestor de paquetes (`pkg`), pero la mayoría de los módulos del
  core (`service_manager`, `swap`, `zram`, `journal_optimizer`,
  `memory_optimizer`, `security`) son Linux-específicos y no se portaron en
  esta ronda — no se recomienda correr perfiles completos en FreeBSD todavía.
- **`gpu_optimizer` es solo diagnóstico**, nunca instala ni cambia drivers
  de GPU. Ver detalle arriba.

### Corregido
- **`.gitignore` / cabeceras de licencia**: el reemplazo masivo MIT→GPLv3 de
  la versión anterior solo cubrió archivos `.sh`; quedaron 14 archivos
  `.conf`/`.rules` con `# Licencia: MIT` sin actualizar
  (`config/settings.conf`, `config/whitelist.conf`, `config/blacklist.conf`,
  y los `.conf`/`.rules` de `config/profiles/` y `config/rules/`).
  Corregido.

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

### Añadido (continuación)
- **`.github/workflows/ci.yml`**: CI en GitHub Actions (push y pull request
  a `main`) que corre `bash -n` y `shellcheck --severity=warning` sobre
  todos los `.sh` del repo — las mismas verificaciones que se venían
  haciendo a mano durante esta sesión.
- **`.github/dependabot.yml`**: en vez de la plantilla genérica de GitHub
  (que pedía un `package-ecosystem` inventado — LSO no tiene
  `package.json`/`requirements.txt`/`Gemfile` ni ningún otro manifiesto de
  dependencias, es Bash puro), se configuró `package-ecosystem:
  "github-actions"`, el único ecosistema real del repo: mantiene
  actualizadas las Actions usadas en `ci.yml` (`actions/checkout`).
- **`.github/SECURITY.md`**: política de seguridad real, en lugar de la
  plantilla genérica de GitHub. Ajustada al estado del proyecto (fase
  alpha, un solo mantenedor, sin versiones paralelas que mantener) y al
  hecho de que LSO corre como root y modifica el sistema — prioriza
  reportes de inyección de comandos, escalado de privilegios y escritura
  insegura de archivos. Habilita el botón "Report a vulnerability" de
  GitHub (Private Vulnerability Reporting).

### Cambiado
- **Licencia: MIT → GPLv3**. `LICENSE` ahora contiene el texto oficial y
  verbatim de la GNU General Public License v3.0 (obtenido directamente de
  `gnu.org`, sin resumir ni parafrasear). Actualizado en `VERSION`,
  `README.md`, `man/lso.1` (nueva sección `LICENCIA`) y en la cabecera
  `# Licencia:` de los 34 scripts que la mencionaban. A diferencia de MIT,
  GPLv3 es copyleft: las versiones modificadas que se distribuyan deben
  liberarse también bajo GPLv3 con el código fuente disponible.

### Corregido (ShellCheck / primera corrida de CI)
Hallazgos reales del primer run de `.github/workflows/ci.yml` en GitHub.
- **`modules/analyzer.sh` (SC2071, bug real)**: el color de la RAM se
  decidía con `[[ "$ram_percent" > "85" ]]`, una comparación de **strings**
  dentro de `[[ ]]`, no numérica. Con un valor como `"9.5"`, la comparación
  de strings da `"9.5" > "85"` = verdadero (`'9' > '8'` lexicográficamente),
  pintando de rojo un uso de RAM del 9.5%. Corregido comparando con `awk`,
  igual que ya se hace en el resto del archivo.
- **`distros/{arch,manjaro,endeavouros}.sh` (mismo bug de comillas anidadas
  encontrado antes en esta versión, esta vez en el ajuste de `MAKEFLAGS`)**:
  `sed -i "s/.../MAKEFLAGS="-j$(nproc)"/"` perdía las comillas internas por
  el mismo motivo que los bugs de `awk` ya corregidos — el resultado en
  `/etc/makepkg.conf` quedaba como `MAKEFLAGS=-j4` en vez de
  `MAKEFLAGS="-j4"`. Arch tenía el bug desde antes de esta sesión; Manjaro y
  EndeavourOS lo heredaron al copiar su estructura. Corregido escapando las
  comillas internas en los 3 archivos.
- **`modules/zram.sh` (SC2046)**: ruta de destino de una redirección sin
  comillas (`/sys/block/$(basename ...)/disksize`), vulnerable a
  word-splitting. Corregido citando la ruta completa.
- **`package_managers/zypper.sh` (SC2046)**: `zypper rm $(...)` sin comillas
  dependía de word-splitting para pasar varios paquetes como argumentos
  separados — funcionaba pero de forma fragil. Reescrito con `mapfile` y un
  array, más robusto y sin depender de `IFS`.
- **Variables muertas eliminadas**: `prefs` en `browser_optimizer.sh`,
  `dm_name` en `detector.sh`, `avail` en `analyzer.sh` — declaradas pero
  nunca usadas.
- **`modules/process_manager.sh`**: `LSO_CANDIDATE_PROCESES` estaba
  declarada pero nunca se usaba — el loop de `renice` tenía una lista
  hardcodeada de solo 4 de los 12 procesos candidatos. Ahora itera sobre el
  array completo. `LSO_CRITICAL_PROCESSES` queda documentada con
  `shellcheck disable=SC2034`: ningún punto de este módulo mata procesos
  por nombre todavía (solo zombies), así que no hay donde consultarla hoy;
  se deja como referencia para módulos futuros.
- **SC2155 (declare-and-assign)** en `lib/utils.sh`, `modules/report.sh` y
  `modules/analyzer.sh`: variables `local` separadas de su asignación con
  `$(...)`, para no enmascarar el código de salida del subcomando.
- **SC1090 (source dinámico) y SC2034 (falsos positivos de variables no
  usadas)**: no son bugs sino inherentes a la arquitectura del proyecto —
  9 sitios hacen `source` de una ruta calculada en tiempo de ejecución
  (carga de módulos/perfiles/plugins/distros/escritorios por nombre), y
  varias variables (flags de `dispatcher.sh`, paleta de `colors.sh`) se
  usan en otros archivos `sourced` dentro del mismo shell, no en el propio
  archivo. Documentados explícitamente con directivas
  `# shellcheck source=/dev/null` y `# shellcheck disable=SC2034` en cada
  sitio, en vez de ocultarlos con un umbral de severidad más alto.

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
