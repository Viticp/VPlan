# Pruebas y calidad

Esta guía explica cómo se verificó VPlan en la Fase 8 y cómo puedes repetir las
pruebas. La idea central es sencilla: **no basta con que la aplicación arranque**.
Hay que demostrar que guarda, que valida, que falla con elegancia y que se puede
usar con teclado, en móvil y en tema oscuro.

## 1. La pirámide de pruebas de VPlan

| Nivel | Qué comprueba | Herramienta | Cantidad |
|---|---|---|---:|
| Unitarios y de contexto | Servicio, entidad, repositorio, controlador y health | JUnit 5 + MockMvc + H2 | 34 |
| API real | CRUD, validación, HTTP, filtros y límites | Node + `fetch` + MySQL | 53 |
| Interfaz real | Diálogos, teclado, filtros, red, responsive | Chrome + CDP | 98 |
| Regresión | Dashboard, analíticas y tema de la Fase 7 | Chrome + CDP | 134 |

Los **34 tests de backend** son la única suite automatizada incluida en el
repositorio. Las suites de API, interfaz y regresión se ejecutaron con scripts
guardados en `target/`, que Git ignora, y **no se publican**: sus cifras quedan
como evidencia de la verificación original y no se pueden repetir solo con el
repositorio.

Los tests de backend usan **H2 en modo MySQL**, así que no necesitan la base real.
Las suites de API e interfaz sí usan **MySQL 8** y la aplicación arrancada.

## 2. Tests del backend

```powershell
. .\scripts\set-dev-env.ps1
.\mvnw.cmd test
```

Esta es la suite que puedes ejecutar tal cual con el repositorio: usa H2 y no
necesita MySQL ni ningún script adicional.

Qué demuestran, por capas:

- **Entidad:** normaliza el título, asigna fechas y conserva `creadoEn`.
- **Repositorio:** las consultas derivadas filtran y ordenan por `id`.
- **Servicio:** estado por defecto, actualización parcial y excepciones.
- **Controlador:** códigos `201`, `200`, `204`, `400`, `404`, `405`, `415` y forma
  del JSON de error.
- **Health:** responde `UP` y devuelve `503` si la base falla.

Un test unitario no sustituye a una prueba real: H2 puede aceptar algo que MySQL
rechace. Por eso la Fase 8 añade pruebas contra el motor verdadero.

## 3. Pruebas de API contra MySQL

El verificador de esta sección **no forma parte del repositorio**: se ejecutó desde
`target/` y se conserva aquí como documentación del método. Para repetir pruebas
automatizadas con lo publicado, usa `.\mvnw.cmd test`.

```powershell
node target\verify-phase8-api.mjs
```

El patrón de cada comprobación es:

```js
const respuesta = await fetch(BASE + '/api/tareas', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ titulo: 'Temporal', prioridad: 'MEDIA' })
});
afirmar('crear devuelve 201', respuesta.status === 201);
```

Qué conviene probar siempre en una API:

1. **Camino feliz:** crear, leer, editar y borrar.
2. **Validación:** campos obligatorios, longitudes máximas, enums inválidos,
   fechas imposibles y JSON mal formado.
3. **Errores HTTP:** `404` al pedir algo que no existe, `405` con un método no
   permitido, `415` con un `Content-Type` incorrecto.
4. **Filtros:** cada uno por separado, combinados y sin resultados.
5. **Límites exactos:** 120 caracteres se aceptan; 121 se rechazan.
6. **Normalización:** espacios recortados y descripción vacía convertida en `null`.
7. **Fugas:** el cuerpo del error no debe contener `java.`, `Exception` ni SQL.

### Una lección real: Hibernate y los cambios invisibles

La primera versión de la prueba hacía un `PUT` con **exactamente los mismos
valores** y esperaba que `actualizadoEn` avanzara. Falló. No era un fallo de la
aplicación: Hibernate compara el estado y, si nada cambió, no ejecuta `UPDATE`.
La prueba correcta cambia al menos un campo después de la pausa:

```js
await new Promise((listo) => setTimeout(listo, 1100));
await pedir(`/api/tareas/${id}`, put({ ...datos, descripcion: 'Cambio real' }));
```

**Moraleja:** una prueba que falla no siempre descubre un defecto del producto.
Antes de tocar código, comprueba que la prueba mide lo que crees que mide.

