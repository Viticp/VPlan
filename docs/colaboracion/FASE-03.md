# Fase 3 — Arranque del backend y endpoint de salud

## Objetivo

Conseguir que VPlan arranque con Spring Boot, se conecte a MySQL mediante
Flyway y exponga `GET /api/health` con una comprobación real de la base de datos.

## Responsable de escritura

- OpenCode: implementación, ejecución y documentación de la fase.
- Hermes: coordinación previa y revisión independiente (`REVISION-HERMES.md`).
- Sin escritura simultánea sobre `src/`.

## Archivos creados

Código:

- `src/main/java/com/vplan/VPlanApplication.java`
- `src/main/java/com/vplan/config/SecurityConfig.java`
- `src/main/java/com/vplan/common/HealthController.java`
- `src/main/java/com/vplan/common/HealthResponse.java`

Tests:

- `src/test/java/com/vplan/VPlanApplicationTests.java`
- `src/test/java/com/vplan/HealthControllerTest.java`

Entorno y documentación:

- `scripts/set-db-password.ps1`
- `scripts/set-dev-env.ps1` (carga `.env.local`)
- `.env.example`
- `.gitignore` (`.env.local`)
- `docs/aprendizaje/04-arranque-y-health.md`
- `README.md`

## Comprobaciones ejecutadas (resultados reales)

| Comprobación | Comando / método | Resultado |
|---|---|---|
| Java y Maven | `.\mvnw.cmd -v` | ✅ Maven 3.9.16 / Temurin 25.0.2 |
| Contraseña disponible | comprobación booleana de `VPLAN_DB_PASSWORD` | ✅ Definida (valor nunca impreso) |
| Arranque contra MySQL | `.\mvnw.cmd spring-boot:run` | ✅ Tomcat en 8080 en 2,018 s |
| Conexión MySQL | log de Hikari + consulta JDBC directa | ✅ MySQL 8.0.45, base `vplan` |
| Migración Flyway | log de Flyway + `flyway_schema_history` | ✅ `V1` aplicada, `success=true` |
| Tablas creadas | consulta directa | ✅ `usuarios`, `tareas`, `flyway_schema_history` |
| Endpoint de salud | `GET http://localhost:8080/api/health` | ✅ HTTP 200, `database=UP` |
| Tests automatizados | `.\mvnw.cmd -B test` | ✅ 2 tests, 0 fallos |
| Fail-fast sin contraseña | arranque con la variable ausente | ✅ Mensaje claro y código 1 |
| `.env.local` fuera de Git | `git status` + `.gitignore` | ✅ Ignorado y no listado |

### Evidencia de Flyway (log real)

```text
Database: jdbc:mysql://localhost:3306/vplan?... (MySQL 8.0)
Schema history table `vplan`.`flyway_schema_history` does not exist yet
Creating Schema History table `vplan`.`flyway_schema_history` ...
Migrating schema `vplan` to version "1 - init"
Successfully applied 1 migration to schema `vplan`, now at version v1
```

### Evidencia de la consulta directa a MySQL

```text
MYSQL_VERSION=8.0.45
CATALOG=vplan
TABLE=flyway_schema_history
TABLE=tareas
TABLE=usuarios
FLYWAY=1 | init | success=true
```

### Respuesta real de `/api/health`

```http
HTTP/1.1 200
Content-Type: application/json
```

```json
{
  "status": "UP",
  "application": "vplan",
  "database": "UP",
  "timestamp": "2026-11-17T08:57:47.837051400Z"
}
```

La aplicación se detuvo después de la comprobación y el puerto 8080 quedó libre.

## Decisiones técnicas

1. **Health con `SELECT 1`** en lugar de un texto fijo: demuestra la conexión real.
2. **503 si la base de datos falla**, 200 si todo está bien.
3. **Health público**, resto de rutas autenticadas. Sin login todavía, el resto
   responde 403.
4. **CSRF activado** desde el principio; se completará en la Fase 4.
5. **Sin usuario por defecto de Spring**: se excluye
   `UserDetailsServiceAutoConfiguration` para no generar ni registrar contraseñas.
6. **Fail-fast explícito** si falta `VPLAN_DB_PASSWORD`, para evitar el
   confuso `Access denied ... (using password: YES)` que produce enviar el
   placeholder literal.
7. **Timeout de 3 s en Hikari** para que `/api/health` no se quede colgado 30 s
   si MySQL está caído.

## Revisión independiente de Hermes

Informe completo: [`REVISION-HERMES.md`](REVISION-HERMES.md).

**Veredicto:** la Fase 3 cumple los requisitos funcionales y de seguridad.

| Nivel | Hallazgos |
|---|---|
| Crítico | Ninguno |
| Alto | Ninguno |
| Medio | 4 (HEAD/OPTIONS en health, `SELECT 1` trivial, SSL de desarrollo, exclusión temporal de seguridad) |
| Bajo | 4 (campos duplicados, matchers explícitos, nivel de log de Flyway, evidencia de health) |

Ningún hallazgo bloquea la fase. Los puntos medios son decisiones conscientes
documentadas o mejoras para producción/Fase 4.

## Hallazgo de seguridad detectado al cerrar la fase

Durante la verificación final, un escaneo del árbol del proyecto (comparando el
contenido de cada archivo con el valor de `VPLAN_DB_PASSWORD`, sin imprimirlo)
reveló que `database/00_create_database_and_user.sql` contenía la contraseña real
de `vplan_app` en las líneas `IDENTIFIED BY`. La persona la había sustituido
por el marcador al ejecutar el script y el archivo se quedó así.

- **Riesgo:** el script está versionado; en el primer `git add` la contraseña
  habría entrado en el historial.
- **Corrección aplicada:** se restauró el marcador `CAMBIA_ESTA_CONTRASENA` en las
  dos líneas (`CREATE USER` y `ALTER USER`). La contraseña sigue disponible en
  `.env.local`, que está ignorado por Git, así que no se ha perdido nada.
- **Prevención:** se añadió un aviso en `docs/aprendizaje/02-base-de-datos.md`
  y un script comprobable, `scripts/check-no-secrets.ps1`, que compara el valor
  real de cada variable sensible de `.env.local` con todos los archivos del
  proyecto y falla (código 1) si aparece escrito. Probado en positivo (detecta un
  secreto ficticio) y en limpio (código 0).
- **Alcance:** no había ningún commit, por lo que la contraseña nunca llegó al
  historial de Git, y no aparecía en `target/` ni en los logs.

## Pendiente

- Aprobación de la persona antes de iniciar la Fase 4.

## Estado

- [x] Implementado
- [x] Tests automáticos en verde
- [x] Verificado contra MySQL real
- [x] Revisado por Hermes
- [x] Aprobado por la persona

## Nota posterior: cambio de alcance

Después de aprobar esta fase, se decidió convertir VPlan en una aplicación
personal **sin login ni registro**. Eso eliminó Spring Security, `SecurityConfig`,
la tabla `usuarios` y `tareas.usuario_id` mediante la migración
`V2__single_user.sql`.

Este informe se conserva **sin reescribir** como registro de lo que se hizo y
verificó en su momento. Los detalles de la adaptación están en
[`ADAPTACION-UN-SOLO-USUARIO.md`](ADAPTACION-UN-SOLO-USUARIO.md).
