# Fase 8 — Pruebas, calidad y correcciones

**Fecha:** 2026-11-17
**Responsable:** OpenCode (sin Hermes)
**Estado:** verificada contra MySQL, API y Chrome; pendiente de aprobación

---

## 1. Objetivo

Revisar la calidad y la robustez de VPlan antes de la documentación final y
GitHub, sin cambiar el alcance aprobado:

- Auditar estructura, backend, frontend, configuración, migraciones, scripts y
  documentación **sin modificar nada** en la primera pasada.
- Probar de verdad el CRUD, las validaciones, los errores HTTP, los filtros, la
  persistencia en MySQL y la compatibilidad con H2.
- Probar la interfaz completa: estados vacíos, diálogos, filtros combinados,
  errores de red, reintentos, cargas lentas, fechas, dashboard, tema y responsive.
- Revisar seguridad, accesibilidad y comportamiento en 1440, 1024, 768 y 390 px.
- Corregir **solo defectos demostrados**, documentarlos y repetir lo afectado.
- No recrear la base de datos, no tocar `V1`/`V2`, no añadir dependencias, no
  introducir autenticación, no exponer la aplicación y no hacer commits.

## 2. Método

1. **Auditoría estática:** lectura de todo el código Java, recursos estáticos,
   `pom.xml`, `application.yml`, migraciones, scripts y documentación.
2. **Tests existentes:** ejecución de la suite del backend antes de tocar nada.
3. **API real:** suite contra `http://localhost:8080/api/tareas` con MySQL 8.
4. **MySQL directo:** consulta JDBC independiente de la API para comprobar filas,
   columnas y el historial de Flyway.
5. **Navegador real:** Chrome headless controlado por Chrome DevTools Protocol
   (CDP), sin frameworks de test ni dependencias nuevas.
6. **Regresión:** repetición completa de la verificación de la Fase 7.
7. **Seguridad:** análisis de patrones peligrosos, peticiones de red, puertos,
   secretos y endpoints.
8. **Limpieza:** eliminación exclusiva de las tareas temporales creadas en esta
   fase y comprobación final del recuento.

## 3. Archivos y alcance

**No se modificó ningún archivo de la aplicación.** No hubo cambios en Java,
`pom.xml`, `application.yml`, HTML, CSS, JavaScript, migraciones ni scripts.

Las únicas incorporaciones son herramientas temporales de verificación en
`target/` (ignorado por Git) y documentación:

| Archivo | Contenido |
|---|---|
| `target/verify-phase8-api.mjs` | 53 comprobaciones de API contra MySQL |
| `target/VerifyFase8.java` | Consulta JDBC directa a MySQL y Flyway |
| `target/verify-phase8-ui.mjs` | 98 comprobaciones de interfaz con CDP |
| `target/verify-phase7.mjs` | Regresión existente de la Fase 7 (134 comprobaciones) |
| `docs/capturas/fase8-*.png` | Capturas reales de esta fase |
| `docs/colaboracion/FASE-08.md` | Este informe |
| `docs/aprendizaje/09-pruebas-y-calidad.md` | Guía de aprendizaje de pruebas |
| `README.md` | Estado real y enlaces actualizados |

No se añadieron dependencias, migraciones ni endpoints.

## 4. Resultados

### 4.1 Tests del backend (H2)

```text
Tests run: 34, Failures: 0, Errors: 0, Skipped: 0
```

Cubren contexto, entidad, repositorio, servicio, controlador, validaciones,
errores HTTP y health. Se ejecutaron antes y después de las pruebas manuales, sin
cambios en el código.

### 4.2 API real contra MySQL

`node target/verify-phase8-api.mjs` → **53 comprobaciones, 0 fallos**.

| Área | Comprobado |
|---|---|
| CRUD | Crear 4 tareas, listar, consultar por id, actualizar, borrar |
| `POST` | `201`, cabecera `Location`, estado por defecto `PENDIENTE` |
| `PUT` | Cambia campos, conserva estado si no se envía, `actualizadoEn` avanza |
| Filtros | Estado, prioridad, combinación y combinación sin resultados |
| Validación | Sin título, título en blanco, 121 caracteres, descripción de 2001 |
| JSON | Enumeraciones inválidas, fecha imposible, cuerpo mal formado |
| HTTP | `400`, `404`, `405`, `415`; `id` no numérico; ruta inexistente |
| Límites | Título de 120 y descripción de 2000 aceptados |
| Normalización | Espacios recortados, descripción vacía a `null`, campos extra ignorados |
| Seguridad | Los errores no filtran clases Java ni trazas internas |

### 4.3 Interfaz real con Chrome

`node target/verify-phase8-ui.mjs` → **98 comprobaciones, 0 fallos**.

