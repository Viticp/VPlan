VPlan

Mi gestor de tareas personal: una aplicación web full stack con API REST en Java (Spring Boot), base de datos MySQL y un frontend en HTML, CSS y JavaScript sin frameworks. Lo hice como proyecto de portafolio del ciclo de DAW (Desarrollo de Aplicaciones Web).

![Dashboard de VPlan en tema claro](docs/capturas/vplan-dashboard-claro-1440.png)

| Tema oscuro | Vista de tareas |
|---|---|
| ![Dashboard de VPlan en tema oscuro](docs/capturas/vplan-dashboard-oscuro-1440.png) | ![Listado de tareas de VPlan](docs/capturas/vplan-tareas-1440.png) |

| Móvil claro (390 px) | Móvil oscuro (390 px) |
|---|---|
| ![Dashboard móvil en tema claro](docs/capturas/vplan-dashboard-claro-390.png) | ![Dashboard móvil en tema oscuro](docs/capturas/vplan-dashboard-oscuro-390.png) |

Qué hace
CRUD de tareas: crear, ver, editar y borrar.
Prioridad (alta, media, baja), estado (pendiente, en proceso, completada) y fecha límite.
Filtros por estado y prioridad, combinables.
Dashboard con progreso, vencimientos, distribución por prioridad y estado, y carga de los próximos 7 días.
Tema claro y oscuro, diseño responsive y navegación con teclado.
Validación en el servidor con errores claros en JSON.
Tecnologías
Backend: Java 21, Spring Boot 3, Spring MVC, Spring Data JPA, API REST
Base de datos: MySQL 8, Flyway (migraciones)
Frontend: HTML5, CSS3, JavaScript
Testing: JUnit 5, MockMvc, H2 (42 tests automatizados)
Herramientas: Maven, Git, GitHub
Cómo ejecutarlo

Necesitas JDK 21 y MySQL 8 en localhost:3306.

Crea la base de datos y el usuario con database/00_create_database_and_user.sql (cambia antes la contraseña del script).
Guarda la contraseña de la app: .\scripts\set-db-password.ps1
Arranca: .\scripts\start-vplan.ps1 y se abre http://localhost:8080.

Los scripts son de PowerShell (Windows). En Linux/macOS: ./mvnw spring-boot:run con las variables de conexión definidas (mira application.yml).

Para lanzar los tests (no necesitan MySQL): .\mvnw.cmd test

Más detalle en INSTALACION.md.

API
Método	Ruta	Qué hace
GET	/api/tareas	Lista tareas (admite ?estado= y ?prioridad=)
GET	/api/tareas/{id}	Devuelve una tarea
POST	/api/tareas	Crea una tarea
PUT	/api/tareas/{id}	Actualiza una tarea
DELETE	/api/tareas/{id}	Elimina una tarea
Cómo lo hice

Lo desarrollé con ayuda de IA (OpenCode, desde la terminal) como herramienta para aprender y avanzar más rápido. Fui documentando lo que iba entendiendo en docs/aprendizaje/ (arquitectura, base de datos, API, frontend y pruebas).

Limitaciones

Es una app personal y local: no tiene login ni usuarios, y solo escucha en 127.0.0.1. No está pensada para exponerse en Internet.

Próximos pasos
Autenticación con Spring Security
Docker Compose para levantarlo todo con un comando
Despliegue con HTTPS