## 4. Comprobación directa en MySQL

La API podría mentir si el frontend o la caché muestran datos viejos. Por eso se
consulta la base con JDBC, sin pasar por Spring. El programa auxiliar de esta fase
(`VerifyFase8.java`) se guardó en `target/` y no se publica; el fragmento siguiente
contiene la consulta completa:

```java
try (Connection conexion = DriverManager.getConnection(url, usuario, contrasena);
     Statement sentencia = conexion.createStatement();
     ResultSet rs = sentencia.executeQuery("SELECT COUNT(*) FROM tareas")) {
    rs.next();
    System.out.println("FILAS_TAREAS=" + rs.getInt(1));
}
```

Buenas prácticas aplicadas:

- La contraseña se lee de `VPLAN_DB_PASSWORD`; **nunca** se imprime.
- Se consultan `tareas` y `flyway_schema_history`.
- Se comprueba `success=true` en `V1` y `V2`.
- No se ejecuta ningún `INSERT`, `UPDATE`, `DELETE` ni `ALTER` desde este programa.

El recuento inicial y final debe ser el mismo. En esta fase: **0 → 0**.

## 5. Pruebas de interfaz con Chrome DevTools Protocol

No se añadió Playwright ni Selenium. Chrome ya ofrece un protocolo para abrir una
pestaña, navegar, evaluar JavaScript, simular teclas y lanzar peticiones fallidas.
El script que automatiza estas comprobaciones tampoco se publica —también vivía en
`target/`—; los fragmentos siguientes muestran el método seguido y permiten
reproducirlo a mano.

### 5.1 Conectar

```powershell
chrome.exe --headless=new --remote-debugging-port=9222 --user-data-dir=<perfil-temporal>
```

El script busca la pestaña en `http://127.0.0.1:9222/json/list`, abre su
`webSocketDebuggerUrl` y envía comandos:

```js
const respuesta = await cdp.enviar('Runtime.evaluate', {
    expression: `document.querySelectorAll('.tarjeta-tarea').length`,
    returnByValue: true
});
```

### 5.2 Esperar, no dormir a ciegas

Un `setTimeout` fijo hace pruebas lentas y frágiles. Es mejor esperar una condición:

```js
async function esperarHasta(expresion, timeout, descripcion) {
    const inicio = Date.now();
    while (Date.now() - inicio < timeout) {
        if (await evaluar(expresion)) return true;
        await esperar(100);
    }
    throw new Error(`Timeout esperando: ${descripcion}`);
}
```

Así la prueba continúa en cuanto la interfaz está lista y falla con un mensaje
claro si algo se queda cargando.

### 5.3 Simular red lenta y red caída

CDP permite interceptar `fetch`. Para una caída real:

```js
await cdp.enviar('Fetch.failRequest', { requestId, errorReason: 'Failed' });
```

Para una carga lenta, se retrasa la petición antes de continuarla:

```js
await esperar(1500);
await cdp.enviar('Fetch.continueRequest', { requestId });
```

Y se comprueba que **mientras** dura la espera se ven los esqueletos de carga, no
una pantalla vacía ni datos inventados.

### 5.4 Simular teclado y viewport

```js
await cdp.enviar('Input.dispatchKeyEvent', {
    type: 'keyDown', key: 'Enter', code: 'Enter',
    windowsVirtualKeyCode: 13, text: '\r'
});
```

Para responsive:

```js
await cdp.enviar('Emulation.setDeviceMetricsOverride', {
    width: 390, height: 844, deviceScaleFactor: 1, mobile: true
});
```

Detalle aprendido: en CDP, `Enter` necesita `text: '\r'` para activar un botón, y
la pestaña debe estar en primer plano (`Page.bringToFront`). Sin eso, el evento
llega pero no abre el diálogo.

## 6. Qué se comprueba en la interfaz

