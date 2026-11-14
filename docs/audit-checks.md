# Catálogo de revisiones de `lso audit`

Cada revisión tiene un ID estable que nunca cambia de significado (las
excepciones dependen de él). Gravedades: CRÍTICO (10), ALTO (6), MEDIO (3),
BAJO (1), INFO (0). Las marcadas con **lenta** se omiten con `--fast`.

Ajustes de perfil: **D** = escritorio/laptop, **C** = contenedor. `na` = no aplica.

## accounts — cuentas y contraseñas

| ID | Gravedad | Qué verifica | Perfil |
|---|---|---|---|
| ACC-001 | CRÍTICO | Solo root tiene UID 0 | |
| ACC-002 | CRÍTICO | Ninguna cuenta sin contraseña (requiere root) | |
| ACC-003 | ALTO | /etc/shadow con permisos ≤ 640 y dueño root | |
| ACC-004 | MEDIO | /etc/passwd sin escritura para grupo u otros | |
| ACC-005 | MEDIO | PASS_MAX_DAYS ≤ 365 | D: bajo |
| ACC-006 | MEDIO | Longitud mínima de contraseña ≥ 8 (pwquality o PAM) | D: bajo |
| ACC-007 | ALTO | Sin UIDs duplicados | |
| ACC-008 | BAJO | Cuentas de sistema (UID 1–999) sin shell de login | |
| ACC-009 | BAJO | UMASK 027 o 077 en login.defs | |
| ACC-010 | ALTO | Ninguna regla de sudo con NOPASSWD (requiere root) | D: medio |

## ssh — servidor OpenSSH (todas `na` si sshd no está instalado)

| ID | Gravedad | Qué verifica | Perfil |
|---|---|---|---|
| SSH-001 | ALTO | PermitRootLogin no / prohibit-password | |
| SSH-002 | ALTO | PasswordAuthentication no | D: medio |
| SSH-003 | CRÍTICO | PermitEmptyPasswords no | |
| SSH-004 | MEDIO | MaxAuthTries ≤ 4 | |
| SSH-005 | MEDIO | X11Forwarding no | D: bajo |
| SSH-006 | MEDIO | Sin cifrados cbc, arcfour ni 3des | |
| SSH-007 | BAJO | LoginGraceTime ≤ 60 s | |
| SSH-008 | MEDIO | sshd_config de root y sin escritura ajena | |
| SSH-009 | CRÍTICO | Llaves privadas del host sin permisos para grupo/otros | |
| SSH-010 | BAJO | ClientAliveInterval > 0 | |

## network — red y firewall

| ID | Gravedad | Qué verifica | Perfil |
|---|---|---|---|
| NET-001 | ALTO | Firewall local activo (ufw, firewalld, nftables o iptables) | D: medio · C: na |
| NET-002 | MEDIO | net.ipv4.ip_forward = 0 (na si hay Docker) | C: na |
| NET-003 | MEDIO | accept_redirects = 0 | C: na |
| NET-004 | BAJO | send_redirects = 0 | C: na |
| NET-005 | MEDIO | rp_filter = 1 o 2 | C: na |
| NET-006 | MEDIO | tcp_syncookies = 1 | C: na |
| NET-007 | BAJO | log_martians = 1 | C: na |
| NET-008 | MEDIO | accept_source_route = 0 | C: na |
| NET-009 | BAJO | icmp_echo_ignore_broadcasts = 1 | C: na |
| NET-010 | ALTO | Sin telnet, FTP ni rsh/rlogin en escucha fuera de loopback | |
| NET-011 | INFO | Servicios TCP en escucha en todas las interfaces | |

## filesystem — sistema de archivos

| ID | Gravedad | Qué verifica | Perfil |
|---|---|---|---|
| FS-001 | MEDIO | /tmp es un montaje propio con nodev y nosuid | C: na |
| FS-002 | MEDIO | /var/tmp con nodev y nosuid (montaje propio o bind) | C: na |
| FS-003 | MEDIO | /dev/shm con nodev, nosuid y noexec | C: na |
| FS-004 | ALTO | Sin archivos escribibles por todos en /etc | |
| FS-005 | MEDIO | Directorios escribibles por todos tienen sticky bit — **lenta** | |
| FS-006 | ALTO | /etc/gshadow con permisos ≤ 640 | |
| FS-007 | MEDIO | /etc/group sin escritura ajena | |
| FS-008 | ALTO | Sin SUID en binarios aprovechables para escalar (find, vim, python…) — **lenta** | |
| FS-009 | MEDIO | Sin archivos sin dueño ni grupo — **lenta** | |
| FS-010 | BAJO | Directorios de /home no legibles por otros usuarios | |
| FS-011 | MEDIO | /etc/crontab y /etc/cron.* solo de root, sin acceso ajeno | |
| FS-012 | BAJO | fs.suid_dumpable = 0 | C: na |
| FS-013 | MEDIO | fs.protected_symlinks = 1 | C: na |
| FS-014 | MEDIO | fs.protected_hardlinks = 1 | C: na |
| FS-015 | BAJO | fs.protected_fifos ≥ 1 | C: na |
| FS-016 | BAJO | fs.protected_regular ≥ 1 | C: na |

## hardening — endurecimiento del sistema

