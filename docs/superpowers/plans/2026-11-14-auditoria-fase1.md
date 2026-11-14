# Auditoría — Fase 1 (motor, puntaje, texto y JSON) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** `lso audit` funcional en modo texto (`--plain`) y JSON (`--json`), con 31 revisiones de ssh, accounts y network, puntaje de 1 a 10 con topes, perfiles y excepciones.

**Architecture:** Las revisiones se registran en un motor (`engine.sh`) que guarda los resultados en arreglos asociativos. `score.sh` calcula el puntaje y los renderizadores solo leen esos arreglos. `optimizer.sh` intercepta `audit` antes del banner para que la salida quede limpia.

**Tech Stack:** Bash ≥ 4.4, coreutils (`stat`), iproute2 (`ss`, opcional). Pruebas con un corredor propio en Bash (sin bats).

**Spec:** `docs/superpowers/specs/2026-11-14-modulo-auditoria-design.md`

## Global Constraints

- Solo lectura: ninguna revisión escribe, reinicia ni cambia nada del sistema.
- Compatible con `set -u` (lo activa `optimizer.sh`). No usar `set -e` en el módulo.
- Sin dependencias nuevas. `jq` solo se usa en las pruebas, y solo si está instalado.
- Cada `*.sh` lleva la cabecera GPLv3 del proyecto (autor Ricardo Rosero, como en `lib/colors.sh`) y pasa `bash -n` (y `shellcheck --severity=warning` si está disponible).
- Textos en español neutro de Colombia, con tuteo.
- Rutas del sistema siempre a través de `audit_path` (soporte de `AUDIT_ROOT`). Comandos externos siempre a través de envoltorios `audit_cmd_*` / `audit_is_*` reemplazables en pruebas.
- Una revisión que no se pudo evaluar es `SKIP`, nunca `PASS`.
- Pesos: critical 10, high 6, medium 3, low 1, info 0. Topes: 1 crítico → 6, 2 → 4, ≥3 → 3; ≥5 altos → 6, 1–4 altos → 8; cobertura < 90 % → 6.

## Review Focus

1. `sshd_config` con `Include`, bloques `Match`, mayúsculas mezcladas y comentarios: el primer valor antes de `Match` gana, como en sshd → prueba en Task 3.
2. Ejecución sin root: `/etc/shadow` o `/etc/sudoers` ilegibles deben quedar en `SKIP` y activar el tope de cobertura, no aprobar → pruebas en Task 2 y Task 6.
3. Detalles con comillas, barras invertidas, saltos de línea o caracteres de control rompen el JSON → prueba en Task 8.
4. Salida redirigida a archivo o tubería: `--plain` no debe incluir códigos ANSI → prueba en Task 8.
5. Comandos ausentes (`ss`, `ufw`, `nft`, `sshd`): la revisión queda en `SKIP` con motivo y nada se cae bajo `set -u` → pruebas en Task 5 y Task 7.

---

### Task 1: Corredor de pruebas y motor de revisiones

**Files:**
- Create: `tests/run.sh`, `tests/lib.sh`, `modules/audit/engine.sh`
- Test: `tests/test_engine.sh`

