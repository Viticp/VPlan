# API REST de tareas

Esta guía explica cómo está construido el CRUD de tareas y **por qué** se ha
hecho así. El objetivo es que puedas defenderlo en una entrevista y modificarlo
sin miedo.

## 1. Estructura

```text
com.vplan
├─ task/
│  ├─ Tarea.java                    Entidad JPA (tabla tareas)
│  ├─ Prioridad.java                Enum BAJA, MEDIA, ALTA
│  ├─ Estado.java                   Enum PENDIENTE, EN_PROCESO, COMPLETADA
│  ├─ TareaRepository.java          Spring Data JPA
│  ├─ TareaService.java             Reglas de negocio y transacciones
│  ├─ TareaNoEncontradaException    Error de negocio → 404
│  ├─ TareaController.java          API REST
│  └─ dto/
│     ├─ TareaRequest.java          Lo que entra
│     └─ TareaResponse.java         Lo que sale
└─ common/
   ├─ ErrorResponse.java            Formato único de error
   └─ GlobalExceptionHandler.java   Excepciones → HTTP
```

**Flujo de una petición**: `Controller → Service → Repository → MySQL`. El
controlador no tiene reglas de negocio y el servicio no sabe qué es HTTP. Así
cada capa se puede probar y cambiar por separado.

## 2. La entidad `Tarea`

```java
@Entity
@Table(name = "tareas")
public class Tarea {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;
    ...
}
```

Decisiones:

- **`IDENTITY`** porque la tabla usa `AUTO_INCREMENT`. Hibernate pide el id a
  MySQL al insertar y no necesita secuencias (que MySQL no tiene).
- **`@Enumerated(EnumType.STRING)`**: en la base de datos se guarda `'ALTA'`, no
  `2`. Si se guardara el ordinal, reordenar el enum corrompería los datos
  existentes.
- **`LocalDate` para `fechaLimite`** porque el requisito es una fecha, no una
  hora. `LocalDateTime` para `creadoEn` y `actualizadoEn`, e `Instant` para
  `completadoEn`.
- **Marcas recortadas a segundos**: las columnas son `TIMESTAMP` (sin
  fracciones). Si se guardaran nanosegundos, la respuesta del `POST` y un `GET`
  posterior darían valores distintos. `truncatedTo(SECONDS)` hace que la API
  devuelva exactamente lo que hay en la base de datos.
- **`completadoEn` es un `Instant`**, no un `LocalDateTime`: un instante
  absoluto no depende de la zona de la máquina. La conexión fija la sesión de
  MySQL en UTC (`connectionTimeZone=UTC` y
  `forceConnectionTimeZoneToSession=true`) y Hibernate usa
  `hibernate.jdbc.time_zone: UTC`. Sin esa combinación, el driver aplicaba la
  zona de la JVM y la fecha guardada se desplazaba una hora.
- **`@PrePersist` / `@PreUpdate`** rellenan `creadoEn` y `actualizadoEn`. Se
  podría usar `@CreationTimestamp`/`@UpdateTimestamp` de Hibernate, pero así el
  comportamiento está a la vista al leer la clase.
- **`estado` por defecto `PENDIENTE`** en `@PrePersist`: una tarea nueva sin
  estado explícito no puede quedar en `null`.
- **`completadoEn` es la fecha real de finalización**, no la de vencimiento ni
  la de última edición. La migración `V3` añade `completado_en TIMESTAMP NULL`
  sin tocar `V1` ni `V2`.
- **`setEstado()` mantiene coherente `completadoEn`**: lo registra al entrar en
  `COMPLETADA`, lo conserva al editar una tarea ya completada y lo limpia al
  reabrirla. Si una tarea antigua ya estaba completada y no tiene fecha, se
  queda a `null`: no se inventa un dato histórico.
- **Constructor `protected Tarea()`**: lo exige JPA. El constructor público
  recibe los datos de negocio.

La tabla **ya existía** (`V1`, adaptada por `V2`). `V3` solo añade la columna de
finalización; las restricciones `CHECK` actuales siguen validando prioridad y
estado.

## 3. El repositorio

```java
public interface TareaRepository extends JpaRepository<Tarea, Long> {
    List<Tarea> findAllByOrderByIdAsc();
    List<Tarea> findByEstadoOrderByIdAsc(Estado estado);
    List<Tarea> findByPrioridadOrderByIdAsc(Prioridad prioridad);
    List<Tarea> findByEstadoAndPrioridadOrderByIdAsc(Estado estado, Prioridad prioridad);
}
```

Se usan **consultas derivadas**: Spring Data genera el SQL a partir del nombre
del método. No hace falta escribir JPQL para algo tan simple.

**Por qué cuatro métodos y no uno con parámetros opcionales**: con un
`WHERE (:estado IS NULL OR ...)` el SQL es más corto, pero el planificador no
siempre usa bien el índice con parámetros nulos y el resultado es más difícil de
leer. El servicio elige uno de los cuatro según los filtros; siempre se ejecuta
la consulta exacta que toca.

Todas ordenan por `id` ascendente para que el resultado sea predecible.

## 4. El servicio

- `@Transactional(readOnly = true)` en la clase: las lecturas no abren
  transacción de escritura.
- `@Transactional` en `crear`, `actualizar` y `eliminar`: si algo falla, no se
  guarda nada a medias.
- `actualizar` **no llama a `save()`**: la entidad ya está gestionada por JPA y
  Hibernate detecta los cambios (*dirty checking*) al hacer commit. Es una de
  las ventajas de JPA que conviene saber explicar.
- Si no se envía `estado` al actualizar, se conserva el actual. Así se puede
  editar el título sin reenviar todo.
