# Adaptación de portabilidad — Informe de implementación

**Fecha:** 2026-11-17  
**Alcance:** traslado de VPlan del ordenador de clase a un Windows 10/11
personal. Sin cambios de esquema, migraciones, dependencias, autenticación ni
diseño del frontend.  
**Estado:** implementado y verificado. La Fase 7 se desarrolló después.

---

## 1. Decisiones aplicadas

| Decisión | Valor |
|---|---|
| Sistema del ordenador personal | Windows 10/11 |
| Orden de trabajo | Portabilidad primero; Fase 7 después |
| Spring Boot | Escucha solo en `127.0.0.1:8080` |
| MySQL | Debe escuchar solo en localhost |
| Contraseñas | Variables de entorno o `.env.local`; nunca en Git |
| Copias de seguridad | Dump completo de `vplan`, incluido Flyway |

---

## 2. Archivos modificados y creados

### Scripts

| Archivo | Cambio |
|---|---|
| `scripts/set-dev-env.ps1` | Detección portable del JDK; lectura UTF-8 de `.env.local` |
| `scripts/mysql-utils.ps1` | **Nuevo**: lectura `.env`, resolución de variables y búsqueda de herramientas MySQL |
| `scripts/backup-db.ps1` | **Nuevo**: copia completa con comprobaciones y sin mostrar la contraseña |
| `scripts/restore-db.ps1` | **Nuevo**: restauración con validación, puerto 8080 libre y confirmación |

### Configuración y código

| Archivo | Cambio |
|---|---|
| `src/main/resources/application.yml` | `server.address: 127.0.0.1`; URL JDBC por defecto a `127.0.0.1`; comentarios de alcance local |
| `src/main/java/com/vplan/VPlanApplication.java` | Mensaje de error genérico, sin rutas de Windows |
| `pom.xml` | Comentario genérico sobre Java 21+ |
| `.gitignore` | `backups/` y `*.dump` |

### Documentación

| Archivo | Cambio |
|---|---|
| `INSTALACION.md` | **Nuevo**: instalación en Windows limpio, traslado, backup/restore y problemas habituales |
| `README.md` | Requisitos y comandos portables; enlaces a instalación y copias; estado de fases |
| `docs/aprendizaje/01-arquitectura.md` | Nota de escucha solo en loopback |
| `docs/aprendizaje/02-base-de-datos.md` | Secciones de backup/restore y MySQL local |
| `docs/aprendizaje/03-entorno-y-maven.md` | Detección portable del JDK; sin rutas del aula |
| `docs/aprendizaje/04-arranque-y-health.md` | Ruta genérica y nota de `server.address` |
| `docs/colaboracion/FASE-02.md` | Rutas del aula sustituidas por valores genéricos y nota histórica |
| `docs/colaboracion/PORTABILIDAD.md` | **Nuevo**: este informe |

**No se modificó:** `V1__init.sql`, `V2__single_user.sql`, entidades, DTOs,
controladores, servicios, repositorios, tests, dependencias ni frontend.

---

## 3. Cambios técnicos

### 3.1 Detección del JDK

`set-dev-env.ps1` ya no usa una ruta fija. Prueba en orden:

1. `-JavaHome`.
2. `VPLAN_JAVA_HOME`.
3. `JAVA_HOME`.
4. `javac.exe` del `PATH`.
5. Rutas habituales de Windows (Adoptium, Java, Microsoft, Corretto, Zulu,
   BellSoft y el JDK incluido con NetBeans).

Descarta candidatos anteriores a Java 21 y, si ninguno sirve, muestra qué
versiones rechazó y cómo indicar una ruta. No modifica variables del sistema.

### 3.2 Copia de seguridad

`backup-db.ps1`:

- Genera `backups\vplan-AAAA-MM-DD_HHmmss.sql`.
- Usa `--single-transaction --no-tablespaces --skip-add-locks --skip-triggers
  --set-gtid-purged=OFF --result-file`.
- Comprueba que el archivo contiene `tareas` y `flyway_schema_history`.
- Pasa la contraseña por `MYSQL_PWD` solo durante el proceso y restaura el valor
  anterior al terminar.
- No imprime la contraseña.

### 3.3 Restauración

`restore-db.ps1`:

- Exige un archivo existente y con las dos tablas.
- Rechaza dumps con `CREATE DATABASE` o `USE`.
- Se niega a continuar si algo escucha en el puerto 8080 (salvo `-Force`).
- Pide escribir `RESTAURAR`.
- Restaura con `mysql` y verifica después las migraciones y el número de tareas.

### 3.4 Privacidad local

- Tomcat: `server.address: 127.0.0.1`.
- URL JDBC por defecto: `jdbc:mysql://127.0.0.1:3306/vplan...`.
- MySQL: `bind-address=127.0.0.1` documentado en `INSTALACION.md` y en la guía de
  base de datos. **No se cambió la configuración global del ordenador de clase**,
  según las condiciones de la tarea.

---

## 4. Verificación real ejecutada

### 4.1 Tests

```text
Tests run: 34, Failures: 0, Errors: 0, Skipped: 0
BUILD SUCCESS
```

Código de salida de Maven: `0`.

### 4.2 Detección de Java