| Área | Comprobado |
|---|---|
| Estado vacío | Dashboard y lista, contadores a cero, analíticas sin datos |
| Crear | Diálogo, foco inicial, validación del servidor, guardado y aviso |
| Editar | Precarga, cambio de campos, persistencia y aviso |
| Teclado | `Enter` abre, `Escape` cancela y devuelve el foco |
| Filtros | Estado, prioridad, combinación, contador y `aria-pressed` |
| Vacío filtrado | Mensaje específico, "Quitar filtros" y restauración |
| Inyección HTML | Título y descripción con `<img>`, `<script>` y `<b>` se pintan como texto |
| Red | Fallo simulado, paneles de error, "Sin datos" y reintento correcto |
| Carga lenta | Esqueletos visibles, retraso real de 1,6 s y datos al terminar |
| Tema | Cambio con teclado, `aria-checked`, `localStorage` y persistencia |
| Movimiento | `prefers-reduced-motion` evita la transición |
| Contraste | 18 pares WCAG AA en claro y en oscuro |
| Responsive | 1440, 1024, 768 y 390 sin desbordamiento de página ni cabecera |
| Móvil | Menú abre, enfoca el primer enlace y `Escape` lo cierra |
| Accesibilidad | Etiquetas, `aria-labelledby`, `aria-live`, foco en diálogos |
| Borrado | Confirmación, cancelación segura y eliminación real |
| Consola | 0 excepciones y 0 errores inesperados |
| Red externa | 0 peticiones fuera de `localhost:8080` |

### 4.4 Regresión de la Fase 7

`node target/verify-phase7.mjs` → **134 comprobaciones, 0 fallos**, con
`0` errores de consola y `0` peticiones externas. El dashboard, las analíticas, el
tema, la sincronización entre pestañas y el responsive siguen intactos.

En total: **285 comprobaciones de integración/E2E** más los **34 tests** del
backend.

### 4.5 MySQL y Flyway

Comprobación directa con JDBC, sin pasar por la API y sin imprimir credenciales:

```text
FILAS_TAREAS=0
MIGRACIONES:
  v1 init success=true
  v2 single user success=true
```

Durante la fase se crearon 4 tareas semilla y se comprobó que sus valores
(`id`, título, prioridad, estado) coincidían en MySQL. Después se eliminaron
**solo** esas tareas y las creadas por la interfaz. El recuento inicial era `0` y
el final también es `0`. No se recreó la base, no se modificó el esquema y no se
aplicó ninguna migración nueva.

## 5. Defectos

### 5.1 Defectos de la aplicación

**Ninguno demostrado.** No se corrigió código de producción porque ninguna prueba
reprodujo un fallo real. El comportamiento observado coincide con el diseño
aprobado de las fases 4–7.

### 5.2 Incidencias de las herramientas de prueba

Se documentan por transparencia; **no son defectos del producto**:

| Incidencia | Causa | Corrección aplicada |
|---|---|---|
| `actualizadoEn` parecía no avanzar | Hibernate no marca la entidad como modificada si el `PUT` envía exactamente los mismos valores | La prueba cambia un dato tras la pausa; el `PUT` real sí actualiza la marca |
| `localStorage` daba `SecurityError` | La primera evaluación se hacía en `about:blank` | Se navega al origen real antes de limpiar el almacenamiento |
| `Enter` no abría el diálogo en CDP | Faltaba `text` en el evento de teclado y la pestaña no estaba en primer plano | Se añade `text: '\r'` y `Page.bringToFront` |

La prueba de API se repitió completa tras ajustar la aserción: **53/53**. La de
interfaz se repitió completa tras ajustar el teclado: **98/98**.

## 6. Seguridad

| Comprobación | Resultado |
|---|---|
| `innerHTML`, `outerHTML`, `insertAdjacentHTML` | Sin uso |
| `eval`, `new Function`, `document.write` | Sin uso |
| Render de datos de la API | `textContent`, `createElement` y plantillas |
| Inyección HTML en título y descripción | Neutralizada; sin `window.__xss` |
| Destino de `fetch` | Solo `/api/tareas` (la interfaz no llama a otros endpoints) |
| Peticiones externas | 0; sin CDN, fuentes ni imágenes remotas |
| Única URL con aspecto externo | Namespace XML del `favicon.svg` |
| Escucha de red | `127.0.0.1:8080` y `127.0.0.1:9222` (Chrome de prueba) |
| Endpoints publicados | `/api/health` y `/api/tareas` únicamente |
| Errores internos | Sin clases Java, trazas ni SQL en las respuestas |
| `scripts/check-no-secrets.ps1` | Sin coincidencias |
| `.gitignore` | Ignora `.env*`, `application-local.*`, `backups/`, `*.dump`, `target/` |

No hay autenticación porque el diseño es personal y local; sigue siendo obligatorio
no exponer el puerto 8080 a la red.

## 7. Accesibilidad

- Navegación completa por teclado, incluidos filtros, tarjetas, diálogos y menú.
- Foco inicial en el primer campo al crear/editar y en "Eliminar" al confirmar.
- `Escape` cierra diálogos y menú, y devuelve el foco al elemento de origen.
- Todos los campos del formulario tienen `<label>` asociado.
- Diálogos con `aria-labelledby`; contador con `aria-live="polite"`; avisos con
  `role="status"` o `role="alert"`.
