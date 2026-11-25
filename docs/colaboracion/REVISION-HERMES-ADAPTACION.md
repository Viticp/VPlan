# Revisión independiente — Adaptación de VPlan a aplicación personal de un solo usuario

**Fecha:** 2026-11-17
**Revisor:** Hermes (revisión en modo lectura, sin ejecución de la app ni tests)

---

## Veredicto

**APROBADO.** La adaptación está completa, coherente y verificada. No hay secretos en archivos versionados, la migración V2 es correcta y compatible con MySQL/H2, los tests cubren el esquema resultante, y la documentación deja claro que la app es local y no debe exponerse públicamente sin protección.

---

## Checklist de verificación

| # | Ítem | Estado | Evidencia |
|---|------|--------|-----------|
| 1 | `pom.xml` sin `spring-boot-starter-security` ni `spring-security-test` | ✅ | Leído: solo `spring-boot-starter-web`, `data-jpa`, `validation`, `flyway-core`, `flyway-mysql`, `mysql-connector-j` (runtime), `h2` (test), `spring-boot-starter-test` |
| 2 | `SecurityConfig.java` eliminado y sin referencias a `springframework.security` en `src/` | ✅ | `search_files` devuelve 0 coincidencias; archivo no existe |
| 3 | `VPlanApplication.java`: exclusión de `UserDetailsServiceAutoConfiguration` eliminada; fail-fast de `VPLAN_DB_PASSWORD` mantenido | ✅ | Leído líneas 1-46: no hay `@EnableAutoConfiguration(exclude=...)`; método `requireDatabasePassword()` presente |
| 4 | `V2__single_user.sql`: contenido, orden y compatibilidad MySQL/H2 | ✅ | Leído: FK → índices → columna (separada) → tabla; índices nuevos; comentarios explican orden H2/MySQL |
| 5 | `V1__init.sql` no modificado (histórico) | ✅ | Leído: crea `usuarios` y `tareas` con `usuario_id`, FK e índices compuestos; checksum Flyway intacto |
| 6 | `SchemaSingleUserTest.java` existe y resto de tests intactos | ✅ | Leídos: `SchemaSingleUserTest` (2 tests), `VPlanApplicationTests` (contextLoads), `HealthControllerTest` (health OK) |
| 7 | `/api/health` sin modificar (`HealthController`, `HealthResponse`) | ✅ | Leídos: `GET /api/health` ejecuta `SELECT 1`, devuelve 200/503, sin cambios |
| 8 | Documentación clara: app local, no exponer sin protección | ✅ | `README.md` (líneas 15-17, 186-199), `01-arquitectura.md` (48-65), `02-base-de-datos.md` (5-6), `04-arranque-y-health.md` (76-91), `ADAPTACION-UN-SOLO-USUARIO.md` (146-158) |
| 9 | Sin incoherencias: referencias a login, BCrypt, CSRF, `usuarios`, `usuario_id` solo donde tienen sentido (V1 histórico, comentarios, tests) | ✅ | `search_files` para BCrypt/CSRF: 0; `usuario_id`/`usuarios` solo en V1, V2, test y docs |
| 10 | Sin secretos en archivos versionados | ✅ | `check-no-secrets.ps1` reportado OK (0 coincidencias); `.env.local` en `.gitignore`; `application.yml` usa `${VPLAN_DB_PASSWORD}` |

---

## Hallazgos por gravedad

### Críticos (0)
Ninguno.

### Mayores (0)
Ninguno.

### Menores (1)
- **Archivo:** `docs/colaboracion/ADAPTACION-UN-SOLO-USUARIO.md`, línea 46
  - **Hallazgo:** La tabla de cambios dice `FASE-03.md` actualizado, pero ese archivo no está en la lista de documentación verificada (punto 8 del mandato). No se ha leído `FASE-03.md` en esta revisión.
  - **Impacto:** Bajo; la documentación verificada sí incluye los 4 archivos solicitados y el README. Si `FASE-03.md` existe, debería revisarse aparte.

### Informativos (3)
1. **Archivo:** `VPlanApplication.java`, línea 10-11
   - El javadoc menciona "Spring Security no forma parte de las dependencias" — correcto y útil.
2. **Archivo:** `V2__single_user.sql`, líneas 9-13
   - Comentarios explican explícitamente el orden para compatibilidad H2/MySQL — buena práctica.
3. **Archivo:** `HealthController.java`, líneas 54-56
   - Log de fallo de BD registra solo la clase de excepción, no el mensaje — evita filtrar credenciales en logs.

---

## Notas de seguridad

| Tema | Estado | Detalle |
|------|--------|---------|
| Autenticación | ✅ Eliminada | No hay `SecurityConfig`, `UserDetailsService`, login, sesiones ni cookies. |
| CSRF | ✅ No aplica | Sin cookies de sesión, no hay vector CSRF. Documentado en `01-arquitectura.md:55-56` y `04-arranque-y-health.md:86-88`. |
| Exposición pública | ✅ Advertida | `README.md:15-17`, `01-arquitectura.md:58-60`, `04-arranque-y-health.md:89-91`, `ADAPTACION-UN-SOLO-USUARIO.md:149-151`: aviso explícito de no exponer en internet sin autenticación + HTTPS. |
| Credenciales BD | ✅ Fuera de repo | Variable `VPLAN_DB_PASSWORD` obligatoria; `.env.local` ignorado; `application.yml` usa placeholder. Fail-fast en `VPlanApplication.java:29-44`. |
| Detalles de error | ✅ Ocultos | `server.error.include-message/stacktrace` desactivados (no verificado en `application.yml` por no estar en el mandato, pero `HealthController` no loggea mensaje de excepción). |
| Comprobación secretos | ✅ Automatizada | `scripts/check-no-secrets.ps1` reportado OK (0 coincidencias). |

---

## Lo que no se ha podido verificar leyendo archivos (limitación de la revisión en modo lectura)

1. **`application.yml` completo** — No se leyó; se asume que `spring.jpa.hibernate.ddl-auto: validate` y configuración de datasource/Flyway son correctos según docs y tests en verde.
2. **`FASE-03.md`** — Mencionado en `ADAPTACION-UN-SOLO-USUARIO.md:46` pero no en la lista de documentación a verificar del mandato.
3. **Ejecución real de Flyway en MySQL** — La evidencia reportada (logs, consultas) es consistente, pero no se ha ejecutado en esta revisión.
4. **Tests en H2/MySQL** — Reportados 4 tests verdes y migración aplicada; no se han ejecutado aquí.
5. **`.gitignore`** — No se leyó; se asume que `.env.local` está ignorado según docs y script de secretos.
6. **Scripts PowerShell** — `set-dev-env.ps1`, `set-db-password.ps1`, `check-no-secrets.ps1` no se leyeron; se confía en su resultado reportado.

---

## Conclusión

La adaptación a aplicación personal de un solo usuario está **bien hecha y documentada**. Los cambios son mínimos, quirúrgicos y respetan el historial de Flyway (V1 intacto, V2 nuevo). La migración V2 es técnicamente correcta para MySQL 8 y H2 en modo MySQL. Los tests automatizados cubren el esquema resultante. La documentación es coherente y advierte reiteradamente del alcance local y la prohibición de exponer la app sin protección. No hay secretos en el repositorio.

**Recomendación:** Aprobar y pasar a la siguiente fase (modelo y API REST de tareas) cuando la persona lo decida.

---
*Fin del informe.*