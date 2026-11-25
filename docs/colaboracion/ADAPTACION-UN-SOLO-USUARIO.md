# Adaptación a una aplicación de un solo usuario

**Fecha:** 2026-11-17
**Responsable de escritura:** OpenCode
**Revisión independiente:** Hermes (`REVISION-HERMES-ADAPTACION.md`)
**Alcance:** retirar la autenticación prevista y adaptar el esquema. **No** incluye
el CRUD de tareas, que sigue pendiente de aprobación.

---

## 1. Decisión

VPlan deja de ser una aplicación con registro y login. Pasa a ser una
aplicación **personal, de un solo usuario y de uso local**.

Consecuencias:

- Ninguna ruta requiere identificarse.
- No hay tabla de usuarios ni dueño de las tareas.
- La aplicación **no debe exponerse en internet** sin protección.

## 2. Qué existía realmente

No había autenticación implementada: ni entidad `Usuario`, ni repositorio, ni
`UserDetailsService`, ni controlador de login. Solo existía la configuración que
la bloqueaba a la espera de una fase futura:

| Elemento | Ubicación original |
|---|---|
| Dependencia de seguridad | `pom.xml` (`spring-boot-starter-security`) |
| Dependencia de test | `pom.xml` (`spring-security-test`) |
| Exclusión de autoconfiguración | `VPlanApplication.java` |
| Reglas de autorización | `src/main/java/com/vplan/config/SecurityConfig.java` |
| Tabla `usuarios` | `V1__init.sql` |
| Relación `tareas.usuario_id` | `V1__init.sql` (FK + 3 índices) |

## 3. Cambios aplicados

| Archivo | Cambio |
|---|---|
| `pom.xml` | Eliminadas `spring-boot-starter-security` y `spring-security-test` |
| `config/SecurityConfig.java` | Eliminado (solo contenía reglas de autorización) |
| `VPlanApplication.java` | Eliminada la exclusión de `UserDetailsServiceAutoConfiguration` |
| `db/migration/V2__single_user.sql` | **Nuevo**: elimina FK, índices y columna `usuario_id`, y la tabla `usuarios` |
| `src/test/java/com/vplan/SchemaSingleUserTest.java` | **Nuevo**: comprueba el esquema resultante |
| Documentación | `README.md`, `01-arquitectura.md`, `02-base-de-datos.md`, `04-arranque-y-health.md`, `FASE-03.md` |

`V1__init.sql` **no se modificó**. La base de datos no se borró ni se recreó.

### Migración `V2__single_user.sql`

```sql
ALTER TABLE tareas DROP FOREIGN KEY fk_tareas_usuario;
DROP INDEX idx_tareas_usuario_estado ON tareas;
DROP INDEX idx_tareas_usuario_fecha ON tareas;
DROP INDEX idx_tareas_usuario_prioridad ON tareas;
ALTER TABLE tareas DROP COLUMN usuario_id;
DROP TABLE usuarios;

CREATE INDEX idx_tareas_estado ON tareas (estado);
CREATE INDEX idx_tareas_fecha ON tareas (fecha_limite);
CREATE INDEX idx_tareas_prioridad ON tareas (prioridad);
```

Detalles que condicionan el orden y que se comprobaron antes de escribir la
migración:

- La clave foránea se elimina antes que la columna que la usa.
- H2 exige eliminar los índices **antes** de la columna que los compone.
- H2 no admite varios `DROP COLUMN` en un mismo `ALTER TABLE`: van separados.
- `DROP FOREIGN KEY` funciona tanto en MySQL 8 como en H2 en modo MySQL.

### Pérdida de datos

Ninguna. Antes de aplicar la migración se comprobó por JDBC que `usuarios` y
`tareas` tenían **0 filas**. Si hubiera habido tareas, se habría planificado un
cambio no destructivo (conservar la columna hasta migrar los datos).

## 4. Verificación

### 4.1 Tests con H2 (primero)

```text
HealthControllerTest        Tests run: 1, Failures: 0, Errors: 0
SchemaSingleUserTest        Tests run: 2, Failures: 0, Errors: 0
VPlanApplicationTests    Tests run: 1, Failures: 0, Errors: 0
Tests run: 4, Failures: 0, Errors: 0, Skipped: 0 — BUILD SUCCESS
```

