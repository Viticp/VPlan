# Fase 9 - Cierre, uso diario y preparación de la publicación

**Fecha:** 2026-11-17
**Responsable:** OpenCode
**Estado:** verificada contra Windows 11, MySQL, API y Chrome; pendiente de aprobación

---

## 1. Objetivo

Cerrar VPlan como aplicación personal para Windows 11 sin añadir funciones al
producto:

- Arrancar y parar con un solo comando.
- Evitar procesos huérfanos y facilitar el diagnóstico con logs.
- Añadir accesos directos de escritorio.
- Verificar de verdad la persistencia, la copia y la restauración.
- Actualizar la documentación de instalación y uso diario.
- Preparar la primera publicación en GitHub **sin commit ni push**.

Restricciones respetadas: no se modificaron Java, `pom.xml`, `application.yml`,
Flyway, migraciones, frontend ni dependencias; no se tocó MySQL ni el firewall; no
se mostraron secretos; no se hizo commit ni push.

---

## 2. Decisiones aprobadas

| ID | Decisión | Aplicación |
|---|---|---|
| D1 | Documentar MySQL escuchando en todas las interfaces | Documentado en INSTALACION, README y este informe; sin cambios en `my.ini` ni firewall |
| D2 | Restauración en base de pruebas independiente | Intentada; bloqueada por permisos de `vplan_app`; no se forzó nada |
| D3 | MIT si el repositorio es público | No se creó `LICENSE` porque el repositorio será privado inicialmente |
| D4 | Accesos directos con ventana normal | Creados y probados en el escritorio |
| D5 | Repositorio privado inicialmente | Documentado; el remoto aún no existe o no es accesible |
| D6 | Sin commit ni push | Se mantienen **0 commits** |

---

## 3. Archivos

### Nuevos

| Archivo | Contenido |
|---|---|
| `scripts/start-vplan.ps1` | Arranque diario con preflight, health, log y PID |
| `scripts/stop-vplan.ps1` | Parada segura, liberación del puerto y limpieza de Maven |
| `scripts/create-shortcuts.ps1` | Accesos directos "VPlan" y "Detener VPlan" |
| `docs/USO-DIARIO.md` | Guía corta de arranque, parada, copias y problemas |
| `docs/colaboracion/FASE-09.md` | Este informe |

### Modificados

| Archivo | Cambio |
|---|---|
| `INSTALACION.md` | Uso diario, logs, accesos directos, restauración segura, traslado, diagnóstico y hallazgo de MySQL |
| `README.md` | Estado final, comandos, estructura, pruebas, seguridad, publicación y tabla de fases |
| `scripts/restore-db.ps1` | Solo el mensaje que sugería `Ctrl+C`; ahora remite a `stop-vplan.ps1`. Sin cambios de comportamiento |

### No modificados

`pom.xml`, todo `src/main/java`, `src/test`, `application.yml`, migraciones
`V1`/`V2`, HTML/CSS/JS, `database/`, `scripts/set-dev-env.ps1`,
`scripts/set-db-password.ps1`, `scripts/backup-db.ps1`,
`scripts/mysql-utils.ps1` y `scripts/check-no-secrets.ps1`.

Comprobado con `git diff --name-only`: ningún archivo de `src/`, `pom.xml`,
`.mvn/` o `database/` aparece como modificado.

---

## 4. Implementación

### 4.1 Arranque

`start-vplan.ps1`:

1. Carga `set-dev-env.ps1` en su propia sesión (el proceso hijo hereda el entorno).
2. Exige `VPLAN_DB_PASSWORD` sin imprimirla.
3. Verifica JDK 21+ y MySQL en `127.0.0.1:3306`.
4. Si el puerto 8080 está ocupado:
   - VPlan: espera health y abre el navegador; no duplica.
   - Otro proceso: se niega y muestra PID y nombre.
5. Arranca `mvnw spring-boot:run` mediante un wrapper `.cmd` en segundo plano.
6. Redirige toda la salida a `logs/vplan-AAAA-MM-DD_HHmmss.log`.
7. Espera `/api/health` con `status=UP` y `database=UP` (90 s por defecto).
8. Guarda `LauncherPid`, `AppPid`, fecha y log en `logs/vplan.pid`.
9. Abre `http://localhost:8080` salvo `-NoBrowser`.
10. Si falla, muestra las últimas líneas del log, limpia el proceso y sale con
    código 1.

Opciones: `-NoBrowser`, `-TimeoutSeconds`, `-Foreground`, `-NoPause`.

### 4.2 Parada

`stop-vplan.ps1`:

