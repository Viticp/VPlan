# Fase 7 — Dashboard ampliado y modo oscuro

**Fecha:** 2026-11-17
**Responsable:** OpenCode (sin Hermes)
**Estado:** implementada y verificada contra MySQL y Chrome, pendiente de aprobación

---

## 1. Objetivo

Ampliar el dashboard y añadir el tema oscuro manteniendo el diseño aprobado y la
aplicación local de un solo usuario:

- Analíticas de progreso, vencimientos, prioridad, estado y carga semanal.
- Tema claro/oscuro con detección inicial del sistema y preferencia guardada.
- Aplicación coherente del tema a vistas, tarjetas, diálogos y avisos.
- Verificación real en escritorio y móvil, en ambos temas.
- Sin cambios de backend, esquema, dependencias ni base de datos.
- Sin login, registro ni hosting. Sin commits.

## 2. Archivos

| Archivo | Cambio | Tamaño |
|---|---|---|
| `src/main/resources/static/index.html` | Bootstrap del tema, interruptor, iconos y bloques analíticos | 28.986 B |
| `src/main/resources/static/css/estilos.css` | Tokens oscuros, interruptor, analíticas, responsive y transición | 39.443 B |
| `src/main/resources/static/js/app.js` | Cálculo y render de analíticas, estados de carga/error | 41.067 B |
| `src/main/resources/static/js/tema.js` | **Nuevo**: persistencia, sistema y sincronización del tema | 3.678 B |
| `src/main/resources/static/js/api.js` | Sin cambios | 3.208 B |
| `src/main/resources/static/img/favicon.svg` | Sin cambios | 305 B |

Documentación:

- `README.md` (estado, capturas, estructura y fases).
- `docs/aprendizaje/06-frontend.md` (dashboard, tema y accesibilidad).
- `docs/aprendizaje/01-arquitectura.md` (módulos y cálculo en cliente).
- `docs/colaboracion/FASE-07.md` (este informe).

**No se ha tocado** ningún archivo Java, `pom.xml`, las migraciones Flyway, la base
de datos ni la configuración. No hay dependencias nuevas.

## 3. Decisiones aplicadas

Las cuatro decisiones aprobadas:

1. **Bloques analíticos propuestos:** progreso, vencimientos, distribución por
   prioridad, distribución por estado, carga de los próximos 7 días y próximas
   tareas.
2. **Interruptor de dos estados** (`Claro` / `Oscuro`), con detección del sistema
   en la primera visita y prioridad de la preferencia guardada.
3. **Prioridad y estado cuentan todas las tareas.** Vencimientos, carga semanal,
   "sin fecha" y progreso excluyen las completadas donde corresponde.
4. **Bootstrap inline mínimo + `js/tema.js` independiente**, sin mezclar el tema
   con la lógica de tareas.

Otras decisiones de implementación:

| Decisión | Motivo |
|---|---|
| `data-theme="oscuro"` en `<html>` y variables redefinidas | No duplicar reglas de componentes |
| Clave `vplan-tema` con valores `claro` / `oscuro` | Preferencia explícita y persistente |
| Script inline antes del CSS pintado | Evita el destello blanco al abrir en oscuro |
| `role="switch"` + `aria-checked` + texto | Estado comprensible con teclado y lector |
| Escuchar `prefers-color-scheme` y `storage` | Seguir al sistema y sincronizar pestañas |
| Clase temporal `tema-cambiando` (~260 ms) | Transición suave sin animar siempre |
| `prefers-reduced-motion: reduce` | Cambio instantáneo si se pide menos movimiento |
| Actualizar `meta[name="theme-color"]` | Barra del navegador coherente con el tema |
| Fechas locales a medianoche | Evita el error de un día por UTC |

## 4. Qué muestra el dashboard

Todo se calcula en el navegador sobre la lista de la única petición
`GET /api/tareas`. No hay endpoint nuevo ni caché adicional.