**Interfaces:**
- Produces (`tests/lib.sh`): `assert_eq ESPERADO OBTENIDO [MSG]`, `assert_contains TEXTO SUBCADENA [MSG]`, `assert_not_contains`, `assert_status CODIGO cmd…`. Cuentan fallos en `TEST_FAILS`. Cada `test_*.sh` define funciones `test_*`.
- Produces (`tests/run.sh`): ejecuta cada `tests/test_*.sh` en un bash nuevo con `set -u`, corre todas sus funciones `test_*`, imprime `PASS/FAIL nombre` y sale ≠0 si algo falla. `tests/run.sh test_engine` filtra por archivo.
- Produces (`engine.sh`):
  - `audit_reset` limpia todo.
  - `audit_register ID SEVERIDAD CATEGORIA "TITULO" FUNCION "FIX"`
  - Arreglos: `AUDIT_IDS` (indexado, en orden de registro), y asociativos por ID: `AUDIT_SEV` (efectiva), `AUDIT_BASE_SEV`, `AUDIT_CAT`, `AUDIT_TITLE`, `AUDIT_FUNC`, `AUDIT_FIX`, `AUDIT_STATUS`, `AUDIT_DETAIL`, `AUDIT_ADJ` (texto del ajuste de perfil, vacío si no hubo).
  - Entradas para perfiles y excepciones: `AUDIT_FORCE_NA[ID]=motivo`, `AUDIT_WAIVED[ID]=motivo`.
  - `audit_pass|audit_fail|audit_warn|audit_skip|audit_na "detalle"` fijan el resultado de la revisión en curso (`AUDIT_CURRENT`).
  - `audit_run_all [CSV_CATEGORIAS]` ejecuta las revisiones registradas (filtradas por categoría si se pasa la lista).

- [ ] **Step 1: Escribir las pruebas que fallan** en `tests/test_engine.sh`:
  - `test_register_and_run_pass`: registra `T-001 high demo "t" _f "fix"` con `_f(){ audit_pass "ok"; }` → `AUDIT_STATUS[T-001]=PASS`, `AUDIT_DETAIL[T-001]=ok`, `AUDIT_IDS=(T-001)`.
  - `test_no_result_is_skip`: función que no llama nada → `SKIP` con detalle `"La revisión no reportó resultado"`.
  - `test_force_na_skips_execution`: `AUDIT_FORCE_NA[T-001]="host"` → `NA` con detalle `host`, y la función no se ejecuta (se verifica con un contador).
  - `test_waived_overrides_open`: FAIL + `AUDIT_WAIVED[T-001]="ticket 1"` → `WAIVED` con detalle `"ticket 1"`, sea cual sea el resultado.
  - `test_category_filter`: dos categorías y `audit_run_all "ssh"` → solo corre ssh y la otra no tiene estado.
  - `test_failing_function_does_not_abort`: una función que hace `return 1` después de `audit_fail` sigue en `FAIL` y el resto de revisiones corre.
- [ ] **Step 2:** `bash tests/run.sh test_engine` → FAIL (engine.sh no existe).
- [ ] **Step 3: Implementar** `tests/lib.sh`, `tests/run.sh` y `modules/audit/engine.sh` según las interfaces. El motor verifica que la severidad esté en `critical|high|medium|low|info` (si no, mensaje a stderr y `return 1`). `AUDIT_SEV` arranca igual a `AUDIT_BASE_SEV`.
- [ ] **Step 4:** `bash tests/run.sh test_engine` → todo PASS.
- [ ] **Step 5: Commit** `feat(audit): motor de revisiones y corredor de pruebas`

### Task 2: Puntaje

**Files:**
- Create: `modules/audit/score.sh`
- Test: `tests/test_score.sh`

**Interfaces:**
- Consumes: arreglos de Task 1.
- Produces: `audit_compute_score`, que fija `AUDIT_SCORE` (1–10), `AUDIT_SCORE_BASE`, `AUDIT_PERCENT` (0–100), `AUDIT_CAP` (vacío si no hubo tope), `AUDIT_CAP_REASON` y el asociativo `AUDIT_COUNT` con claves `critical high medium low` (abiertos = FAIL+WARN, por severidad efectiva) y `pass warn fail skip na waived`.
- Produces: `audit_categories` (imprime las categorías en orden de primera aparición, una por línea), `audit_category_percent CAT` (imprime un entero, o `-` si nada se evaluó) y `audit_category_open CAT` (imprime la cantidad de FAIL+WARN).