1. Lee `logs/vplan.pid` y el proceso que escucha en 8080.
2. Verifica que es Java y que su línea de comandos contiene VPlan.
3. Intenta un cierre ordenado; si no termina, fuerza el árbol del proceso.
4. Detiene también el lanzador de Maven.
5. Espera a que el puerto quede libre y borra el PID.
6. Si el proceso es ajeno, **se niega** salvo `-Force`.

Limitación: Windows no entrega `Ctrl+C` real a un Java en segundo plano. El cierre
puede terminar siendo forzado; MySQL mantiene la integridad de las transacciones
ya confirmadas. El modo `-Foreground` conserva el `Ctrl+C` clásico.

### 4.3 Accesos directos

`create-shortcuts.ps1` crea dos `.lnk` con `powershell.exe -NoProfile -File`:

- `%USERPROFILE%\Desktop\VPlan.lnk`
- `%USERPROFILE%\Desktop\Detener VPlan.lnk`

Ventana normal, directorio de trabajo del proyecto y sin permisos de
administrador.

---

## 5. Resultados reales

### 5.1 Arranque y parada

| Escenario | Resultado |
|---|---|
| Arranque desde parado | Health `UP`; log de 7.571 bytes; PID 21544; puerto 8080 en `127.0.0.1` |
| Segundo arranque | Detectó VPlan, no duplicó y salió con código 0 |
| Puerto 8080 ocupado por PowerShell | Se negó, mostró PID 5340 y salió con código 1; el proceso ajeno siguió vivo |
| Parada normal | Puerto libre, PID borrado y ningún Java de VPlan |
| Parada sin aplicación | Mensaje claro y código 0 |
| Parada con proceso ajeno | Se negó y el proceso siguió vivo |
| Acceso directo "VPlan" | Arrancó y respondió `UP` |
| Acceso directo "Detener VPlan" | Paró la aplicación y dejó el puerto libre |

**8 / 8 escenarios correctos.**

No se ejecutaron: el camino de timeout de arranque (requiere romper una
precondición), `-Foreground` (bloquea la consola de prueba) ni `-Force` sobre un
proceso ajeno (sería destructivo y no era necesario).

### 5.2 Persistencia

1. Se creó la tarea temporal `FASE9_TEMP_persistencia` (id 72).
2. Se paró VPlan con `stop-vplan.ps1`.
3. Se volvió a arrancar con `start-vplan.ps1`.
4. `GET /api/tareas/72` devolvió la misma tarea, estado `PENDIENTE`.
5. Se eliminó la tarea.

Resultado: **1 / 1 tarea conservada**. La base quedó a **0 tareas**.

### 5.3 Copia de seguridad

```text
Archivo: backups\vplan-2026-11-17_132926.sql
Tamano : 3.722 bytes (3,6 KB)
Contiene CREATE TABLE `tareas`: si
Contiene CREATE TABLE `flyway_schema_history`: si
Contiene CREATE DATABASE o USE: no
```

La copia se hizo con la aplicación parada y 0 tareas. Es una copia real y válida
del esquema y del historial de Flyway.

### 5.4 Restauración

| Prueba | Resultado |
|---|---|
| Archivo inexistente | `No existe el archivo de copia de seguridad...` |
| Archivo sin tablas | `El archivo no parece una copia completa de VPlan...` |
| Aplicación en marcha | `Hay algo escuchando en el puerto 8080...` |
| Confirmación con `NO` | `Restauracion cancelada. No se ha modificado nada.` |
| Base `vplan_restore_test` | **No ejecutada**: `ERROR 1044 (42000): Access denied for user 'vplan_app'@'localhost' to database 'vplan_restore_test'` |

La restauración real sobre `vplan` **no se ejecutó** para no tocar los datos.
`vplan_app` solo tiene permisos sobre `vplan.*`; no puede crear ni usar la
base de pruebas. El SQL que debe ejecutar un administrador está en
`INSTALACION.md`, sección 7.

### 5.5 Regresiones

| Suite | Resultado |
|---|---|
| `.\mvnw.cmd test` | **34 / 34**, 0 fallos, 0 errores |
| API real (`verify-phase8-api.mjs`) | **53 / 53**, 0 fallos |
| Interfaz real (`verify-phase8-ui.mjs`) | **98 / 98**, 0 fallos; 0 excepciones; 2 errores de consola simulados y 0 inesperados |
| Regresión Fase 7 (`verify-phase7.mjs`) | **134 / 134**, 0 errores de consola, 0 peticiones externas |

Las copias de las suites de UI y Fase 7 escribieron capturas en
`target/fase9-capturas` en lugar de `docs/capturas`, para no alterar las capturas
de fases anteriores. Las aserciones no se modificaron.

### 5.6 Estado final

