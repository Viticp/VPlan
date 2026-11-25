# Arranque, configuración y endpoint de salud

## 1. Qué ocurre al ejecutar la aplicación

```text
.\mvnw.cmd spring-boot:run
        │
        ▼
VPlanApplication.main()
        │
        ├─ 1. Spring lee application.yml y las variables de entorno
        ├─ 2. HikariCP abre el pool de conexiones a MySQL
        ├─ 3. Flyway comprueba flyway_schema_history y aplica V1__init.sql
        ├─ 4. Hibernate valida que el esquema coincide (ddl-auto: validate)
        └─ 5. Tomcat escucha en http://localhost:8080 (solo 127.0.0.1)
```

El orden importa: **Flyway va antes que JPA**. Si Hibernate arrancara primero con
`validate`, fallaría porque las tablas aún no existirían.

## 2. La contraseña nunca está en el código

En `application.yml`:

```yaml
password: "${VPLAN_DB_PASSWORD}"
```

No hay valor por defecto a propósito. Si la variable no existe, el arranque falla
con un error claro en lugar de intentar conectarse con una contraseña vacía.

La comprobación está en `VPlanApplication.main()`: se ejecuta antes de crear
el contexto de Spring. Los tests no pasan por `main()` (usan H2), así que no
necesitan la variable.

Para no repetirla en cada sesión, se guarda en `.env.local`:

```text
VPLAN_DB_PASSWORD=...
```

- `.env.local` está en `.gitignore`: **nunca** se sube al repositorio.
- `scripts/set-dev-env.ps1` lo lee y define la variable solo en la sesión actual.
- `scripts/set-db-password.ps1` la pide una vez sin mostrarla por pantalla.
- `.env.example` documenta qué variables existen, sin valores reales.

## 3. El endpoint `/api/health`

```http
GET /api/health
```

```json
{
  "status": "UP",
  "application": "vplan",
  "database": "UP",
  "timestamp": "2026-11-17T09:50:00Z"
}
```

No devuelve un "OK" fijo: ejecuta `SELECT 1` con `JdbcTemplate`. Así se comprueba
la conexión real, no solo que Tomcat esté vivo.

- `200 OK` si la base de datos responde.
- `503 Service Unavailable` si la base de datos falla.

En caso de fallo **no** se registra el mensaje de la excepción, para no filtrar
host, usuario ni cadena JDBC en los logs.

¿Por qué no Spring Boot Actuator? Para el portfolio es más didáctico implementar
la comprobación y, de paso, evitar una dependencia extra que ocultaría qué ocurre.

## 4. Acceso y alcance

VPlan es una aplicación personal que se ejecuta en tu equipo. **No hay
autenticación ni autorización**: todas las rutas son públicas.

| Ruta | Acceso |
|---|---|
| `GET /api/health` | Público |
| Recursos estáticos (`/`, `/css/**`, `/js/**`, `/img/**`) | Público |
| Futuras rutas de la API | Públicas |

- No hay `SecurityConfig` ni dependencia de Spring Security.
- No hay sesiones ni cookies de identidad, así que **CSRF no aplica**: esa
  protección existe para impedir que un sitio externo use tus cookies, y aquí no
  hay ninguna.
- **Solo escucha en loopback.** `server.address: 127.0.0.1` en
  `application.yml` hace que Tomcat acepte conexiones únicamente desde el propio
  equipo. `http://localhost:8080` sigue funcionando igual, pero la aplicación no
  es accesible desde la red local.
- **No expongas el puerto 8080 a internet.** Cualquiera con acceso al equipo
  podría leer y modificar las tareas. Para publicarla haría falta añadir
  autenticación, HTTPS y una revisión de seguridad.

## 5. Cómo arrancar y comprobar

```powershell
cd <ruta-del-proyecto>
. .\scripts\set-dev-env.ps1
.\mvnw.cmd spring-boot:run
```

En otra terminal:

```powershell
Invoke-RestMethod http://localhost:8080/api/health | ConvertTo-Json
```

También puedes abrir `http://localhost:8080/api/health` en el navegador.

Para parar: `Ctrl + C`.

## 6. Qué mirar en los logs

Señales de que todo ha ido bien:

```text
Flyway ... Successfully applied 1 migration to schema `vplan`
HikariPool ... Start completed
Tomcat started on port 8080
Started VPlanApplication in X seconds
```

## 7. Errores habituales

| Error | Causa | Solución |
|---|---|---|
| `Could not resolve placeholder 'VPLAN_DB_PASSWORD'` | Falta la variable | Ejecutar el script de entorno y `.env.local` |
| `Access denied for user 'vplan_app'` | Contraseña incorrecta o usuario no creado | Revisar el script SQL y `.env.local` |
| `Communications link failure` | MySQL parado | Iniciar el servicio `MySQL80` |
| `Flyway detected applied migration not resolved locally` | Se editó una migración ya aplicada | No editar migraciones aplicadas; crear `V2__...` |
| `Schema-validation: missing table` | Flyway no se ejecutó | Revisar logs de Flyway y permisos del usuario |

## 8. Tests

```powershell
.\mvnw.cmd test
```

Los tests usan el perfil `test`: H2 en memoria con `MODE=MySQL` y las mismas
migraciones Flyway. No necesitan MySQL ni la contraseña real. Eso permite que
cualquiera clone el repositorio y ejecute los tests sin configurar nada.