Cálculo, en unidades dobles para evitar decimales: PASS suma `2w`, WARN `w`, FAIL `0`; posible `2w`; `percent = (obt*100 + pos/2) / pos`; `base = max(1, (percent+5)/10)`. Si no hay nada evaluado: `percent=0`, `score=1`, motivo `"No se evaluó ninguna revisión"`. Cobertura: evaluadas = PASS+WARN+FAIL; aplicables = evaluadas+SKIP. Gana el tope más bajo; si hay empate, el primero en este orden: críticos, altos, cobertura.

- [ ] **Step 1: Pruebas** (se construyen estados con un helper `_mk ID SEV STATUS`):
  - `test_all_pass_is_10`: 3 PASS (high, medium, low) → `AUDIT_SCORE=10`, `AUDIT_PERCENT=100`, `AUDIT_CAP=""`.
  - `test_one_critical_caps_6`: 20 PASS medium + 1 FAIL critical → base 9 (percent 86), `AUDIT_SCORE=6` y `AUDIT_CAP_REASON` contiene `"1 hallazgo crítico"`.
  - `test_two_critical_caps_4` y `test_three_critical_caps_3`.
  - `test_high_caps`: 1 FAIL high → tope 8; 5 FAIL high → tope 6.
  - `test_warn_counts_half`: 1 PASS medium + 1 WARN medium → percent 75.
  - `test_coverage_cap`: 9 PASS + 2 SKIP → tope 6 con motivo que contiene `"cobertura"`. 9 PASS + 1 SKIP (90 %) → sin tope.
  - `test_na_and_waived_ignored`: NA y WAIVED no cambian el porcentaje ni los conteos de abiertos.
  - `test_category_percent`: `audit_category_percent ssh` es correcto y devuelve `-` para una categoría con solo NA.
- [ ] **Step 2:** `bash tests/run.sh test_score` → FAIL.
- [ ] **Step 3: Implementar** `score.sh`. Motivos exactos: `"Tope 6/10: 1 hallazgo crítico abierto"`, `"Tope 4/10: 2 hallazgos críticos abiertos"`, `"Tope 3/10: N hallazgos críticos abiertos"`, `"Tope 6/10: N hallazgos altos abiertos"`, `"Tope 8/10: N hallazgo(s) alto(s) abierto(s)"`, `"Tope 6/10: cobertura de P % (menos del 90 % evaluado; ¿corriste sin root?)"`.
- [ ] **Step 4:** pruebas PASS.
- [ ] **Step 5: Commit** `feat(audit): cálculo de puntaje con topes`

### Task 3: Ayudantes de lectura del sistema

**Files:**
- Create: `modules/audit/helpers.sh`, `tests/fixtures/ssh_include/…`
- Test: `tests/test_helpers.sh`

**Interfaces:**
- Produces:
  - `audit_path RUTA` → `"${AUDIT_ROOT:-}${RUTA}"`
  - `audit_perm RUTA` → modo octal (`stat -c %a`), o `return 1` si no existe.
  - `audit_owner_uid RUTA` → uid numérico (las pruebas lo reemplazan).
  - `audit_is_root` → `[[ $EUID -eq 0 ]]` (reemplazable).
  - `audit_have CMD` → `command -v`.
  - `audit_sysctl CLAVE` → contenido de `$(audit_path /proc/sys/<clave con / >)` sin espacios; `return 1` si no existe.
  - `audit_sshd_present` → existe `$(audit_path /etc/ssh/sshd_config)`.
  - `audit_sshd_value CLAVE DEFAULT` → valor efectivo en minúsculas. Si `AUDIT_ROOT` está vacío, `audit_is_root` y `audit_have sshd`, usa `audit_cmd_sshd_T` (envoltorio de `sshd -T`). Si no, analiza los archivos: expande `Include` (globs relativos a `/etc/ssh`, en orden alfabético, en la posición del Include), ignora comentarios y líneas vacías, clave sin distinguir mayúsculas, se detiene en el primer `Match`, gana el primer valor. Si no aparece, devuelve DEFAULT.
  - `audit_is_container` → `/.dockerenv`, `/run/.containerenv` o `systemd-detect-virt -c` (reemplazable).
  - Envoltorios: `audit_cmd_ss` (`ss -Htuln`), `audit_cmd_ufw_status`, `audit_cmd_firewalld_state`, `audit_cmd_nft_ruleset`, `audit_cmd_iptables_rules` (`iptables -S`).
