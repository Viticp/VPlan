# Fase 2 — Base de datos y estructura del proyecto

> Documento histórico de la Fase 2. Las rutas concretas del equipo donde se
> desarrolló no son requisitos: la instalación portable se describe en
> [INSTALACION.md](../../INSTALACION.md).

## Objetivo

Dejar preparado el proyecto sin implementar todavía el backend: build reproducible,
esquema de base de datos versionado, entorno de desarrollo por sesión y documentación.

## Responsable de escritura

- OpenCode: implementación.
- Hermes: revisión en modo lectura.
- Un solo escritor a la vez, según `PROTOCOLO.md`.

## Decisiones aplicadas

| Decisión | Valor |
|---|---|
| Java objetivo | 21 (`--release 21`) |
| JDK de ejecución | Temurin 25 (detectado automáticamente) |
| Spring Boot | 3.5.16 |
| Build | Maven Wrapper 3.3.4 + Maven 3.9.16 |
| Base de datos | MySQL 8 (`vplan`, usuario `vplan_app`) |
| Tests | H2 2.3.232 en modo MySQL |
| Migraciones | Flyway 11.7.2 |
| Git | Solo repositorio local; sin identidad configurada |

## Archivos entregados

Build y configuración:

- `pom.xml`
- `mvnw`, `mvnw.cmd`, `.mvn/wrapper/maven-wrapper.jar`, `.mvn/wrapper/maven-wrapper.properties`
- `src/main/resources/application.yml`
- `src/test/resources/application-test.yml`
- `src/main/resources/db/migration/V1__init.sql`

Base de datos (los ejecuta la persona, no los agentes):

- `database/00_create_database_and_user.sql`
- `database/01_verify.sql`

Entorno:

- `scripts/set-dev-env.ps1`

Repositorio:

- `.gitignore`, `.gitattributes`, `.editorconfig`
- `.git/` inicializado en rama `main` (sin commits)

Documentación:

- `README.md`
- `docs/aprendizaje/01-arquitectura.md`
- `docs/aprendizaje/02-base-de-datos.md`
- `docs/aprendizaje/03-entorno-y-maven.md`
- `docs/colaboracion/PROTOCOLO.md`
- `docs/colaboracion/PLANTILLA-HANDOFF.md`

## Comprobaciones ejecutadas

| Comprobación | Comando / método | Resultado |
|---|---|---|
| Ruta del proyecto disponible | `Test-Path` | ✅ Creada en `<ruta-del-proyecto>` |
| El script de entorno funciona | dot-source + `java -version` | ✅ JAVA_HOME = Temurin 25.0.2 |
| El script rechaza un JDK viejo | `-JavaHome` apuntando a JDK 11 | ✅ Error controlado: «necesita Java 21 o superior» |
| Maven Wrapper | `.\mvnw.cmd -v` | ✅ Maven 3.9.16, Java 25.0.2 |
| Dependencias del `pom.xml` | `.\mvnw.cmd -B -q dependency:resolve` | ✅ Código de salida 0 |
| Sintaxis de `application.yml` | SnakeYAML 2.4 | ✅ Claves `spring`, `server`, `logging` |
| `V1__init.sql` en H2 modo MySQL | `RunScript` + consultas | ✅ Crea `usuarios` y `tareas`; inserta; `ON DELETE CASCADE` funciona |
| Script administrativo de MySQL | — | ⛔ **No ejecutado** (lo ejecuta la persona con root) |
| MySQL real | — | ⛔ **No modificado** |
| Git local sin identidad | `git config --local --list` | ✅ Sin `user.name` ni `user.email` |

Nota: Maven muestra un aviso de Jansi sobre métodos restringidos de Java 25. Es
inofensivo y no afecta al build.

## Revisión de Hermes (transcrita literalmente, resumida)

> 1. **ALTA** — `JAVA_HOME` fijado a la ruta de NetBeans; falla en otro equipo.
> 2. **MEDIA** — `flyway-mysql` sería redundante porque Flyway 11 incluye MySQL.
> 3. **MEDIA** — `sslMode=DISABLED` es inseguro en producción.
> 4. **BAJA** — Los `CHECK` con literales obligan a migrar si cambian los valores.
> 5. **BAJA** — `maximum-pool-size: 5` es conservador.
> 6. **BAJA** — El placeholder de contraseña está en un archivo versionado.

### Resolución de OpenCode

| Punto | Decisión | Motivo |
|---|---|---|
| 1 | **Aceptado y corregido** | El script acepta `-JavaHome` o `VPLAN_JAVA_HOME`, valida que el JDK sea ≥ 21 y mantiene la ruta del equipo como valor por defecto |
| 2 | **Rechazado con evidencia** | `flyway-core-11.7.2.jar` contiene **0** clases de MySQL; `flyway-mysql-11.7.2.jar` contiene las 11 clases del driver (verificado con `jar tf`). Sin esa dependencia Flyway no reconoce MySQL |
| 3 | **Aceptado como documentación** | Es una URL de desarrollo local; ya es sustituible con `VPLAN_DB_URL` y se añadió un comentario que exige `sslMode=VERIFY_IDENTITY` en producción |
| 4 | **Rechazado** | Los `CHECK` son una garantía de integridad deliberada. Cambiar valores se hace con una migración nueva, que es el procedimiento correcto; una tabla de referencia sería complejidad innecesaria para este alcance |
| 5 | **Rechazado para desarrollo** | 5 conexiones sobran para un uso personal y evitan consumir conexiones del MySQL local; se puede subir por variable si hiciera falta |
| 6 | **Rechazado** | `CAMBIA_ESTA_CONTRASENA` es un marcador, no un secreto. El script debe ser ejecutable por la persona; la contraseña real nunca se guarda en el repositorio |

## Bloqueadores / pendientes

- Ejecutar `database/00_create_database_and_user.sql` como root (lo hace la persona).
- Definir `VPLAN_DB_PASSWORD` en la sesión.
- Identidad de Git (nombre y email) para poder hacer el primer commit.
- Verificar el script SQL contra MySQL real al inicio de la Fase 3.

## Estado

- [x] Implementado
- [x] Revisado por Hermes
- [ ] Aprobado por la persona