```text
TAREAS=0
FLYWAY=1|1
FLYWAY=2|1
8080/9222 LIBRES
PROCESOS VPLAN: NINGUNO
```

### 5.7 Seguridad y documentación

- `check-no-secrets.ps1`: **OK**, el valor de `VPLAN_DB_PASSWORD` no aparece en
  ningún archivo del proyecto.
- `.env.local`, `backups/`, `logs/` y `target/` no están en el índice de Git.
- Los enlaces locales de README, INSTALACION y USO-DIARIO resuelven.
- No se mostró ni copió ninguna contraseña.

---

## 6. Incidencias y limitaciones

### 6.1 MySQL escucha en todas las interfaces

Comprobado: puerto 3306 en `::`, sin `bind-address` en `my.ini`, accesible por TCP
en las IP locales del equipo. El firewall tiene las reglas de entrada de `mysqld`
en **Block**, así que la red no podía conectar, pero la configuración no cumple la
recomendación.

No se modificó nada (D1). Procedimiento con administrador en
`INSTALACION.md` §3 y §10.

### 6.2 Base de pruebas de restauración

Bloqueada por permisos. Para habilitarla, un administrador debe ejecutar:

```sql
CREATE DATABASE vplan_restore_test
  CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;

GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, REFERENCES, INDEX, ALTER
  ON vplan_restore_test.* TO 'vplan_app'@'localhost';
```

Después se puede repetir con:

```powershell
.\scripts\restore-db.ps1 -BackupFile ".\backups\vplan-2026-11-17_132926.sql" `
  -Database vplan_restore_test -Force
```

### 6.3 Publicación

- Cuenta de GitHub del autor: `https://github.com/Viticp`. El repositorio
  público de VPlan todavía no se ha creado.
- `user.name` y `user.email` siguen sin configurar.
- No hay `LICENSE`: la licencia se decidirá antes de publicar.
- **0 commits y 0 push.**

### 6.4 Otras limitaciones

- No se probó una instalación completa en una máquina virtual con Windows 11
  limpio. Se revisó la guía y se ejecutaron sus comandos en este equipo.
- No se probó el cierre ordenado real de Spring: Windows fuerza el proceso si no
  responde. No hay pérdida de datos confirmados.
- `-Foreground` y `-Force` no se ejecutaron en las pruebas (ver 5.1).

---

## 7. Estado de Git

- Rama `main`, **0 commits**.
- **114 archivos preparados** en el índice: los 109 de la Fase 8 más los ocho
  archivos de esta fase.
- Preparados en esta fase: `scripts/start-vplan.ps1`,
  `scripts/stop-vplan.ps1`, `scripts/create-shortcuts.ps1`,
  `docs/USO-DIARIO.md`, `docs/colaboracion/FASE-09.md`, `README.md`,
  `INSTALACION.md` y `scripts/restore-db.ps1`.
- No queda ningún cambio sin preparar y `.env.local`, `backups/`, `logs/` y
  `target/` siguen fuera del índice.
- Ningún archivo de la aplicación (`src/`, `pom.xml`, `.mvn/`, `database/`)
  aparece modificado.
- Se usó solo `git add`. **No se hizo commit ni push**: la publicación espera
  autorización expresa. Si se quiere deshacer la preparación, basta con
  `git reset` (no borra archivos).

---

## 8. Cómo repetir las pruebas

```powershell
# 1. Tests del backend
. .\scripts\set-dev-env.ps1
.\mvnw.cmd test

# 2. Arrancar sin navegador
.\scripts\start-vplan.ps1 -NoBrowser

# 3. API (deja 4 tareas temporales)
node target\verify-phase8-api.mjs

# 4. Interfaz: Chrome con --remote-debugging-port=9222
node target\verify-phase9-ui.mjs

# 5. Regresión de la Fase 7
node target\verify-phase9-phase7.mjs

# 6. Parar, copiar y comprobar la base
.\scripts\stop-vplan.ps1
.\scripts\backup-db.ps1
```

`verify-phase9-ui.mjs` y `verify-phase9-phase7.mjs` son copias de las suites de la
Fase 8 y la Fase 7 que solo cambian la carpeta de capturas a
`target/fase9-capturas`.

---

## 9. Conclusión

VPlan queda cerrado para uso personal en Windows 11: arranca y para con un
comando o un doble clic, registra sus logs, conserva las tareas al reiniciar,
permite copias reales y protege la restauración con comprobaciones. La aplicación
está parada, con 0 tareas, Flyway correcto y sin procesos abiertos.

Quedan tres asuntos externos, documentados y sin forzar: cerrar MySQL a loopback
con permisos de administrador, habilitar la base de pruebas de restauración y
crear el repositorio privado con identidad y autenticación antes del primer push.