- [ ] **Step 1: Pruebas** con el fixture `ssh_include`: `sshd_config` = `Include /etc/ssh/sshd_config.d/*.conf`, `PermitRootLogin yes`, `Match User x` + `PasswordAuthentication yes`; y `sshd_config.d/10-a.conf` = `permitrootlogin NO`.
  - `test_sshd_include_first_wins`: `audit_sshd_value permitrootlogin yes` → `no`.
  - `test_sshd_match_ignored`: `audit_sshd_value passwordauthentication yes` → `yes` (el default, no el valor dentro de Match).
  - `test_sshd_default`: clave ausente → devuelve el default.
  - `test_sysctl_read`: fixture `proc/sys/net/ipv4/ip_forward` con `0\n` → `0`; clave inexistente → código 1.
  - `test_perm`: archivo temporal con `chmod 640` → `640`.
- [ ] **Step 2:** FAIL. **Step 3:** implementar. **Step 4:** PASS.
- [ ] **Step 5: Commit** `feat(audit): ayudantes de lectura con raíz configurable`

### Task 4: Perfiles y excepciones

**Files:**
- Create: `modules/audit/profiles.sh`, `modules/audit/waivers.sh`
- Test: `tests/test_profiles.sh`

**Interfaces:**
- Produces:
  - `audit_profile_class_for PERFIL_LSO` imprime `server|desktop`, o `return 1` si el perfil es desconocido. Mapeo: server, database, docker → server; desktop, laptop, gaming, dev, workstation → desktop.
  - `audit_profile_resolve [PERFIL_LSO]` fija `AUDIT_PROFILE_CLASS` (`server|desktop|container`), `AUDIT_PROFILE_SOURCE` (`chosen|detected`) y `AUDIT_PROFILE_LABEL`. Sin argumento: container si `audit_is_container`; desktop si `${LSO_DESKTOP:-}` no está vacío ni es `none`/`Unknown`; si no, server. Etiquetas: `Servidor`, `Escritorio / <perfil>` (o `Escritorio` si fue detectado), `Contenedor`.
  - `audit_profile_apply` recorre `AUDIT_PROFILE_RULES` (líneas `"clase ID gravedad|na motivo…"`) y, para la clase activa, ajusta `AUDIT_SEV` y `AUDIT_ADJ[ID]="<clase>:<gravedad>"` o fija `AUDIT_FORCE_NA[ID]=motivo`. Ignora los IDs no registrados.
  - `audit_load_waivers ARCHIVO` llena `AUDIT_WAIVED[ID]=motivo` (formato `ID  # motivo`; sin motivo → `"Excepción sin motivo"`). Si el archivo no existe, no hace nada. Los IDs desconocidos van a `AUDIT_WAIVER_UNKNOWN` (arreglo).
- Reglas iniciales (fase 1):
  ```
  desktop SSH-002 medium · desktop SSH-005 low · desktop ACC-005 low · desktop ACC-006 low
  desktop ACC-010 medium · desktop NET-001 medium
  container NET-001 NET-002 NET-003 NET-004 NET-005 NET-006 NET-007 NET-008 NET-009 → na "Lo gestiona el host del contenedor" (una regla por ID)
  ```
