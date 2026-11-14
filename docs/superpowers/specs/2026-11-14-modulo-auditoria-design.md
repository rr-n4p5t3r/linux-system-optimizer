# Módulo de auditoría de seguridad (`lso audit`) — Diseño

Fecha: 2026-11-14 · Estado: aprobado (plan de 4 fases)

## 1. Intención

Agregar a LSO un módulo de auditoría de seguridad inspirado en
[linaudit](https://github.com/alexiarstein/linaudit). Debe revisar el sistema,
dar un puntaje de 1 a 10 y mostrar un tablero interactivo en consola con
resumen, hallazgos y categorías.

**Para qué:** revisar los equipos propios y también los de clientes, a veces
de forma automática (cron o monitoreo). Por eso tiene que:

- correr en servidores ajenos sin instalar nada (solo Bash y coreutils, igual que el resto de LSO);
- ser de **solo lectura**, sin modificar nunca el sistema auditado;
- producir un informe entregable (texto o JSON) además del tablero.

## 2. Objetivos, no-objetivos y antiobjetivos

**Objetivos**
- Comando `lso audit` con tablero TUI, salida `--plain` y salida `--json`.
- Puntaje de 1 a 10 con topes por hallazgos graves, que explique qué tope se aplicó.
- Revisiones con ID estable (`SSH-001`), gravedad, categoría, detalle y corrección sugerida.
- Gravedad ajustada según el perfil (servidor, escritorio o contenedor).
- Excepciones (riesgos aceptados) con su motivo.
- Revisiones que se pueden probar sin root, con archivos de prueba.

**No-objetivos**
- Corregir automáticamente. LSO tiene otros módulos que modifican el sistema; este no.
- Cumplimiento CIS/STIG, forense o EDR.
- FreeBSD (se marca como no soportado en esta versión).

**Antiobjetivos** (fallaría aunque "funcione")
- Que `--json` salga mezclado con banners o mensajes de log.
- Que una revisión que no se pudo evaluar cuente como aprobada.
- Que se muestre el valor de un secreto encontrado (solo archivo y línea).
- Copiar código o textos de linaudit (AGPL-3.0). Implementación propia.

## 3. Restricciones

- Bash ≥ 4.4 y coreutils/procps/iproute2. `jq`, `ss`, `systemctl` y `sshd` son opcionales: si faltan, la revisión queda como *no evaluable*.
- Licencia GPLv3, cabeceras como en el resto del proyecto.
- El CI corre `bash -n` y `shellcheck --severity=warning` sobre todo `*.sh`.
- Textos de UI en español neutro de Colombia, con tuteo.

## 4. Enfoques considerados

| Enfoque | Ventaja | Costo | Decisión |
|---|---|---|---|
| **A. Tablero en Bash puro** (ANSI/tput, `read -rsn1`) | Sin dependencias, corre en cualquier servidor de cliente | El dibujo es lo más laborioso | **Elegido** |
| B. `dialog`/`whiptail` | Rápido | No permite gráficos de barras ni el anillo; no se parece a lo pedido | Descartado |
| C. Visor aparte en Python o Go que lee el JSON | El tablero más pulido | Dependencia extra o binario por arquitectura | Posible a futuro |

Como las revisiones y el dibujo están separados, el enfoque C se puede agregar
después sin rehacer las revisiones.

## 5. Diseño

### 5.1 Integración con LSO

- `optimizer.sh` detecta `audit` como **primer argumento** antes de imprimir
  el banner. En ese caso carga libs y core, corre la detección en silencio
  (`run_full_detection >/dev/null 2>&1`) y entrega el control a
  `modules/audit/audit.sh`. Así ni `--json` ni el TUI se ensucian.
- `lso help` documenta el comando `audit`.
- `lso module security` sigue igual (no se toca).

### 5.2 Estructura

```
modules/audit/
  audit.sh          ← punto de entrada: argumentos, orquesta y elige la salida
  engine.sh         ← registro y ejecución de revisiones, resultados
  score.sh          ← puntaje y topes
  profiles.sh       ← clase de perfil y ajustes de gravedad
  waivers.sh        ← excepciones
  helpers.sh        ← lectura de archivos con raíz configurable, sshd, sysctl…
  checks/<cat>.sh   ← una categoría por archivo
  render_plain.sh
  render_json.sh
  render_tui.sh     ← fase 2
tests/
  run.sh            ← corredor de pruebas propio (sin bats)
  lib.sh            ← asserts
  fixtures/…        ← árboles de archivos falsos
  test_*.sh
```

### 5.3 Modelo de una revisión

Registro:
```bash
audit_register ID GRAVEDAD CATEGORIA "Título" funcion "Corrección sugerida"
```
La función de la revisión llama exactamente una de:
`audit_pass "detalle"`, `audit_fail "detalle"`, `audit_warn "detalle"`,
`audit_skip "motivo"` (no evaluable, p. ej. requiere root) o
`audit_na "motivo"` (no aplica).

Estados: `PASS`, `FAIL`, `WARN`, `SKIP`, `NA`, `WAIVED`.
Gravedades: `critical`, `high`, `medium`, `low`, `info`.

Los resultados se guardan en arreglos asociativos indexados por ID. Las
revisiones leen archivos como `"${AUDIT_ROOT}/etc/…"`, donde `AUDIT_ROOT` es
vacío en producción y apunta a un fixture en pruebas. Los comandos externos se
llaman desde funciones envoltorio de `helpers.sh` que las pruebas reemplazan.

IDs por categoría: `ACC` accounts, `SSH` ssh, `NET` network, `FS` filesystem,
`HRD` hardening, `PER` persistence, `PAT` patching, `SEC` secrets, `APP` apps.
Un ID nunca cambia de significado.

### 5.4 Puntaje

- Pesos: critical 10, high 6, medium 3, low 1, info 0.
- Solo cuentan `PASS`, `WARN` y `FAIL`. `PASS` suma el peso completo, `WARN` la
  mitad y `FAIL` cero. Porcentaje = obtenido / posible.
- Puntaje base = `max(1, redondeo(porcentaje / 10))`.
- Topes (se aplica el más bajo, y el informe dice cuál fue y por qué):
  - 1 crítico abierto → 6; 2 → 4; 3 o más → 3
  - 5 o más altos abiertos → 6; de 1 a 4 → 8
  - menos del 90 % de las revisiones evaluadas (`SKIP` sobre aplicables) → 6
- "Abierto" significa `FAIL` o `WARN`. `WAIVED` y `NA` no afectan el puntaje.
- Cada categoría muestra su porcentaje con la misma fórmula.

### 5.5 Perfiles

Clase de auditoría:
- `container`: se detecta `/.dockerenv`, `/run/.containerenv` o
  `systemd-detect-virt -c`. Lo que maneja el host (firewall, kernel, reloj,
  logs) queda en `NA`.
- `server`: perfiles LSO `server`, `database` y `docker`, o sin escritorio detectado.
- `desktop`: perfiles `desktop`, `laptop`, `gaming`, `dev` y `workstation`, o
  con escritorio detectado.

`--profile <perfil LSO>` fuerza la clase. Sin él se usa la detección, y la
cabecera muestra `(detectado)` o `(elegido)`. Los ajustes viven en
`profiles.sh` como tabla `clase:ID → gravedad|na`. Un perfil nunca oculta una
revisión: solo cambia su gravedad o la marca como `NA`, y el informe lo dice.

### 5.6 Excepciones

Archivo `/etc/lso/audit-waivers.conf`, o el que indique `--waivers FILE`.
Formato: una línea por excepción, `ID  # motivo`. Una revisión exceptuada
aparece como `WAIVED` con su motivo y no afecta el puntaje.

### 5.7 Interfaz de línea de comandos

```
lso audit [--plain [--all] | --json] [--output FILE] [--min-score N]
          [--category CAT[,CAT]] [--profile P] [--waivers FILE] [--fast] [--no-color]
```
- Sin `--plain` ni `--json`, y con stdout en una TTY de al menos 100×30, abre
  el TUI. Si no se cumple, sale en `--plain`.
- `--output` escribe el informe con permisos 600.
- Código de salida: 0 normal; 1 si el puntaje es menor que `--min-score`;
  2 si hay error de uso.
- Sin root funciona igual: lo que requiere root queda en `SKIP` y el tope de
  cobertura lo refleja.

### 5.8 JSON (esquema v1)

```json
{
  "schema": 1, "tool": "lso-audit", "version": "…", "generated": "ISO-8601",
  "host": "…", "distro": "…", "profile": {"class": "desktop", "source": "detected"},
  "root": true, "duration_s": 5.4,
  "score": {"value": 6, "base": 8, "percent": 78, "cap": {"value": 6, "reason": "…"}},
  "counts": {"critical": 1, "high": 2, "medium": 9, "low": 8, "pass": 72, "warn": 0, "skip": 0, "na": 0, "waived": 0},
  "categories": [{"name": "ssh", "percent": 92, "open": 0}],
  "checks": [{"id": "SSH-001", "category": "ssh", "severity": "high", "status": "FAIL",
              "title": "…", "detail": "…", "fix": "…", "adjusted": "desktop:medium"}]
}
```
Se genera con `printf` y una función de escape propia, sin depender de `jq`.

### 5.9 Tablero (fase 2)

Pantalla alterna, cursor oculto, se restaura con `trap` (también con Ctrl+C).
- **Resumen:** anillo de puntaje con puntos (braille o `•`), barras verticales
  por gravedad, barras de porcentaje por categoría y lista "Lo más urgente".
- **Hallazgos:** lista navegable con ↑↓ y Enter para ver detalle y corrección.
  `/` busca, `s` filtra por gravedad, `c` filtra por categoría.
- **Categorías:** tabla de categorías; Enter muestra sus hallazgos.

Teclas globales: `Tab`/`1`/`2`/`3` cambian de pestaña, `?` muestra la ayuda y
`q` sale. Se redibuja cuando cambia el tamaño de la terminal (`SIGWINCH`).
Colores de 256, con degradación a 8 colores.

### 5.10 Pruebas

`tests/run.sh` ejecuta cada `tests/test_*.sh`, que usan asserts de
`tests/lib.sh`. Las revisiones se prueban con `AUDIT_ROOT` apuntando a
`tests/fixtures/<caso>/` y con los envoltorios de comandos reemplazados.
También hay pruebas del puntaje (casos de topes) y del JSON, que se valida con
`jq` solo si está instalado.

## 6. Fases

1. Motor, puntaje, perfiles básicos, salidas `--plain` y `--json`, integración
   con `optimizer.sh` y unas 25 revisiones (ssh, accounts, network).
2. Tablero TUI.
3. Categorías filesystem, hardening, persistence, patching, secrets y apps
   (~100 revisiones en total), ajustes de perfil completos y excepciones.
4. `--min-score`, página man, README, CHANGELOG y ayuda.

## 7. Decisiones tomadas por Claude (para revisar)

- Las pruebas usan un corredor propio en Bash en lugar de `bats`, para no agregar dependencias.
- El comando `audit` se intercepta antes del banner (§5.1).
- Las clases de perfil se mapean desde los perfiles LSO existentes (§5.5).
- Los nombres de categoría quedan en inglés en los IDs y en el JSON, y en la UI se muestran tal cual, como en la referencia.
- Fórmula base `max(1, redondeo(%/10))` (linaudit no publica la suya).