| Comportamiento | Cómo se demuestra |
|---|---|
| Estado vacío | Contadores a `0`, mensaje específico y botón de crear |
| Crear | Diálogo abierto, foco en el título, `POST` real y tarjeta nueva |
| Validación | Título en blanco → aviso del servidor y foco en el campo |
| Editar | Campos precargados, `PUT` real y tarjeta actualizada |
| Cancelar | `Escape` cierra, no guarda y devuelve el foco |
| Filtros | `aria-pressed`, contador `n de m` y vacío por filtros |
| Inyección HTML | `<img>`, `<script>` y `<b>` aparecen como texto, sin ejecutarse |
| Red caída | Paneles de error, "Sin datos" y botón de reintento |
| Reintento | La lista se recupera sin recargar la página |
| Tema | `role="switch"`, `aria-checked`, `localStorage` y persistencia |
| Movimiento reducido | No se añade la clase de transición |
| Responsive | `scrollWidth - innerWidth <= 0` en 4 anchos |
| Menú móvil | Se abre, enfoca el primer enlace y `Escape` lo cierra |

## 7. Comprobar accesibilidad sin herramientas externas

- **Teclado:** enfoca cada control y pulsa `Enter`; comprueba que ocurre lo mismo
  que con el ratón.
- **Foco:** al abrir un diálogo debe ir al primer campo; al cerrar, volver al botón
  que lo abrió.
- **Etiquetas:** `campo.labels.length > 0` para todos los campos.
- **Anuncios:** `aria-live="polite"` en el contador y `role="status"`/`alert` en
  los avisos.
- **Contraste:** se leen las variables CSS, se calcula la luminancia relativa y se
  exige `>= 4.5:1`. En esta fase pasaron 18 pares en claro y 18 en oscuro.
- **Movimiento:** se emula `prefers-reduced-motion: reduce` y se comprueba que el
  cambio de tema no anima.

## 8. Revisión de seguridad

Grep rápido antes de cualquier entrega:

```powershell
Select-String -Path src\main\resources\static\**\*.js `
  -Pattern 'innerHTML|outerHTML|insertAdjacentHTML|eval\(|new Function|document\.write'
```

En VPlan no hay coincidencias. Los datos de la API se pintan con `textContent`
y `createElement`. Además:

- Solo se llama a `/api/tareas`; no hay CDN ni peticiones externas.
- La aplicación escucha en `127.0.0.1`, no en `0.0.0.0`.
- Los errores no incluyen trazas ni SQL.
- `scripts/check-no-secrets.ps1` compara los valores reales de `.env.local` con
  todos los archivos y falla si encuentra uno.
- `.gitignore` excluye `.env*`, `backups/`, `*.dump` y `target/`.

## 9. Limpieza de datos temporales

Regla de oro: **crear solo lo necesario y borrar solo lo creado**.

1. Anotar el recuento inicial (`GET /api/tareas`).
2. Crear tareas con un prefijo inequívoco: `Fase 8 · ...`.
3. Borrar por `id` o por ese prefijo, nunca "todas las tareas".
4. Comprobar que el recuento final coincide con el inicial.
5. Verificar también en MySQL, no solo en la API.

Las suites de esta fase limpian en un bloque `finally`, de modo que aunque una
comprobación falle, los datos temporales no se quedan en la base.

## 10. Cómo leer un fallo

| Mensaje | Significado habitual |
|---|---|
| `Timeout esperando: ...` | La interfaz no llegó al estado esperado; revisa consola y red |
| `FALLO: ... — código 500` | Error del servidor; mira el log de Spring Boot |
| `FALLO: ... — 1 filas` | Quedaron datos de una ejecución anterior |
| `FALLO: contraste ...` | Un par de colores baja de 4.5:1 |
| `FALLO: sin peticiones externas` | Algún recurso apunta fuera de `localhost` |
| `SecurityError: localStorage` | Se evaluó en `about:blank`; navega primero al origen |

Antes de corregir código, pregunta: **¿el fallo está en el producto o en la
prueba?** En la Fase 8, las tres incidencias fueron de las herramientas; no se
cambió ninguna línea de la aplicación.

## 11. Checklist para futuras fases

- [ ] La suite del backend pasa antes de tocar nada.
- [ ] Hay una prueba real contra MySQL, no solo H2.
- [ ] Se comprueba el recuento inicial y final.
- [ ] Se prueban validaciones y errores HTTP, no solo el camino feliz.
- [ ] Se prueba la interfaz con teclado y en 390 px.
- [ ] Se revisan consola, red externa y secretos.
- [ ] Se documenta cualquier corrección y se repite lo afectado.
- [ ] No se declara una fase terminada si quedan pruebas críticas pendientes.