- [ ] **Step 1: Pruebas:** `test_class_mapping` (laptop→desktop, database→server, xyz→rc 1); `test_detect_container_wins` (reemplaza `audit_is_container` para que devuelva 0 y LSO_DESKTOP=gnome → container, source detected); `test_desktop_adjusts_severity` (registra `NET-001 high`, clase desktop → `AUDIT_SEV=medium`, `AUDIT_ADJ=desktop:medium`); `test_container_forces_na`; `test_waivers_parse` (archivo con comentario, línea vacía, `NET-001   # firewall perimetral`, `XXX-999`) → motivo correcto y `AUDIT_WAIVER_UNKNOWN=(XXX-999)`.
- [ ] **Step 2:** FAIL. **Step 3:** implementar. **Step 4:** PASS.
- [ ] **Step 5: Commit** `feat(audit): perfiles y excepciones`

### Task 5: Revisiones SSH

**Files:**
- Create: `modules/audit/checks/ssh.sh`, `tests/fixtures/ssh_bad/`, `tests/fixtures/ssh_good/`
- Test: `tests/test_checks_ssh.sh`

**Interfaces:**
- Consumes: Task 1 y Task 3. Cada revisión es `_chk_ssh_NNN`. Si `audit_sshd_present` falla → `audit_na "OpenSSH server no está instalado"`.

| ID | Sev | Título (UI) | Pasa si | Fix |
|---|---|---|---|---|
| SSH-001 | high | Root no puede entrar por SSH con contraseña | `permitrootlogin` ∈ {no, prohibit-password, without-password} (default `prohibit-password`) | `PermitRootLogin prohibit-password` |
| SSH-002 | high | SSH no acepta contraseñas | `passwordauthentication`=no (default yes) | `PasswordAuthentication no` |
| SSH-003 | critical | SSH no acepta contraseñas vacías | `permitemptypasswords`=no (default no) | `PermitEmptyPasswords no` |
| SSH-004 | medium | Intentos de autenticación limitados | `maxauthtries` ≤ 4 (default 6) | `MaxAuthTries 4` |
| SSH-005 | medium | Reenvío X11 desactivado | `x11forwarding`=no (default no) | `X11Forwarding no` |
| SSH-006 | medium | Sin cifrados débiles | `ciphers` no contiene `cbc`, `arcfour` ni `3des` (default: pasa) | quitar esos cifrados de `Ciphers` |
| SSH-007 | low | Tiempo de gracia de login corto | `logingracetime` ≤ 60 (acepta `2m` → 120) (default 120) | `LoginGraceTime 60` |
| SSH-008 | medium | sshd_config protegido | uid 0 y no escribible por grupo ni por otros | `chown root:root …; chmod 600 …` |
| SSH-009 | critical | Llaves privadas del host protegidas | cada `/etc/ssh/ssh_host_*_key` sin permisos para grupo ni otros (`perm & 077 == 0`); si no se pueden leer los permisos → SKIP | `chmod 600 /etc/ssh/ssh_host_*_key` |
| SSH-010 | low | Sesiones inactivas se cierran | `clientaliveinterval` > 0 (default 0) | `ClientAliveInterval 300` |

- [ ] **Step 1: Pruebas:** el fixture `ssh_bad` hace fallar SSH-001…007 y 010; el fixture `ssh_good` hace pasar todas (con `audit_owner_uid` reemplazado para que devuelva 0). `test_no_sshd_is_na` (raíz vacía → las 10 en NA). `test_host_key_world_readable` (`chmod 644` en una llave falsa → SSH-009 FAIL y el detalle nombra el archivo). Los detalles de FAIL incluyen el valor encontrado, p. ej. `"PermitRootLogin yes"`.
- [ ] **Step 2:** FAIL. **Step 3:** implementar. **Step 4:** PASS.
- [ ] **Step 5: Commit** `feat(audit): revisiones de SSH`

### Task 6: Revisiones de cuentas

**Files:**
- Create: `modules/audit/checks/accounts.sh`, `tests/fixtures/acc_bad/`, `tests/fixtures/acc_good/`
- Test: `tests/test_checks_accounts.sh`

