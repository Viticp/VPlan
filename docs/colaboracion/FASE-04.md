# Fase 4 — Backend CRUD de tareas

**Fecha:** 2026-11-17
**Responsable de escritura:** OpenCode
**Revisión independiente:** Hermes (`REVISION-HERMES-FASE-04.md`)
**Estado:** implementada y verificada, pendiente de aprobación de la persona

---

## 1. Objetivo

Exponer una API REST para gestionar tareas sobre la tabla `tareas` que ya existe,
sin tocar el esquema ni añadir dependencias.

## 2. Archivos creados

Código principal:

- `task/Prioridad.java`, `task/Estado.java`
- `task/Tarea.java` (entidad JPA)
- `task/TareaRepository.java`
- `task/TareaService.java`
- `task/TareaNoEncontradaException.java`
- `task/TareaController.java`
- `task/dto/TareaRequest.java`, `task/dto/TareaResponse.java`
- `common/ErrorResponse.java`, `common/GlobalExceptionHandler.java`

Tests:

- `task/TareaRepositoryTest.java` (5 tests)
- `task/TareaServiceTest.java` (10 tests)
- `task/TareaControllerTest.java` (15 tests)

Documentación:

- `docs/aprendizaje/05-api-tareas.md`
- `README.md` (API de tareas, estado y fases)
- `docs/aprendizaje/01-arquitectura.md` (ejemplo de recorrido real)

**No se ha creado ninguna migración nueva.** La tabla `tareas` de `V1`/`V2` ya
tenía todas las columnas y las restricciones `CHECK` necesarias.

## 3. Decisiones técnicas

| Decisión | Motivo |
|---|---|
| `@Enumerated(EnumType.STRING)` | En la base se guarda `'ALTA'`, no un ordinal; reordenar el enum no corrompe datos |
| `LocalDateTime` UTC recortado a segundos | La columna es `TIMESTAMP` sin fracciones: así la respuesta del `POST` coincide con un `GET` posterior |
| `@PrePersist` / `@PreUpdate` | Fechas explícitas y visibles, sin depender de anotaciones "mágicas" de Hibernate |
| Cuatro consultas derivadas en el repositorio | Evita `WHERE (:param IS NULL OR ...)`; cada combinación de filtros usa su índice |
| `actualizar` sin `save()` | La entidad está gestionada: *dirty checking* de JPA |
| DTOs `record` separados de la entidad | La entidad no se expone y el contrato JSON queda fijado |
| `201` + `Location` al crear, `204` al borrar | Códigos HTTP correctos para un CRUD |
| `ErrorResponse` único | El frontend solo aprende un formato de error |
| Handler genérico → 500 sin detalles | No se filtran trazas ni mensajes internos |

## 4. Resultados reales de los tests

```text
HealthControllerTest          1 test    0 fallos
SchemaSingleUserTest          2 tests   0 fallos
TareaControllerTest          15 tests   0 fallos
TareaRepositoryTest           5 tests   0 fallos
TareaServiceTest             10 tests   0 fallos
VPlanApplicationTests      1 test    0 fallos
--------------------------------------------------
Tests run: 34, Failures: 0, Errors: 0, Skipped: 0 — BUILD SUCCESS
```

Los tests de repositorio y servicio usan H2 con el esquema real migrado por
Flyway; los de controlador recorren la API completa con MockMvc. Todos son
transaccionales y se revierten.

## 5. Verificación de la API contra MySQL real

Aplicación arrancada con `spring-boot:run` contra `vplan` (MySQL 8.0.45).
`Current version of schema vplan: 2`, `Started VPlanApplication in 2.244
seconds`, 0 errores en el log.

| # | Petición | Código real | Cuerpo real (resumido) |
|---|---|---|---|
| 1 | `GET /api/tareas` (vacía) | `200` | `[]` |
| 2 | `POST /api/tareas` | `201` | `{"id":1,"titulo":"Preparar practica",...,"estado":"PENDIENTE","fechaLimite":"2026-12-31"}` |
| 3 | `GET /api/tareas/1` | `200` | misma tarea |
| 4 | `PUT /api/tareas/1` | `200` | `{"titulo":"Actualizada","prioridad":"MEDIA","estado":"COMPLETADA","fechaLimite":"2027-06-30"}` |
| 5 | `GET /api/tareas?estado=COMPLETADA&prioridad=MEDIA` | `200` | la tarea actualizada |
| 6 | `POST` sin título ni prioridad | `400` | `campos: {"titulo":"El titulo es obligatorio","prioridad":"La prioridad es obligatoria"}` |
| 7 | `GET /api/tareas/999999` | `404` | `"No existe ninguna tarea con id 999999"` |
| 8 | `GET /api/tareas?estado=URGENTE` | `400` | `"El parametro 'estado' tiene un valor no permitido"` |
| 9 | `DELETE /api/tareas/1` | `204` | sin cuerpo |
| 10 | `GET /api/tareas/1` tras borrar | `404` | |
| 11 | `GET /api/health` | `200` | `{"status":"UP","database":"UP"}` |

Comprobaciones adicionales:

- El título enviado como `"  Preparar practica  "` se guardó como
  `"Preparar practica"` (normalización).
- Una descripción con solo espacios se guardó como `null`.
- Al crear sin `estado`, la tarea quedó en `PENDIENTE`.
- `PUT` sin `estado` conserva el estado actual (cubierto en los tests).
- Tras borrar, la tabla quedó con **0 filas**: la base no se deja con datos de
  prueba.
- `flyway_schema_history` sigue en 2 migraciones, `success=true`.

### Ejemplo de error real

```json
{
  "timestamp": "2026-11-17T09:38:40.458941Z",
  "status": 400,
  "error": "Bad Request",
  "mensaje": "La peticion no es valida",
  "ruta": "/api/tareas",
  "campos": {
    "titulo": "El titulo es obligatorio",
    "prioridad": "La prioridad es obligatoria"
  }
}
```

## 6. Requisitos comprobados

| Requisito | Estado |
|---|---|
| Tabla MySQL existente, sin cambios de esquema | ✅ |
| Flyway intacto (2 migraciones aplicadas) | ✅ |
| `/api/health` sigue funcionando | ✅ |
| Sin Spring Security ni autenticación | ✅ |
| Sin dependencias nuevas en `pom.xml` | ✅ |
| Entidad, enums, repositorio, servicio, DTOs, validación, controlador | ✅ |
| Manejo global de errores | ✅ |
| Tests de repositorio, servicio y controlador | ✅ |
| Filtros por estado y prioridad | ✅ |

## 7. Limitaciones conocidas

- Sin paginación: `GET /api/tareas` devuelve todo (suficiente para uso personal).
- `PUT` es actualización completa; no hay `PATCH` parcial.
- `actualizadoEn` tiene resolución de segundos porque la columna `TIMESTAMP`
  existente no guarda fracciones. Cambiarla requeriría una migración y no se ha
  considerado necesario.
- Sin autenticación: la API no debe exponerse en internet.

## 8. Pendiente

- Revisión independiente de Hermes: **no se ha podido emitir**. El proveedor de
  modelos devolvió `HTTP 429: free-models-per-day` (límite diario gratuito, se
  reinicia a la 01:00). Se reintentará cuando el límite se restablezca; el
  informe no existe todavía para no falsear la evidencia.
- Aprobación de la persona antes de la Fase 5 (frontend).

## 9. Estado

- [x] Implementado
- [x] Tests automatizados en verde (34)
- [x] Verificado contra MySQL real
- [ ] Revisado por Hermes
- [ ] Aprobado por la persona
