# Revisión independiente — Fase 3 VPlan

**Fecha:** 2026-11-17  
**Revisor:** Hermes Agent (modo solo lectura)  
**Alcance:** Código, configuración, logs reales, tests y Git. Verificación real ejecutada.

---

## Veredicto general

**La Fase 3 CUMPLE los requisitos funcionales y de seguridad definidos en FASE-03.md.**  
El backend arranca, Flyway migra, `/api/health` responde 200 con `SELECT 1` real, y no hay secretos en archivos versionados. Verificación contra MySQL 8.0.45 completada: catálogo `vplan`, tablas `flyway_schema_history`, `tareas` y `usuarios` confirmadas; Flyway aplicó 1 migración (v1 init, success=true); health check real HTTP 200 con `{"status":"UP","database":"UP"}`.

---

## Checklist de cumplimiento

| Requisito (FASE-03.md) | Estado | Evidencia |
|---|---|---|
| Spring Boot arranca con Tomcat en 8080 | ✅ | `run-out.log` líneas 42, 72 |
| Flyway aplica `V1__init.sql` en MySQL 8.0 | ✅ | `run-out.log` líneas 50-56; `flyway_schema_history` creada; **MySQL real 8.0.45: catálogo `vplan`, tablas `flyway_schema_history`, `tareas`, `usuarios`; migración v1 init success=true** |
| `ddl-auto: validate` (Hibernate no crea tablas) | ✅ | `application.yml:24`; log línea 70 |
| `GET /api/health` público, ejecuta `SELECT 1` | ✅ | `HealthController.java:34-52`; test línea 24-28 |
| Respuesta 200 con `status=UP, database=UP` | ✅ | Test `HealthControllerTest`; **verificación real: HTTP 200, `{"status":"UP","application":"vplan","database":"UP","timestamp":"2026-11-17T08:57:47.837051400Z"}`; Tomcat arrancó en 8080, "Started VPlanApplication in 2.018 seconds"; app detenida, puerto 8080 libre** |
| Respuesta 503 si BD cae | ✅ | `HealthController.java:44-46` |
| Variables de entorno para BD (sin defaults de password) | ✅ | `application.yml:10-12`; `VPlanApplication.java:31-47` |
| `.env.local` ignorado por Git | ✅ | `.gitignore:15`; `git status` sin `.env.local` |
| CSRF activo, sin login aún (resto 403) | ✅ | `SecurityConfig.java:29-36` |
| Exclusión `UserDetailsServiceAutoConfiguration` | ✅ | `VPlanApplication.java:15` |
| Fail-fast si falta `VPLAN_DB_PASSWORD` | ✅ | `VPlanApplication.java:31-47`; comprobación manual líneas 50-56 FASE-03.md |
| Tests automatizados en verde (2 tests) | ✅ | `mvnw test` → 2 tests, 0 fallos |
| Sin contraseñas en código versionado | ✅ | Revisión completa: solo placeholders `${...}` |
| Logs sin filtrar credenciales | ✅ | `HealthController.java:56` loggea solo clase de excepción |

---

## Hallazgos por gravedad

### Crítico
**Ninguno.**

### Alto
**Ninguno.**

### Medio

| # | Archivo:Línea | Hallazgo | Impacto |
|---|---|---|---|
| M1 | `SecurityConfig.java:30` | `GET /api/health` permitido solo por método GET. Si se añade `HEAD` o `OPTIONS` en el futuro, quedarían autenticados (403). | Bajo ahora; rompería monitores que usan HEAD. |
| M2 | `HealthController.java:51` | `SELECT 1` sin `LIMIT 1` ni hint de índice. En MySQL es trivial, pero en tablas grandes o réplicas podría ser costoso. | Endpoint de salud debe ser barato. |
| M3 | `application.yml:10` | `sslMode=DISABLED` y `allowPublicKeyRetrieval=true` en URL por defecto. Documentado como solo desarrollo, pero el valor por defecto se usa si no se define `VPLAN_DB_URL`. | Riesgo si alguien despliega sin sobrescribir la variable. |
| M4 | `VPlanApplication.java:15` | Exclusión `UserDetailsServiceAutoConfiguration` es temporal (hasta Fase 4). Si se olvida quitarla, no habrá autenticación real. | Debe haber recordatorio en Fase 4. |

### Bajo

| # | Archivo:Línea | Hallazgo |
|---|---|---|
| L1 | `HealthResponse.java:13-17` | Campos `status` y `database` duplicados semánticamente hoy. Decisión documentada en FASE-03.md (línea 91) para extensibilidad. |
| L2 | `SecurityConfig.java:31` | Matchers estáticos explícitos (`/css/**`, `/js/**`, `/img/**`) en lugar de `PathRequest.toStaticResources()`. Más verboso pero legible. |
| L3 | `application.yml:44` | Log level `org.flywaydb: INFO` muestra detalles de migración (nombres de tablas, checksums). En producción considerar `WARN`. |

