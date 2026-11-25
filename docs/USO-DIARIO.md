# Uso diario de VPlan en Windows 11

VPlan es una aplicación **local, privada y de un solo usuario**. Se abre en
`http://localhost:8080` y guarda las tareas en MySQL. No tiene login ni se publica
en internet.

Esta guía es la referencia corta para el día a día. La instalación completa y el
traslado a otro ordenador están en [INSTALACION.md](../INSTALACION.md).

---

## Arrancar

Desde la carpeta del proyecto:

```powershell
.\scripts\start-vplan.ps1
```

El script:

1. Detecta un JDK 21 o superior y carga `.env.local` sin mostrar la contraseña.
2. Comprueba que MySQL responde en `127.0.0.1:3306`.
3. Comprueba que el puerto 8080 está libre o que ya lo usa VPlan.
4. Arranca Spring Boot en segundo plano.
5. Espera a que `/api/health` esté `UP` y abre el navegador.
6. Guarda el PID en `logs/vplan.pid` y la salida en
   `logs/vplan-AAAA-MM-DD_HHmmss.log`.

Si VPlan ya está en marcha, no arranca una segunda copia: abre el navegador. Si
el puerto lo ocupa otro programa, se niega a continuar y muestra el PID.

La primera vez Maven descarga dependencias. Si tarda más de lo normal:

```powershell
.\scripts\start-vplan.ps1 -TimeoutSeconds 180
```

Opciones:

| Opción | Para qué |
|---|---|
| `-NoBrowser` | No abrir el navegador |
| `-TimeoutSeconds 180` | Esperar más tiempo |
| `-Foreground` | Ver la salida de Maven en la consola (depuración) |

### Acceso directo

```powershell
.\scripts\create-shortcuts.ps1
```

Crea **VPlan** en el escritorio. El doble clic arranca VPlan si hace falta y lo
abre en una ventana de Chrome en modo aplicación, sin pestañas ni barra de
direcciones. Al cerrar esa ventana se detiene el servidor que arrancó el propio
acceso directo.

Si VPlan ya estaba en marcha por otro método, se reutiliza esa instancia y no se
detiene al cerrar la ventana. La ventana usa un perfil de Chrome independiente
(`logs\vplan-chrome-profile`), así que no comparte cookies ni el tema con tu
Chrome normal. Para reemplazar el acceso directo:

```powershell
.\scripts\create-shortcuts.ps1 -Force
```

---

## Parar

```powershell
.\scripts\stop-vplan.ps1
```

El script comprueba que el proceso del puerto 8080 es VPlan, lo detiene, para
también el lanzador de Maven, espera a que el puerto quede libre y borra el archivo
de PID. Si no hay nada en marcha, termina sin error.

**No detiene procesos ajenos.** Si el puerto lo ocupa otro programa, se niega. No
uses `-Force` salvo que estés completamente seguro.

---

## Comprobar que está bien

```powershell
Invoke-RestMethod http://localhost:8080/api/health | ConvertTo-Json
```

Respuesta esperada:

```json
{
  "status": "UP",
  "application": "vplan",
  "database": "UP",
  "timestamp": "2026-11-17T09:50:00Z"
}
```

Si `database` es `DOWN`, MySQL no responde o la contraseña no es correcta.

---

## Dónde están las cosas

| Elemento | Ruta |
|---|---|
| Aplicación | `http://localhost:8080` |
| Logs de arranque | `logs\vplan-AAAA-MM-DD_HHmmss.log` |
| PID del último arranque | `logs\vplan.pid` |
| Copias de seguridad | `backups\vplan-AAAA-MM-DD_HHmmss.sql` |
| Contraseña local | `.env.local` (ignorado por Git; no compartir) |
| Configuración | `src\main\resources\application.yml` (sin contraseñas) |

`logs/`, `backups/`, `target/` y `.env.local` están ignorados por Git.

---

## Copia de seguridad

Con VPlan parado o en marcha:

```powershell
.\scripts\backup-db.ps1
```

La copia incluye **toda** la base `vplan`: la tabla `tareas` y el historial de
Flyway. Guarda el archivo en un lugar privado (disco externo o copia cifrada). No
lo subas a GitHub.

### Restaurar

Con VPlan parado:

```powershell
.\scripts\stop-vplan.ps1
.\scripts\restore-db.ps1 -BackupFile ".\backups\vplan-2026-11-17_132926.sql"
```

El script valida el archivo, se niega a continuar si el puerto 8080 está ocupado y
pide escribir `RESTAURAR`.

Para probar una restauración sin tocar tus datos hace falta una base
independiente (`vplan_restore_test`) y permisos que `vplan_app` no tiene por
defecto. El SQL exacto está en
[INSTALACION.md](../INSTALACION.md#probar-una-restauración-sin-tocar-tus-datos).

---

## Problemas frecuentes

| Síntoma | Solución |
|---|---|
| `Falta VPLAN_DB_PASSWORD` | Ejecuta `.\scripts\set-db-password.ps1` |
| `MySQL no responde` | `Get-Service MySQL80` y `Start-Service MySQL80` |
| El puerto 8080 está ocupado | `Get-NetTCPConnection -LocalPort 8080`; no fuerces procesos ajenos |
| VPlan ya está en marcha | Es normal; abre `http://localhost:8080` |
| El arranque falla | Revisa el log que indica el script, en `logs\` |
| La parada no detiene un proceso | Es una protección; usa `-Force` solo si estás seguro |
| No aparece el acceso directo | Ejecuta `.\scripts\create-shortcuts.ps1` |
| Al cerrar la ventana no se detiene el servidor | VPlan ya estaba en marcha por otro método; es intencionado |

---

## Seguridad

- No hay autenticación: cualquiera con acceso a este equipo puede ver y modificar
  las tareas.
- La aplicación escucha solo en `127.0.0.1:8080`.
- No expongas el puerto 8080 ni MySQL a internet.
- Mantén `.env.local` y `backups/` fuera de Git y de servicios públicos.

En este equipo, MySQL está configurado con `bind-address=127.0.0.1` en `my.ini`
y escucha solo en loopback. Si lo instalas en otro equipo, aplica el mismo
procedimiento de [INSTALACION.md](../INSTALACION.md#privacidad-aceptar-solo-conexiones-locales).

---

## Llevar VPlan a otro ordenador

Resumen:

1. Copia el proyecto sin `target/`, `backups/`, `logs/` ni `.env.local`.
2. Copia el archivo `.sql` de la copia de seguridad por un medio privado.
3. Instala JDK 21+ y MySQL 8.0+.
4. Crea la base `vplan` y el usuario `vplan_app` con una contraseña nueva.
5. Ejecuta `.\scripts\set-db-password.ps1`.
6. Restaura la copia con `.\scripts\restore-db.ps1`.
7. Arranca con `.\scripts\start-vplan.ps1`.

Lista completa y comprobaciones: [INSTALACION.md](../INSTALACION.md#8-trasladar-vplan-a-otro-ordenador).