| ID | Sev | Título | Pasa si | SKIP si |
|---|---|---|---|---|
| ACC-001 | critical | Solo root tiene UID 0 | en `/etc/passwd` solo `root` tiene UID 0 | — |
| ACC-002 | critical | Ninguna cuenta sin contraseña | ningún campo 2 vacío en `/etc/shadow` | shadow ilegible |
| ACC-003 | high | /etc/shadow protegido | uid 0 y `perm & 037 == 0` (≤ 640) | — |
| ACC-004 | medium | /etc/passwd sin escritura ajena | `perm & 022 == 0` | — |
| ACC-005 | medium | Vencimiento de contraseñas configurado | `PASS_MAX_DAYS` en `/etc/login.defs` ≤ 365 | login.defs no existe |
| ACC-006 | medium | Política de longitud mínima de contraseña | `minlen` ≥ 8 en `/etc/security/pwquality.conf` (o `pwquality.conf.d/*.conf`), o `minlen=` ≥ 8 en una línea `pam_pwquality`/`pam_unix` de `/etc/pam.d/common-password` o `system-auth` | — |
| ACC-007 | high | Sin UIDs duplicados | sin UIDs repetidos en `/etc/passwd` | — |
| ACC-008 | low | Cuentas de sistema sin shell de login | UID 1–999 con shell distinta de `nologin`/`false`/`sync`/`shutdown`/`halt` → WARN con la lista | — |
| ACC-009 | low | umask restrictiva por defecto | `UMASK` en login.defs ∈ {027, 077}; 022 → WARN | login.defs no existe |
| ACC-010 | high | sudo siempre pide contraseña | ninguna línea activa con `NOPASSWD` en `/etc/sudoers` ni `/etc/sudoers.d/*` | sudoers ilegible |

Fixes: comandos concretos (`passwd -l usuario`, `chmod 640 /etc/shadow`, editar `PASS_MAX_DAYS 365`, `minlen = 12`, `usermod -s /usr/sbin/nologin usuario`, `UMASK 027`, quitar `NOPASSWD` con `visudo`).

- [ ] **Step 1: Pruebas:** `acc_bad` (usuario `toor` con UID 0, `test::` en shadow, UID 1001 duplicado, `daemon` con `/bin/bash`, `NOPASSWD: ALL`, `PASS_MAX_DAYS 99999`, `UMASK 022`) → FAIL/WARN esperados por ID. `acc_good` → todas PASS. `test_shadow_unreadable_is_skip`: con `chmod 000` en `shadow`, ACC-002 queda en `SKIP` y el detalle contiene `"root"` (la prueba se omite si se corre como root). Los detalles nunca incluyen hashes.
- [ ] **Step 2:** FAIL. **Step 3:** implementar. **Step 4:** PASS.
- [ ] **Step 5: Commit** `feat(audit): revisiones de cuentas`

### Task 7: Revisiones de red

**Files:**
- Create: `modules/audit/checks/network.sh`, `tests/fixtures/net_bad/`, `tests/fixtures/net_good/` (árbol `proc/sys/net/ipv4/…`)
- Test: `tests/test_checks_network.sh`