| Caso | Resultado |
|---|---|
| Entorno del aula (`JAVA_HOME` y `javac` apuntan a Java 8/11) | Detecta el JDK 25 por rutas habituales |
| `-JavaHome` explícito | Usa el JDK indicado |
| `-JavaHome` inexistente | Continúa la búsqueda y encuentra otro válido |
| Solo JDK 11 disponible (rutas habituales simuladas) | Error controlado: «No se ha encontrado un JDK 21 o superior» y menciona el JDK 11 descartado |

### 4.3 Lectura UTF-8 de `.env.local`

La función `Read-DotEnvFile` leyó correctamente un valor con `ñ` y `á` desde un
archivo UTF-8 sin BOM.

### 4.4 Aplicación y MySQL reales

| Comprobación | Resultado |
|---|---|
| Arranque | `Started VPlanApplication` |
| Flyway | `Current version of schema vplan: 2` |
| URL JDBC usada | `jdbc:mysql://127.0.0.1:3306/vplan...` |
| `/api/health` | `200`, `status=UP`, `database=UP` |
| `POST /api/tareas` | Creada la tarea temporal `Portabilidad E2E` (id 19) |
| `GET /api/tareas` | 1 tarea |
| `DELETE /api/tareas/19` | `204`; después 0 tareas |
| Escucha del puerto 8080 | Solo `127.0.0.1` |
| Acceso desde otro equipo de la red local (1) | No alcanzable |
| Acceso desde otro equipo de la red local (2) | No alcanzable |

### 4.5 Backup

| Comprobación | Resultado |
|---|---|
| Ejecución con entorno cargado | Correcta |
| Ejecución sin cargar entorno (solo `.env.local`) | Correcta, código `0` |
| Archivo generado | 3.906 bytes |
| Contiene `tareas` | Sí |
| Contiene `flyway_schema_history` | Sí |
| Contiene la tarea real | Sí (`Portabilidad E2E`) |
| Contiene `LOCK TABLES` | No |
| Contiene `CREATE DATABASE` o `USE` | No |
| `git check-ignore` | `.gitignore:22:backups/` |

### 4.6 Restauración en base independiente

Se levantó una instancia MySQL 8.0.45 temporal, aislada, en `127.0.0.1:3317`,
con un directorio de datos en `%TEMP%`. **No se tocó `vplan`.**

| Comprobación | Resultado |
|---|---|
| Base de destino | `vplan_restore_test` |
| Restauración | Correcta |
| Tareas restauradas | 1 (`Portabilidad E2E`) |
| Migraciones | `v1 init success=1`, `v2 single user success=1` |
| Tablas | `tareas`, `flyway_schema_history` |
| Archivo inválido | Rechazado con mensaje claro |
| Limpieza | Instancia detenida; directorio temporal eliminado; puerto 3317 libre |

### 4.7 Protecciones de restauración

Con VPlan abierto en el puerto 8080, `restore-db.ps1` sin `-Force` se negó a
continuar:

```text
Hay algo escuchando en el puerto 8080. Deten VPlan (Ctrl+C) antes de restaurar.
```

La base siguió con 1 tarea: no se modificó nada.

### 4.8 Secretos

```text
OK: los valores de .env.local no aparecen en ningun archivo del proyecto.
```

Código de salida: `0`.

### 4.9 Estado final

| Comprobación | Resultado |
|---|---|
| `FILAS_TAREAS` | 0 |
| Migraciones | `v1 init success=true`, `v2 single user success=true` |
| Puerto 8080 | Libre |
| Puerto 9222 | Libre |
| Puerto 3317 | Libre |
| Aplicación / Chrome | Detenidos |
| Copias de prueba | Eliminadas |
| Commits | Ninguno (no autorizado) |

---

## 5. Incidencias encontradas durante la verificación

1. **`restore-db.ps1` fallaba con stderr vacío.** `Get-Content -Raw` devolvía
   `$null` y `.Trim()` lanzaba una excepción después de restaurar. Corregido con
   una comprobación de nulos y verificado de nuevo.
2. **`backup-db.ps1` no contemplaba un dump vacío.** Se añadió una comprobación
   para borrar el archivo y fallar con un mensaje claro.
3. **Ruido de `mysqladmin` con `--skip-password`.** La herramienta imprime un
   aviso de contraseña en la interfaz; no expone ningún valor. Solo afectó al
   arnés temporal de pruebas, no a los scripts del proyecto.
4. **Rutas con espacios en `Start-Process`.** El arnés temporal necesitó citar
   `--basedir` y `--datadir`. Los scripts del proyecto no pasan rutas de MySQL
   por `Start-Process`, así que no estaban afectados.

---

## 6. Pendiente en el ordenador personal

1. Aplicar `bind-address=127.0.0.1` en el `my.ini` de MySQL y reiniciar el
   servicio. En el ordenador de clase **no se tocó** la configuración global.
2. Seguir `INSTALACION.md` en un Windows limpio.
3. Restaurar una copia real creada con `backup-db.ps1`.
4. Crear el primer commit cuando se autorice y configurar la identidad de Git.

---

## 7. Conclusión

VPlan ya no depende del JDK, las rutas ni los archivos locales del ordenador de
clase. La aplicación escucha solo en loopback, las credenciales siguen fuera del
repositorio y el ciclo copia/restauración está probado con datos reales en una
base independiente. El esquema, las migraciones, los tests y el frontend no se han
modificado.