Flyway aplicó `V1` y `V2` sobre H2 en memoria, y los tests confirman que
`usuarios` ya no existe y que `tareas` conserva `estado` pero no `usuario_id`.

### 4.2 MySQL real (después)

```text
Database: jdbc:mysql://localhost:3306/vplan?... (MySQL 8.0)
Current version of schema `vplan`: 1
Migrating schema `vplan` to version "2 - single user"
Successfully applied 1 migration to schema `vplan`, now at version v2 (78 ms)
Tomcat started on port 8080
Started VPlanApplication in 1.919 seconds
```

Consultas directas a la base de datos:

```text
MYSQL_VERSION=8.0.45
TABLA=flyway_schema_history
TABLA=tareas
FLYWAY=1 | init | success=true
FLYWAY=2 | single user | success=true
COLUMNA_TAREAS=id bigint null=NO
COLUMNA_TAREAS=titulo varchar(120) null=NO
COLUMNA_TAREAS=descripcion varchar(2000) null=YES
COLUMNA_TAREAS=prioridad varchar(10) null=NO
COLUMNA_TAREAS=estado varchar(20) null=NO
COLUMNA_TAREAS=fecha_limite date null=YES
COLUMNA_TAREAS=creado_en timestamp null=NO
COLUMNA_TAREAS=actualizado_en timestamp null=NO
INDICE_TAREAS=PRIMARY col=id
INDICE_TAREAS=idx_tareas_estado col=estado
INDICE_TAREAS=idx_tareas_fecha col=fecha_limite
INDICE_TAREAS=idx_tareas_prioridad col=prioridad
FILAS_TAREAS=0
```

No aparece la tabla `usuarios` ni la columna `usuario_id`.

### 4.3 Endpoint de salud

```http
GET http://localhost:8080/api/health  → 200
{"status":"UP","application":"vplan","database":"UP","timestamp":"2026-11-17T09:19:37.446408200Z"}

HEAD http://localhost:8080/api/health → 200
```

El endpoint no se ha modificado. `HEAD` también responde 200: al no existir reglas
de seguridad, ya no hay diferencia entre métodos.

### 4.4 Secretos

`scripts/check-no-secrets.ps1` → `OK: los valores de .env.local no aparecen en
ningún archivo del proyecto` (código 0).

## 5. Seguridad y alcance

- VPlan se ejecuta en `localhost:8080`, en el equipo de la persona.
- **No hay autenticación**: cualquiera con acceso al puerto podría leer y
  modificar las tareas. Por eso no debe publicarse en internet tal cual.
- Para desplegarla haría falta: autenticación, HTTPS y una revisión de seguridad.
- Sin cookies de sesión, la protección CSRF no aporta nada: no hay credencial que
  un sitio externo pueda reutilizar.
- Las credenciales de MySQL siguen fuera del repositorio (`.env.local` ignorado).
- El mensaje de error del servidor sigue sin incluir trazas ni detalles internos.

Este aviso está también en el `README.md` y en
`docs/aprendizaje/04-arranque-y-health.md`.

## 6. Lo que no se ha tocado

- `V1__init.sql` y el historial de Flyway.
- `application.yml` (datasource, Hikari, Flyway, `ddl-auto: validate`, puerto).
- `HealthController` y `HealthResponse`.
- Maven Wrapper, scripts de entorno y `.env.local`.
- La base de datos `vplan` (misma base, mismos datos: 0 tareas).
- El servicio MySQL y la configuración del sistema.

## 7. Estado

- [x] Implementado
- [x] Verificado primero en H2 y después en MySQL real
- [x] Tests automatizados en verde (4)
- [x] `check-no-secrets.ps1` en verde
- [x] Documentado el uso local y la prohibición de exponerlo sin protección
- [x] Revisado por Hermes
- [ ] Aprobado por la persona
- [x] CRUD de tareas: implementado en la Fase 4 (ver
  [`FASE-04.md`](FASE-04.md)), pendiente de aprobación