- Interruptor de tema con `role="switch"` y `aria-checked`.
- 18 pares de color superan **4.5:1** en tema claro y en tema oscuro.
- `prefers-reduced-motion: reduce` elimina la animación del cambio de tema.

## 8. Responsive y rendimiento

| Ancho | Página | Cabecera | Rejilla |
|---|---:|---:|---|
| 1440 px | 0 px | 0 px | Columnas de escritorio |
| 1024 px | 0 px | 0 px | Columnas de escritorio |
| 768 px | 0 px | 0 px | Menú móvil |
| 390 px | 0 px | 0 px | 1 columna, menú móvil |

Sin desbordamiento horizontal, sin recursos externos y sin errores de carga. La
carga lenta simulada mostró los estados de carga y terminó con los datos correctos.

## 9. Capturas revisadas

En `docs/capturas/`:

- `fase8-01-dashboard-vacio.png`
- `fase8-02-tarea-creada.png`
- `fase8-03-error-red.png`
- `fase8-04-tareas-oscuro-1440.png`
- `fase8-05-menu-movil-390.png`

Se revisaron una a una. Todas se tomaron con datos reales y la base quedó vacía.

## 10. Cómo repetir las pruebas

> **Nota de publicación:** solo el paso 1 está incluido en el repositorio. Los
> verificadores de los pasos 3, 4, 5 y 6 vivían en `target/` (ignorado por Git) y
> no se publican; se conservan aquí como registro de cómo se verificó la fase. La
> prueba automatizada que puedes repetir es `.\mvnw.cmd test`.

```powershell
# 1. Tests del backend (H2, no necesitan MySQL)
. .\scripts\set-dev-env.ps1
.\mvnw.cmd test

# 2. Arrancar la aplicación en otra ventana
.\mvnw.cmd spring-boot:run

# 3. API real (deja 4 tareas temporales para la comprobación directa)
node target\verify-phase8-api.mjs

# 4. MySQL directo (sin imprimir la contraseña)
$jar = Get-ChildItem "$env:USERPROFILE\.m2\repository\com\mysql\mysql-connector-j" -Recurse -Filter "mysql-connector-j-*.jar" | Select-Object -Last 1
java "-Dfile.encoding=UTF-8" --class-path $jar.FullName target\VerifyFase8.java

# 5. Interfaz: requiere Chrome con --remote-debugging-port=9222
node target\verify-phase8-ui.mjs

# 6. Regresión de la Fase 7
node target\verify-phase7.mjs

# 7. Secretos
.\scripts\check-no-secrets.ps1
```

Las suites de API y de interfaz limpian sus propias tareas al terminar. Si una
ejecución se interrumpe, basta con borrar las tareas cuyo título empiece por
`Fase 8 ·` o cuya descripción contenga `FASE8_TEMP`.

## 11. Puertos y procesos

Durante la verificación:

| Puerto | Dirección | Proceso |
|---:|---|---|
| 8080 | `127.0.0.1` | `com.vplan.VPlanApplication` |
| 9222 | `127.0.0.1` | Chrome headless de pruebas |

Al terminar se detuvieron la aplicación, el wrapper de Maven y Chrome. Los puertos
8080 y 9222 quedaron libres y no quedó ningún proceso de prueba en ejecución.

## 12. Limitaciones conocidas

Se mantienen las de las fases anteriores, ninguna nueva:

- Sin autenticación ni HTTPS por diseño local; no debe publicarse tal cual.
- Sin paginación ni buscador; el dashboard calcula en el navegador con la lista
  completa.
- El tema se guarda por navegador, no por usuario.
- Sin deshacer tras eliminar.
- Sin JavaScript no hay datos, filtros, tema ni diálogos.

## 13. Checklist

- [x] Auditoría inicial sin modificar código
- [x] 34 tests del backend en verde
- [x] CRUD, validaciones, errores HTTP y filtros contra MySQL
- [x] Compatibilidad con H2 y Flyway en versión 2
- [x] Persistencia verificada directamente en MySQL
- [x] Crear, editar y eliminar desde la interfaz
- [x] Filtros combinados y estados vacíos
- [x] Error de red, reintento y carga lenta
- [x] Fechas, vencimientos y dashboard
- [x] Tema claro/oscuro, persistencia y movimiento reducido
- [x] Responsive 1440 / 1024 / 768 / 390 sin desbordamiento
- [x] Navegación por teclado, foco y diálogos
- [x] Etiquetas, `aria-live`, `aria-checked` y contraste AA
- [x] Inyección HTML neutralizada y sin peticiones externas
- [x] Sin secretos y `.env.local` ignorado
- [x] Escucha exclusiva en `127.0.0.1`
- [x] Base de datos con 0 tareas al empezar y al terminar
- [x] Regresión de la Fase 7 (134 comprobaciones)
- [x] Sin dependencias, migraciones ni endpoints nuevos
- [x] Documentación creada y README actualizado
- [ ] Aprobación de la persona

**No se ha iniciado la Fase 9 y no se ha hecho ningún commit.**
