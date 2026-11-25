# Arquitectura y flujo de una petición

## 1. Vista general

VPlan es una aplicación **monolítica**: un único proceso Spring Boot sirve tanto
la API JSON como los archivos HTML, CSS y JavaScript.

```text
Navegador (HTML + JS vanilla)
        │  fetch("/api/tareas")
        ▼
Spring Boot :8080
  ├─ Controller  → valida la petición y decide qué responder
  ├─ Service     → reglas de negocio y validaciones
  ├─ Repository  → acceso a datos (Spring Data JPA)
  └─ MySQL       → datos persistentes
```

No hay servidor de frontend aparte. Ventajas: no hay CORS, un solo despliegue y
el mismo `:8080` sirve todo.

> Desde la Fase 6 la interfaz **lee y escribe datos reales** de MySQL a través de
> `/api/tareas`: no quedan tarjetas de ejemplo. El flujo completo es navegador
> (`fetch`) → Spring Boot → MySQL y vuelta.
>
> La Fase 7 no añade capas ni endpoints: amplía el dashboard y el tema oscuro en
> el cliente. Las analíticas y la preferencia de tema viven solo en el navegador.

## 2. Responsabilidad de cada capa

| Capa | Qué hace | Qué NO hace |
|---|---|---|
| `*Controller` | Recibe HTTP, valida el DTO, devuelve códigos y JSON | No contiene reglas de negocio ni SQL |
| `*Service` | Reglas de negocio, transacciones | No conoce HTTP |
| `*Repository` | Consultas a base de datos | No decide reglas de negocio |
| Entidad JPA | Representa una tabla | No se expone directamente al cliente |
| DTO | Contrato de entrada/salida de la API | No tiene lógica de persistencia |

Separar entidad y DTO evita dos problemas clásicos: exponer campos internos
(como `actualizado_en`) y aceptar campos que el cliente no debería enviar
(como `id` en una creación).

## 3. Ejemplo de recorrido (Fase 4)

Petición: `PUT /api/tareas/12` con `{"titulo":"Entrega","prioridad":"ALTA","estado":"COMPLETADA"}`.

1. `TareaController` recibe el JSON, lo convierte en `TareaRequest` y valida con
   Bean Validation. Si algo no cumple, responde `400` con los campos erróneos.
2. `TareaService` busca la tarea por id; si no existe, lanza
   `TareaNoEncontradaException`.
3. `TareaRepository` recupera la entidad de MySQL.
4. El servicio cambia los campos sobre la entidad gestionada por Hibernate.
5. Al hacer commit, Hibernate ejecuta el `UPDATE` y `@PreUpdate` rellena
   `actualizadoEn`.
6. `TareaResponse.desde(...)` convierte la entidad en el JSON de salida y el
   controlador devuelve `200`.

## 4. Aplicación de un solo usuario (sin autenticación)

VPlan se usa **en local, por una sola persona**. No hay registro, login,
sesiones ni cookies de identidad. Consecuencias de diseño:

- Todas las rutas son públicas: no existe `SecurityConfig` ni filtros de
  seguridad.
- No hay CSRF que proteger: la protección CSRF evita que un sitio externo use
  tus cookies de sesión, y aquí no hay ninguna.
- No hay tabla `usuarios` ni columna `usuario_id`: una tarea simplemente existe.
- La aplicación escucha **solo en `127.0.0.1:8080`** (`server.address`), así que
  no es accesible desde la red local. MySQL debe configurarse igual, con
  `bind-address=127.0.0.1`.
- **No debe publicarse en internet** tal cual. Cualquiera con acceso al equipo
  podría leer y modificar las tareas. Para desplegarla habría que añadir
  autenticación, HTTPS y una revisión de seguridad.

Este cambio sustituyó a la autenticación por sesión que estaba prevista en el
diseño inicial. La migración `V2__single_user.sql` eliminó la tabla `usuarios` y
la relación `tareas.usuario_id`; `V1__init.sql` se conserva intacta como
histórico de Flyway.

## 5. Dónde vive cada cosa

```text
com.vplan
├─ VPlanApplication   Punto de entrada (@SpringBootApplication)
├─ task/                 Entidad, repositorio, servicio y controlador de tareas
└─ common/               Manejo global de errores y formato de error
```

No hay un paquete `dashboard`: las analíticas se calculan en el navegador sobre la
lista que devuelve `GET /api/tareas`.

Regla práctica: si una clase necesita HTTP y SQL a la vez, probablemente está mal
colocada.

## 6. Frontend

- Una sola página (`static/index.html`) con dos vistas conmutadas por hash:
  `#/dashboard` y `#/tareas`.
- CSS con variables en `:root`. El tema oscuro redefine las mismas variables en
  `:root[data-theme="oscuro"]`; los componentes no cambian.
- JavaScript vanilla en tres módulos ES, sin frameworks ni dependencias externas:
  `js/api.js` (solo `fetch`, timeout y errores de la API), `js/app.js` (estado,
  render, analíticas, filtros, diálogos y foco) y `js/tema.js` (interruptor,
  `localStorage`, preferencia del sistema y sincronización entre pestañas). El
  navegador los carga como `<script type="module">`.
- Un script inline mínimo en el `<head>` aplica el tema guardado antes del primer
  pintado, para evitar el destello blanco.
- Formularios en `<dialog>` nativo, con la validación del propio navegador.
- Una sola petición `GET /api/tareas` por carga; filtros, contadores y todas las
  analíticas del dashboard se calculan en el cliente sobre la lista ya cargada.
  Tras cada `POST`, `PUT` o `DELETE` se vuelve a leer la lista del servidor.

El detalle está en [Frontend](06-frontend.md).