| ID | Gravedad | Qué verifica | Perfil |
|---|---|---|---|
| HRD-001 | ALTO | MAC activo: AppArmor con perfiles cargados o SELinux enforcing | C: na |
| HRD-002 | MEDIO | auditd en ejecución | D: bajo · C: na |
| HRD-003 | MEDIO | kernel.randomize_va_space = 2 (ASLR) | C: na |
| HRD-004 | MEDIO | Servicio de sincronización horaria activo | C: na |
| HRD-005 | MEDIO | syslog activo o journal persistente | C: na |
| HRD-006 | BAJO | kernel.kptr_restrict ≥ 1 | C: na |
| HRD-007 | BAJO | kernel.dmesg_restrict = 1 | C: na |
| HRD-008 | MEDIO | kernel.yama.ptrace_scope ≥ 1 | C: na |
| HRD-009 | BAJO | kernel.unprivileged_bpf_disabled ≥ 1 | C: na |
| HRD-010 | MEDIO | Configuración del gestor de arranque sin lectura para otros | C: na |
| HRD-011 | BAJO | Banner legal en /etc/issue.net | D: na · C: na |
| HRD-012 | BAJO | Ctrl+Alt+Supr no reinicia (ctrl-alt-del.target enmascarado) | D: na · C: na |
| HRD-013 | BAJO | Sistemas de archivos poco usados deshabilitados (cramfs, freevxfs, hfs, hfsplus, jffs2, udf) | C: na |
| HRD-014 | BAJO | Volcados de memoria (core dumps) limitados | |

## persistence — mecanismos de persistencia

| ID | Gravedad | Qué verifica | Perfil |
|---|---|---|---|
| PER-001 | CRÍTICO | /etc/ld.so.preload ausente o vacío | |
| PER-002 | ALTO | Sin archivos SUID/SGID en /tmp, /var/tmp ni /dev/shm | |
| PER-003 | ALTO | Sin ejecutables en /dev/shm | |
| PER-004 | ALTO | authorized_keys de root con permisos ≤ 600 | |
| PER-005 | ALTO | authorized_keys de usuarios sin escritura ajena | |
| PER-006 | MEDIO | Tareas cron que no ejecutan desde /tmp ni descargan y ejecutan (curl/wget \| sh) | |
| PER-007 | MEDIO | Unidades systemd que no ejecutan desde /tmp, /var/tmp ni /dev/shm | |
| PER-008 | MEDIO | Sin ejecutables ocultos en /tmp, /var/tmp ni /dev/shm | |
| PER-009 | CRÍTICO | PAM no acepta cualquier autenticación (auth sufficient pam_permit.so) | |
| PER-010 | ALTO | Scripts de inicio de shell (/etc/profile, /etc/profile.d, bashrc) sin escritura ajena | |
| PER-011 | MEDIO | /etc/rc.local sin comandos activos | |

## patching — actualizaciones

| ID | Gravedad | Qué verifica | Perfil |
|---|---|---|---|
| PAT-001 | ALTO | Sin actualizaciones de seguridad pendientes (apt, dnf, zypper) — **lenta** | |
| PAT-002 | MEDIO | Índice de paquetes actualizado en los últimos 7 días | |
| PAT-003 | MEDIO | Actualizaciones automáticas de seguridad activas | D: bajo |
| PAT-004 | MEDIO | No hay reinicio pendiente por actualizaciones | |
| PAT-005 | MEDIO | El kernel en ejecución es el más reciente instalado | C: na |
| PAT-006 | ALTO | Repositorios sin verificación de firma desactivada | |

## secrets — credenciales expuestas (nunca se muestra el valor)

| ID | Gravedad | Qué verifica | Perfil |
|---|---|---|---|
| SEC-001 | ALTO | Llaves SSH privadas de usuarios sin permisos para grupo/otros | |
| SEC-002 | ALTO | Archivos .env y similares no legibles por otros — **lenta** | |
| SEC-003 | CRÍTICO | Credenciales de nube (~/.aws, ~/.config/gcloud, ~/.azure) no legibles por otros | |
| SEC-004 | MEDIO | Historial de shell sin contraseñas en línea de comandos — **lenta** | |
| SEC-005 | ALTO | .netrc, .pgpass y .my.cnf no legibles por otros | |
| SEC-006 | ALTO | /etc/fstab sin contraseñas en línea (usa credentials=) | |
| SEC-007 | MEDIO | Sin repositorios .git dentro de /var/www | |
| SEC-008 | MEDIO | kubeconfig y config de Docker no legibles por otros | |

## apps — servicios y aplicaciones

| ID | Gravedad | Qué verifica | Perfil |
|---|---|---|---|
| APP-001 | ALTO | Socket de Docker no escribible por todos | |
| APP-002 | MEDIO | Usuarios en el grupo docker (equivale a root) | D: bajo |
| APP-003 | CRÍTICO | API de Docker sin TLS no expuesta (puerto 2375) | |
| APP-004 | MEDIO | MySQL/MariaDB no escucha en todas las interfaces | |
| APP-005 | MEDIO | PostgreSQL no escucha en todas las interfaces | |
| APP-006 | ALTO | Redis expuesto sin contraseña | |
| APP-007 | ALTO | MongoDB no escucha en todas las interfaces | |
| APP-008 | BAJO | nginx con server_tokens off | |
| APP-009 | BAJO | Apache con ServerTokens Prod | |
| APP-010 | BAJO | PHP con expose_php Off | |
| APP-011 | ALTO | NFS sin exportaciones no_root_squash | |
| APP-012 | ALTO | vsftpd sin acceso anónimo | |
| APP-013 | ALTO | SNMP sin comunidades public/private | |
| APP-014 | BAJO | Avahi (mDNS) desactivado en servidores | D: na |
| APP-015 | BAJO | CUPS solo escucha en loopback | |

Total: 101 revisiones.