- La fecha de finalización **no viaja en `TareaRequest`**: la decide el servidor
  al cambiar el estado. De este modo el cliente no puede falsear cuándo se
  completó una tarea.
- `limpiar()` quita espacios y convierte `"   "` en `null`: una descripción vacía
  se guarda como ausente, no como cadena vacía.

## 5. DTOs y validación

`TareaRequest` (entrada):

| Campo | Validación |
|---|---|
| `titulo` | `@NotBlank`, máximo 120 |
| `descripcion` | máximo 2000, opcional |
| `prioridad` | `@NotNull` |
| `estado` | opcional |
| `fechaLimite` | opcional |

`TareaResponse` (salida) incluye `id`, `creadoEn`, `actualizadoEn` y
`completadoEn`. Este último se serializa como **instante UTC con sufijo `Z`**
para que el navegador pueda situarlo en el día local de la persona; las tareas
antiguas completadas sin fecha devuelven `null`.

**Por qué no devolver la entidad directamente**: si mañana se añade una columna
interna, aparecería en el JSON sin querer. El DTO fija el contrato de la API y
evita aceptar campos que el cliente no debe enviar (por ejemplo, un `id` en el
`POST`).

Las validaciones con Bean Validation devuelven `400` y un mapa `campos` con el
mensaje de cada campo, para que el frontend pueda marcar los errores.

## 6. El controlador

| Método | Ruta | Código | Nota |
|---|---|---|---|
| `GET` | `/api/tareas` | `200` | Acepta `?estado=` y `?prioridad=` |
| `GET` | `/api/tareas/{id}` | `200` / `404` | |
| `POST` | `/api/tareas` | `201` | Cabecera `Location` con la URL de la tarea creada |
| `PUT` | `/api/tareas/{id}` | `200` / `404` | Actualización completa |
| `DELETE` | `/api/tareas/{id}` | `204` / `404` | Sin cuerpo |

`201 Created` + `Location` es la respuesta correcta al crear un recurso, no
`200`. `204 No Content` es la correcta al borrar.

Los filtros son parámetros opcionales: si se envía un valor que no existe (por
ejemplo `?estado=URGENTE`), Spring no puede convertirlo al enum y el manejador
global responde `400` con un mensaje claro.

## 7. Errores

Todas las respuestas de error usan `ErrorResponse`:

```json
{
  "timestamp": "2026-11-17T10:00:00Z",
  "status": 404,
  "error": "Not Found",
  "mensaje": "No existe ninguna tarea con id 7",
  "ruta": "/api/tareas/7"
}
```

`GlobalExceptionHandler` traduce:

| Excepción | HTTP |
|---|---|
| `TareaNoEncontradaException` | `404` |
| `MethodArgumentNotValidException` | `400` + `campos` |
| `HttpMessageNotReadableException` (JSON o enum inválido) | `400` |
| `MethodArgumentTypeMismatchException` (filtro inválido) | `400` |
| `HttpRequestMethodNotSupportedException` | `405` |
| `HttpMediaTypeNotSupportedException` | `415` |
| `NoResourceFoundException` (ruta inexistente) | `404` |
| Cualquier otra | `500` genérico |

**Nunca** se devuelve el mensaje de una excepción interna ni una traza: el
detalle va al log del servidor y el cliente recibe un mensaje genérico. Es la
misma razón por la que `server.error.include-message` está en `never`.

## 8. Ejemplos con curl

```bash
# Crear
curl -i -X POST http://localhost:8080/api/tareas \
  -H "Content-Type: application/json" \
  -d '{"titulo":"Preparar entrega","prioridad":"ALTA","fechaLimite":"2026-12-31"}'

# Listar y filtrar
curl http://localhost:8080/api/tareas
curl "http://localhost:8080/api/tareas?estado=PENDIENTE&prioridad=ALTA"

# Actualizar (PUT completo)
curl -X PUT http://localhost:8080/api/tareas/1 \
  -H "Content-Type: application/json" \
  -d '{"titulo":"Entrega lista","prioridad":"MEDIA","estado":"COMPLETADA"}'

# Borrar
curl -i -X DELETE http://localhost:8080/api/tareas/1
```

## 9. Tests

| Test | Nivel | Qué cubre |
|---|---|---|
| `TareaRepositoryTest` | repositorio + H2 | Guardar, recuperar, fecha de finalización y los cuatro filtros |
| `TareaServiceTest` | servicio + H2 | Estado por defecto, normalización, actualización, 404, borrado y ciclo de `completadoEn` |
| `TareaControllerTest` | API completa (MockMvc) | Códigos HTTP, JSON, validación, filtros, errores y fecha UTC de finalización |

Los tests usan H2 en memoria con el **mismo esquema** que MySQL (Flyway aplica
`V1`, `V2` y `V3`). Cada test es transaccional y se revierte, así que no
dependen del orden ni dejan datos.

La suma total del proyecto es **42 tests** (incluidos los de fases anteriores).

## 10. Limitaciones conocidas

- **Sin paginación**: `GET /api/tareas` devuelve todo. Para una app personal es
  suficiente; con miles de tareas habría que añadir `Pageable`.
- **Sin autenticación**: es una decisión de diseño (app local). No debe
  publicarse en internet.
- **`actualizadoEn` y `completadoEn` con resolución de segundos**: si editas o
  completas dos veces en el mismo segundo, la marca no cambia. Es una
  consecuencia de las columnas `TIMESTAMP`; cambiarlas exigiría otra migración.
- **Tareas antiguas completadas sin fecha**: se conservan con
  `completadoEn = null` y no aparecen en el gráfico semanal. Se documenta así
  para no inventar actividad que no se registró.
- **`PUT` es actualización completa**, no parcial. Un `PATCH` parcial sería una
  mejora futura.
