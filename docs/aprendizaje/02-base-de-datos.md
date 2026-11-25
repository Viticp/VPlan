# Base de datos y Flyway

## 1. Qué guardamos

Una sola tabla, `tareas`: VPlan es de un único usuario, así que no hay
dueño de la tarea ni relación con ninguna tabla de usuarios.

### `tareas`

| Columna | Tipo | Por qué |
|---|---|---|
| `id` | `BIGINT AUTO_INCREMENT` | Clave primaria |
| `titulo` | `VARCHAR(120)` | Obligatorio |
| `descripcion` | `VARCHAR(2000)` | Opcional, texto libre acotado |
| `prioridad` | `VARCHAR(10)` + `CHECK` | `BAJA`, `MEDIA`, `ALTA` |
| `estado` | `VARCHAR(20)` + `CHECK` | `PENDIENTE`, `EN_PROCESO`, `COMPLETADA` |
| `fecha_limite` | `DATE` | Opcional; sin hora, porque el requisito es una fecha |
| `creado_en` | `TIMESTAMP` | Auditoría |
| `actualizado_en` | `TIMESTAMP` | Se actualiza desde JPA en cada cambio |

**¿Por qué `VARCHAR + CHECK` y no `ENUM`?** MySQL y H2 lo aceptan igual, permite
evolucionar los valores sin `ALTER TABLE` complicados y el error salta en la base
de datos, no solo en Java.

**Índices**

- `estado` → el filtro más frecuente.
- `fecha_limite` → ordenar por vencimiento.
- `prioridad` → filtros por prioridad.

Las tareas se llaman `tareas` y no `tasks` porque el resto del código (entidades,
DTOs, endpoints) usa español, igual que las columnas.

## 2. Por qué Flyway

`spring.jpa.hibernate.ddl-auto: validate` significa: *Hibernate no crea ni cambia
tablas; solo comprueba que las entidades encajan con el esquema real*.

El esquema lo controla Flyway con archivos versionados:

```text
src/main/resources/db/migration/
├─ V1__init.sql          Esquema inicial (con usuarios y tareas)
└─ V2__single_user.sql   Elimina usuarios y tareas.usuario_id
```

Al arrancar, Flyway:

1. Crea la tabla `flyway_schema_history` si no existe.
2. Compara las migraciones del proyecto con las ya aplicadas.
3. Ejecuta las pendientes, en orden.
4. Si alguna falla, detiene el arranque. Nunca deja el esquema a medias.

Reglas:

- Una migración ya aplicada **no se edita**. Se añade otra (`V3__...`).
- Los nombres siguen `V<número>__descripcion.sql`.
- En producción, un cambio destructivo se planifica; no se improvisa.

**Caso real de VPlan:** al pasar a un solo usuario, `V1` no se tocó. Se creó
`V2__single_user.sql`, que elimina la clave foránea, los índices que empezaban por
`usuario_id`, la columna `usuario_id` y la tabla `usuarios`. Se pudo hacer sin
perder datos porque ambas tablas estaban vacías. Si hubiera habido tareas, el
cambio se habría planificado de otra forma (por ejemplo, conservando la columna
hasta migrar los datos).

Ventaja frente a `ddl-auto: update`: el historial es reproducible, revisable en Git
y no depende de cómo Hibernate interprete las entidades.

## 3. Compatibilidad con los tests

Los tests usan H2 en modo MySQL. Para que los mismos scripts funcionen en los dos
motores hay que conocer las diferencias:

- Se evitan `ENGINE=InnoDB` y `COLLATE` por tabla.
- Se evita `ENUM` de MySQL.
- Se evita `ON UPDATE CURRENT_TIMESTAMP`.
- Se evitan tipos exclusivos como `TEXT` (se usa `VARCHAR(2000)`).
- En `V2`: la clave foránea se elimina con `DROP FOREIGN KEY` (H2 lo acepta en
  modo MySQL), los índices se eliminan **antes** de la columna y cada
  `DROP COLUMN` va en su propia sentencia: H2 no admite varios en un mismo
  `ALTER TABLE`.

El charset y la collation se definen una sola vez al crear la base de datos
(`database/00_create_database_and_user.sql`).

## 4. Cómo inspeccionar la base de datos

En MySQL Workbench, tras ejecutar los scripts:

```sql
USE vplan;
SHOW TABLES;
DESCRIBE tareas;

SELECT version, description, success
FROM flyway_schema_history
ORDER BY installed_rank;
```

La tabla `flyway_schema_history` es el registro de migraciones aplicadas.

## 5. Credenciales

La aplicación se conecta como `vplan_app`, un usuario **sin privilegios
globales**, solo sobre el esquema `vplan`. La contraseña se pasa por la variable
de entorno `VPLAN_DB_PASSWORD`; no se escribe en `application.yml` ni se sube
a Git.

> **Cuidado con el script SQL.** `database/00_create_database_and_user.sql` debe
> seguir versionado con el marcador `CAMBIA_ESTA_CONTRASENA`. Si lo ejecutas
> sustituyendo el marcador por la contraseña real, **no guardes el archivo**: o
> deshaces el cambio, o ejecutas el `ALTER USER` directamente en la consola de
> MySQL. Un script con la contraseña dentro acabaría en el repositorio.

## 6. Copias de seguridad y restauración

Una copia válida incluye **toda** la base `vplan`:

- `tareas`, con los datos.
- `flyway_schema_history`, para que Flyway sepa qué migraciones ya están
  aplicadas.

Restaurar solo `tareas` rompe el arranque: Flyway intentaría aplicar `V1` sobre un
esquema que ya existe.

```powershell
. .\scripts\set-dev-env.ps1
.\scripts\backup-db.ps1
```

`backup-db.ps1` usa `mysqldump` con:

- `--single-transaction`: copia consistente sin bloquear la aplicación.
- `--no-tablespaces`: obligatorio porque `vplan_app` no tiene el privilegio
  global `PROCESS`.
- `--skip-add-locks` y `--skip-triggers`: la restauración no necesita privilegios
  extra.
- `--result-file`: evita el problema de codificación de `>` en PowerShell 5.1,
  que escribiría UTF-16.

El archivo se guarda en `backups/`, ignorado por Git porque contiene datos
personales. Para restaurar, con la aplicación parada:

```powershell
.\scripts\restore-db.ps1 -BackupFile ".\backups\vplan-2026-11-17_120000.sql"
```

El script valida el archivo, comprueba que el puerto 8080 está libre y pide
escribir `RESTAURAR`. Al terminar verifica las migraciones y el número de tareas.

**No copies la carpeta `data/` de MySQL**: no es portable entre versiones ni
sistemas. El dump SQL sí lo es.

## 7. MySQL solo en local

VPlan es una aplicación privada. Además de `server.address: 127.0.0.1` en
Spring Boot, MySQL debe escuchar solo en loopback:

```ini
# my.ini, sección [mysqld]
bind-address=127.0.0.1
```

Después de reiniciar el servicio, `Get-NetTCPConnection -LocalPort 3306 -State
Listen` debe mostrar `127.0.0.1` y no `::` ni `0.0.0.0`. Instrucciones completas
en [INSTALACION.md](../../INSTALACION.md).