| Bloque | Cálculo |
|---|---|
| Progreso general | `completadas / total`, con nota de pendientes |
| Vencidas | Sin completar y fecha anterior a hoy |
| Para hoy | Sin completar y fecha igual a hoy |
| Próximos 7 días | Sin completar, desde mañana hasta hoy + 7 |
| Sin fecha | Sin completar y sin fecha límite |
| Prioridad | Todas las tareas, con cantidad y porcentaje |
| Estado | Todas las tareas, con cantidad, porcentaje y barra apilada |
| Carga semanal | Sin completar con fecha, 7 columnas desde mañana |
| Próximas tareas | Hasta 5 sin completar, ordenadas por fecha |

Estados cubiertos:

- **Cargando:** guiones y textos "Cargando…".
- **Error:** "No disponible"; nunca cifras inventadas.
- **Vacío:** mensajes específicos, sin gráficos ni barras falsas.

## 5. Verificación real

### 5.1 Backend y recursos

```text
Tests run: 34, Failures: 0, Errors: 0, Skipped: 0
```

No se modificó ninguna clase Java ni ninguna prueba. Los recursos de
`target/classes/static` son idénticos (SHA-256) a los de
`src/main/resources/static`.

| Recurso | Código | `Content-Type` | Tamaño |
|---|---|---|---|
| `/` | `200` | `text/html` | 28.986 B |
| `/css/estilos.css` | `200` | `text/css` | 39.443 B |
| `/js/app.js` | `200` | `text/javascript` | 41.067 B |
| `/js/tema.js` | `200` | `text/javascript` | 3.678 B |
| `/js/api.js` | `200` | `text/javascript` | 3.208 B |
| `/img/favicon.svg` | `200` | `image/svg+xml` | 305 B |
| `/api/health` | `200` | `application/json` | DB `UP` |

### 5.2 Verificación E2E con Chrome y MySQL real

Chrome headless con CDP, viewport emulado de verdad y peticiones reales. La
verificación terminó con **134 entradas correctas**, sin fallos:

| Comprobación | Resultado |
|---|---|
| Base inicial | 0 tareas |
| Analíticas con base vacía | Progreso `0 %`, métricas a `0`, "Sin tareas", sin gráfico |
| Crear 8 tareas de prueba | 8 `POST 201` |
| Una sola petición `GET` por carga | 1 |
| Contadores de estado | `4 / 2 / 2` |
| Progreso general | `25 %`, `2 de 8 tareas completadas`, `aria-valuenow=25` |
| Vencimientos | `1 / 1 / 3 / 1` |
| Prioridad | Alta `3 (38 %)`, Media `3 (38 %)`, Baja `2 (25 %)` |
| Estado | Pendiente `4 (50 %)`, En proceso `2 (25 %)`, Completada `2 (25 %)` |
| Barra apilada | `50 % / 25 % / 25 %` |
| Carga semanal | 7 columnas, total `3`, días `1/0/1/0/0/0/1` |
| Próximas tareas | 5 filas ordenadas, vencida marcada |
| Tema del sistema | Oscuro detectado sin preferencia guardada |
| Preferencia guardada | Gana al sistema en ambos sentidos |
| Cambio del sistema en vivo | La página lo sigue si no hay preferencia |
| Sincronización entre pestañas | Cambio real en dos pestañas con `storage` |
| Diálogo, tarjeta, aviso y confirmación en oscuro | Superficies y texto correctos |
| Movimiento reducido | Sin clase de transición y duración `1e-05s` |
| Movimiento normal | Transición `0.22s` y retirada de la clase |
| Errores de consola | 0 |
| Peticiones externas | 0 |

### 5.3 Contraste WCAG AA

Se midieron 18 pares de color en cada tema. Todos superan 4.5:1:

| Par | Claro | Oscuro |
|---|---:|---:|
| Texto principal sobre fondo | 15.92:1 | 15.55:1 |
| Texto suave sobre fondo | 5.49:1 | 8.54:1 |
| Texto tenue sobre superficie | 4.85:1 | 5.59:1 |
| Primario de texto sobre superficie | 5.50:1 | 8.84:1 |
| Prioridad alta | 4.63:1 | 7.30:1 |
| Prioridad media | 5.12:1 | 8.43:1 |
| Prioridad baja | 5.29:1 | 8.36:1 |
| Estados (mínimo) | 5.29:1 | 6.90:1 |
| Blanco sobre botón primario | 5.50:1 | 4.85:1 |
| Blanco sobre botón peligro | 5.18:1 | 4.72:1 |