---

## Notas de seguridad

1. **Secretos:** Confirmado — no hay contraseñas, tokens ni claves en ningún archivo versionado (`.java`, `.yml`, `.sql`, `.md`, `pom.xml`, scripts). `.env.local` está en `.gitignore` y no aparece en `git status`.

2. **Logs:** `HealthController` registra solo `ex.getClass().getSimpleName()` (línea 56), nunca el mensaje de la excepción que podría contener host, usuario o cadena JDBC. Correcto.

3. **CSRF:** Activado por defecto (Spring Security default). No hay endpoints de escritura (POST/PUT/DELETE) en esta fase, por lo que no hay falsos 403 reales. Decisión documentada y razonable.

4. **Autorización:** Todas las rutas salvo `/api/health` y estáticos requieren autenticación (`anyRequest().authenticated()`). Al no haber `formLogin`, `httpBasic` ni `logout` (desactivados líneas 34-36), cualquier petición a ruta protegida devuelve 403. Comportamiento esperado hasta Fase 4.

5. **Riesgos futuros:**
   - La exclusión de `UserDetailsServiceAutoConfiguration` **debe** revertirse en Fase 4 al introducir `UserDetailsService` propio. Si no se hace, la app no tendrá autenticación real.
   - `sslMode=DISABLED` en URL por defecto: asegurar que en producción se defina `VPLAN_DB_URL` con `sslMode=VERIFY_IDENTITY` y certificado válido.
   - Hikari `connection-timeout: 3000` (línea 17) es agresivo; si la red tiene latencia >3s, `/api/health` fallará. Evaluar si 5-10s es más robusto.

---

## Conclusión

**La Fase 3 está aprobada para pasar a Fase 4.**

- Todos los requisitos funcionales verificados (arranque, Flyway, health check, tests).
- Postura de seguridad correcta para esta fase: sin secretos en repo, CSRF activo, fail-fast en configuración, logs limpios.
- Los hallazgos Medios/Bajos son decisiones conscientes documentadas o mejoras para fases posteriores, no bloqueadores.

---

*Fin del informe. Solo lectura — ningún archivo modificado.*

---

## ANEXO: Hallazgo de seguridad detectado al cerrar la fase (2026-11-17)

### 1. Reconocimiento del fallo de mi revisión
Mi informe original (línea 32 y 66) afirmó: "Sin contraseñas en código versionado" y "Confirmado — no hay contraseñas, tokens ni claves en ningún archivo versionado". Esa afirmación fue **incorrecta**. Mi revisión solo buscó patrones (`password`, `secret`, `token`, `${...}`) y no comparó el contenido real de `database/00_create_database_and_user.sql` contra el valor literal de `VPLAN_DB_PASSWORD` presente en `.env.local`. El archivo versionado contenía la contraseña real en las líneas con `IDENTIFIED BY` (CREATE USER y ALTER USER), no el marcador `CAMBIA_ESTA_CONTRASENA`.

### 2. Verificación propia del estado actual
He leído `database/00_create_database_and_user.sql` (líneas 17 y 21) y confirmo que **ahora solo contiene el marcador `CAMBIA_ESTA_CONTRASENA`** en ambas sentencias `IDENTIFIED BY`. La contraseña real reside únicamente en `.env.local` (ignorado por Git).

### 3. Veredicto de la fase
**Se mantiene: La Fase 3 está aprobada para pasar a Fase 4.**
- El repositorio está en `main` con **0 commits**; la contraseña nunca entró al historial de Git.
- Escaneo posterior sobre todo el proyecto (excluyendo `.env.local` y `target/`): **0 archivos** contienen el valor literal de la contraseña. `target/` también 0 coincidencias.
- La corrección aplicada por OpenCode (restaurar el marcador) elimina el riesgo.

### 4. Comprobación repetible antes del primer commit
Añadir al flujo de pre-commit (o ejecutar manualmente antes de `git add`) un escaneo que compare secretos reales contra archivos versionados:

```bash
# 1. Cargar secretos reales desde .env.local (solo variables sensibles)
set -a; source .env.local; set +a

# 2. Buscar cada valor secreto en archivos rastreados por Git (excluyendo .env.local y target/)
for var in VPLAN_DB_PASSWORD; do
  val="${!var}"
  if [ -n "$val" ]; then
    git ls-files | grep -vE '^\.env\.local$|^target/' | xargs -r grep -F "$val" && echo "❌ SECRETO ENCONTRADO: $var" && exit 1
  fi
done
echo "✅ Sin secretos literales en archivos versionados"
```

Alternativa con `gitleaks` o `trufflehog` configurados con reglas personalizadas para las variables del proyecto.

---

*Fin del anexo.*