| ID | Sev | Título | Pasa si |
|---|---|---|---|
| NET-001 | high | Firewall local activo | `ufw status` contiene `active` (no `inactive`), o firewalld `running`, o `nft list ruleset` tiene alguna regla `drop`/`reject` o `policy drop`, o `iptables -S` tiene `-P INPUT DROP` o algún `-j DROP/REJECT`. Ninguna herramienta disponible o todas fallan por permisos sin root → SKIP. |
| NET-002 | medium | Reenvío IPv4 desactivado | `ip_forward`=0; si `audit_have docker` → NA ("Docker requiere reenvío") |
| NET-003 | medium | Rechaza ICMP redirects | `conf/all/accept_redirects`=0 |
| NET-004 | low | No envía ICMP redirects | `conf/all/send_redirects`=0 |
| NET-005 | medium | Reverse path filtering activo | `conf/all/rp_filter` ∈ {1, 2} |
| NET-006 | medium | SYN cookies activas | `tcp_syncookies`=1 |
| NET-007 | low | Registra paquetes marcianos | `conf/all/log_martians`=1 |
| NET-008 | medium | Rechaza source routing | `conf/all/accept_source_route`=0 |
| NET-009 | low | Ignora ping a broadcast | `icmp_echo_ignore_broadcasts`=1 |
| NET-010 | high | Sin servicios inseguros escuchando | `ss` no muestra puertos 21, 23, 512, 513 ni 514 en escucha (sin `ss` → SKIP) |
| NET-011 | info | Servicios expuestos en todas las interfaces | lista los puertos en `0.0.0.0`/`[::]`/`*` (WARN si hay alguno; peso 0) |

Si la clave sysctl no existe → SKIP `"No se pudo leer net.ipv4.…"`. Fixes con `sysctl -w` más la línea para `/etc/sysctl.d/99-lso-hardening.conf`.

- [ ] **Step 1: Pruebas:** fixtures bad/good para NET-002…009. NET-001 con envoltorios reemplazados en cuatro casos: ufw activo → PASS; ufw `Status: inactive` → FAIL; ninguna herramienta (`audit_have` devuelve 1) → SKIP; nft con `policy drop` → PASS. NET-010 con `audit_cmd_ss` falso que muestra `0.0.0.0:23` → FAIL y el detalle menciona `23`. `test_docker_makes_forward_na`.
- [ ] **Step 2:** FAIL. **Step 3:** implementar. **Step 4:** PASS.
- [ ] **Step 5: Commit** `feat(audit): revisiones de red`

### Task 8: Salidas en texto y JSON

**Files:**
- Create: `modules/audit/render_plain.sh`, `modules/audit/render_json.sh`
- Test: `tests/test_render.sh`

**Interfaces:**
- Consumes: Tasks 1, 2 y 4 (`AUDIT_PROFILE_*`). Metadatos que fija Task 9: `AUDIT_VERSION`, `AUDIT_HOST`, `AUDIT_DISTRO`, `AUDIT_DURATION` (texto con 1 decimal), `AUDIT_IS_ROOT` (`true|false`), `AUDIT_COLOR` (1|0).
- Produces: `audit_render_plain [all]`, `audit_json_escape TEXTO`, `audit_render_json`.
- Orden de hallazgos (compartido): severidad efectiva critical→high→medium→low→info, luego ID. Función `audit_sorted_ids [all]`, que vive en `render_plain.sh` y también la usa el JSON (todas las revisiones, en ese orden).

Formato `--plain`:
```
LSO audit · <host> · <distro> · <perfil label> (<detectado|elegido>) · <versión> · <dur> s
Puntaje: 6/10  (base 8/10, 78 %)
  Tope 6/10: 1 hallazgo crítico abierto
Abiertos: 1 crítico · 2 alto · 9 medio · 8 bajo    ✓ 72 aprobadas · ? 0 no evaluables · ≈ 0 exceptuadas
Categorías:
  accounts   97 %   ✖ 0
  …
Hallazgos:
  [CRÍTICO] PER-009  Título
            Detalle: …
            Corrección: …
```
Con `all` se agregan las secciones `Aprobadas`, `No evaluables`, `No aplica` y `Exceptuadas`. Colores solo si `AUDIT_COLOR=1`.

