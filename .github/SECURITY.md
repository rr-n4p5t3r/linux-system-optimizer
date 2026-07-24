# Política de Seguridad

## Versiones soportadas

LSO está en fase **alpha** (versión actual: `0.2.0-alpha`) y todavía no ha
alcanzado una versión `1.0` estable. Mientras tanto solo hay una línea de
desarrollo activa: la rama `main`. No se mantienen versiones alpha
anteriores ni ramas paralelas.

| Versión              | Soportada           |
| --------------------- | -------------------- |
| `0.2.x-alpha` (`main`) | :white_check_mark: |
| `< 0.2.0-alpha`        | :x:                 |

Cuando el proyecto alcance `1.0`, esta tabla se actualizará para reflejar
las versiones con mantenimiento a largo plazo.

## Alcance

LSO normalmente se ejecuta con privilegios de root (`sudo`) y modifica
estado del sistema: parámetros del kernel (`sysctl`), servicios `systemd`,
el gestor de paquetes, archivos en `/etc`, autoarranque de aplicaciones, y
cachés/backups del usuario. Por eso tienen prioridad los reportes sobre:

- Ejecución de comandos arbitrarios a través de entradas no confiables
  (nombres de módulo/perfil, o archivos `config/rules/*.rules` manipulados).
- Escalado de privilegios más allá de lo que ya otorga `sudo`.
- Escritura insegura en archivos del sistema (symlinks, condiciones de
  carrera en `backups/`, `logs/`, `reports/`).
- Fuga de datos sensibles en logs o reportes generados por LSO.

**No es una vulnerabilidad** que LSO, ejecutado con `sudo`, modifique el
sistema — es su propósito documentado. Para inspeccionar cambios antes de
aplicarlos, usa siempre `--dry-run` primero.

## Cómo reportar una vulnerabilidad

**No abras un issue público para vulnerabilidades de seguridad.**

1. Preferido: pestaña **Security → Report a vulnerability** de este
   repositorio (GitHub Private Vulnerability Reporting).
2. Alternativa: escribe a **rrosero2000@gmail.com** con el asunto
   `[LSO Security] <resumen breve>`.

Incluye si es posible: versión de LSO afectada, distro/entorno donde lo
reprodujiste, pasos para reproducir, e impacto esperado.

### Qué esperar

- Confirmación de recepción en un plazo de **5 días**.
- Proyecto de un solo mantenedor en fase alpha: no hay una SLA formal, pero
  los reportes válidos con impacto de privilegios/root se priorizan sobre
  cualquier otro trabajo en curso.
- Si se acepta, se coordina contigo una fecha de divulgación una vez
  publicado el fix, y se te da crédito (salvo que prefieras anonimato).
- Si se rechaza (no reproducible, fuera de alcance, comportamiento
  esperado), se explica el motivo.

## Buenas prácticas para quien use LSO

- Corre `--dry-run` antes de aplicar cualquier perfil en un sistema que
  te importe.
- No agregues reglas (`.rules`), perfiles o plugins de terceros sin
  revisarlos antes: se ejecutan con los mismos privilegios que LSO (root,
  si lo invocaste con `sudo`).