Mínimos globales: **4.63:1 en claro** y **4.72:1 en oscuro**.

### 5.4 Responsive

| Ancho | Desbordamiento página | Cabecera | Analíticas | Gráfico | Interruptor |
|---|---:|---:|---|---|---|
| 1440 claro/oscuro | 0 (revisión visual) | 0 | 2 columnas | 7 columnas | Visible |
| 1024 claro/oscuro | 0 | 0 | 2 columnas | 7 columnas | En pantalla |
| 768 claro/oscuro | 0 | 0 | 1 columna | 7 columnas | En pantalla |
| 390 claro/oscuro | 0 | 0 | 1 columna | 7 columnas | En pantalla |

La revisión visual detectó que a ≤ 640 px la etiqueta "Completada" se solapaba con
su barra porque la columna medía 84 px. Se corrigió a **100 px** y se regeneraron
las capturas móviles. La comprobación E2E completa se repitió después del cambio.

### 5.5 Capturas revisadas

En `docs/capturas/`:

- `fase7-vacio-claro-1440.png`
- `fase7-dashboard-claro-1440.png`
- `fase7-dashboard-oscuro-1440.png`
- `fase7-dashboard-claro-1024.png`
- `fase7-dashboard-oscuro-768.png`
- `fase7-dashboard-claro-390.png`
- `fase7-dashboard-oscuro-390.png`
- `fase7-dialogo-oscuro-1440.png`
- `fase7-toast-oscuro-1440.png`

Se revisaron una a una, en claro y en oscuro según cada captura. Todas se tomaron
con tareas reales.

## 6. Limpieza

- Las 8 tareas de prueba se eliminaron con `DELETE` real.
- Comprobación final: `GET /api/tareas` devuelve `[]` (`0 filas`).
- La interfaz se recargó y mostró el estado vacío y las analíticas a cero.
- No quedan datos ficticios, temporales ni de ejemplo.
- Flyway sigue en `V1` y `V2`; no se aplicó ninguna migración nueva.

## 7. Seguridad y alcance

- `scripts/check-no-secrets.ps1` → sin coincidencias.
- Ninguna contraseña en archivos, capturas, logs ni en este informe.
- Sin dependencias nuevas; sin CDN, fuentes ni peticiones externas.
- Sin `innerHTML` con datos de la API.
- La aplicación sigue sin login, sin registro y sin autenticación.
- Sigue siendo local (`127.0.0.1:8080`): no debe exponerse a internet.

## 8. Limitaciones conocidas

- Las analíticas se calculan en el navegador con la lista completa. Con miles de
  tareas convendría un endpoint agregado en el servidor.
- La preferencia de tema es local al navegador; no viaja entre equipos.
- Sin paginación, buscador ni deshacer tras eliminar.
- Si JavaScript está desactivado no hay datos, analíticas, tema ni diálogos.

## 9. Checklist

- [x] Analíticas de progreso, vencimientos, prioridad, estado y carga semanal
- [x] Una sola petición `GET /api/tareas` por carga
- [x] Interruptor claro/oscuro visible y accesible
- [x] Detección del sistema y preferencia guardada
- [x] Sincronización entre pestañas
- [x] Tema aplicado a vistas, tarjetas, diálogos y avisos
- [x] Contraste AA en ambos temas
- [x] Movimiento reducido respetado
- [x] Responsive 1440 / 1024 / 768 / 390 en ambos temas
- [x] Diseño y saludo personalizado conservados
- [x] 34 tests del backend
- [x] MySQL limpio (`0 filas`) y Flyway v2
- [x] Sin secretos, dependencias nuevas ni cambios de backend
- [ ] Aprobación de la persona

**No se ha iniciado la Fase 8.**