- [ ] **Step 1: Pruebas:** `test_plain_no_ansi_when_color_off` (no contiene `$'\033'`); `test_plain_sorted_by_severity` (CRÍTICO aparece antes que BAJO); `test_plain_all_lists_pass`; `test_json_escape` (`a"b\c` + salto de línea + tabulador + `\x01` → `a\"b\\c\n\t\u0001`); `test_json_valid` (si `jq` existe: `jq -e '.schema==1 and .score.value>=1 and (.checks|length)==N'`; si no existe, la prueba se omite e imprime SKIP); `test_json_profile_adjusted` (`.checks[]|select(.id=="NET-001").adjusted=="desktop:medium"`).
- [ ] **Step 2:** FAIL. **Step 3:** implementar el JSON exactamente con las claves del esquema v1 del spec (§5.8). **Step 4:** PASS.
- [ ] **Step 5: Commit** `feat(audit): salidas plain y json`

### Task 9: Punto de entrada `lso audit` e integración

**Files:**
- Create: `modules/audit/audit.sh`
- Modify: `optimizer.sh` (después de cargar el core, antes de `init_logger`), `core/dispatcher.sh` (`show_help`)
- Test: `tests/test_cli.sh`

**Interfaces:**
- Consumes: todo lo anterior.
- Produces: `audit_main ARGS…` → código de salida (0 normal, 2 uso inválido). Opciones: `--plain`, `--all`, `--json`, `--output FILE`, `--category CSV`, `--profile P`, `--waivers FILE` (default `/etc/lso/audit-waivers.conf`), `--fast` (aceptada, sin efecto en fase 1), `--no-color`, `-h|--help`. Sin `--plain`/`--json` → plain (el TUI llega en la fase 2). `--plain` y `--json` juntos → error de uso. Perfil o categoría desconocidos → error de uso con la lista válida.
- Flujo: `audit_reset` → cargar `checks/*.sh` → `audit_profile_resolve` → `audit_profile_apply` → `audit_load_waivers` → `audit_run_all` → `audit_compute_score` → render. `AUDIT_COLOR=1` solo si stdout es TTY, no hay `--no-color`, `NO_COLOR` está vacía y no se pide `--output`. `--output`: escribe con `umask 077` y `chmod 600`, y avisa por stderr `"Informe guardado en FILE"`. Si no es root, avisa por stderr `"Aviso: sin root algunas revisiones no se pueden evaluar"` (no en stdout).
- Integración en `optimizer.sh`: si `${1:-} == audit`, entonces `shift`, `LSO_LOG_FILE=/dev/null`, `run_full_detection >/dev/null 2>&1 || true`, `source "$LSO_BASE_DIR/modules/audit/audit.sh"`, `audit_main "$@"` y `exit $?`. Ayuda: línea `audit                    Auditoría de seguridad (solo lectura). Ver: lso audit --help`.

- [ ] **Step 1: Pruebas** (ejecutan `bash optimizer.sh audit …` como proceso):
  - `test_json_stdout_is_clean`: `--json` → el primer carácter de stdout es `{` (y con `jq`, JSON válido con 31 checks).
  - `test_plain_has_score`: `--plain --no-color` contiene `Puntaje:` y no contiene `LINUX SYSTEM OPTIMIZER`.
  - `test_bad_flag_exit_2`: `--nope` → código 2.
  - `test_plain_and_json_conflict`: código 2.
  - `test_output_mode_600`: `--json --output "$tmp/r.json"` → archivo con modo `600` y stdout vacío.
  - `test_category_filter`: `--json --category ssh` → todos los checks con `category=="ssh"` (con `jq`), o `grep -c '"category": "accounts"'` = 0.
  - `test_profile_server`: `--profile server --json` → `"class": "server"` y `"source": "chosen"`.
  - `test_help_lists_audit`: `bash optimizer.sh help` contiene `audit`.
- [ ] **Step 2:** FAIL. **Step 3:** implementar. **Step 4:** `bash tests/run.sh` (toda la suite) → PASS.
- [ ] **Step 5: Verificación manual:** `bash optimizer.sh audit --plain` en este equipo, sin root y con `sudo`. Revisar que los resultados tengan sentido para el sistema real y anotar los falsos positivos.
- [ ] **Step 6: Commit** `feat(audit): comando lso audit con salidas plain/json`
