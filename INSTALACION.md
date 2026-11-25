# Instalación y traslado de VPlan

VPlan es una aplicación **local, privada y de un solo usuario**. Se ejecuta en
tu ordenador y se abre en `http://localhost:8080`. No se publica en internet, no
necesita hosting y no tiene login ni registro.

Esta guía explica cómo instalarla en un Windows limpio, cómo trasladarla desde
otro ordenador y cómo hacer copias de seguridad de las tareas.

> **Atajo:** si ya tienes el proyecto y el entorno configurados, ve directamente a
> [Uso diario: arrancar y parar](#6-uso-diario-arrancar-y-parar).

---

## 1. Qué necesitas

| Componente | Versión | Notas |
|---|---|---|
| Sistema operativo | Windows 10 u 11 | La guía principal es para Windows |
| Java | **JDK 21 o superior** | Probado con Temurin 21.0.13 |
| Base de datos | **MySQL 8.0 o superior** | Probado con MySQL 8.0.43 |
| Terminal | PowerShell 5.1 o superior | Incluida en Windows |
| Puerto | 8080 libre | Solo se abre en `127.0.0.1` |
| Internet | Solo la primera vez | Maven descarga sus dependencias |

**No necesitas** Maven, Node, Docker, un IDE, un servidor web ni una cuenta en
ningún servicio. Maven se descarga solo mediante el wrapper incluido.

---

## 2. Instalar Java 21 o superior

1. Descarga **Eclipse Temurin 21 (LTS)** desde
   [adoptium.net](https://adoptium.net/).
2. Durante la instalación, activa:
   - **Set JAVA_HOME variable**
   - **Add to PATH**
3. Abre una PowerShell **nueva** y comprueba:

```powershell
java -version
javac -version
```

Ambos comandos deben mostrar una versión **21 o superior**. Si en el equipo hay
varias instalaciones de Java, lo importante es que VPlan encuentre una válida:
el script de entorno busca en este orden:

1. El parámetro `-JavaHome`.
2. La variable `VPLAN_JAVA_HOME`.
3. La variable `JAVA_HOME`.
4. `javac.exe` disponible en el `PATH`.
5. Las rutas habituales de instalación de Windows.

Si no encuentra ninguna, muestra un error claro. Puedes indicar la ruta a mano:

```powershell
. .\scripts\set-dev-env.ps1 -JavaHome "C:\ruta\al\jdk"
```

El script no modifica `JAVA_HOME` del sistema: solo la sesión actual de PowerShell.

---

## 3. Instalar MySQL 8.0 o superior

1. Descarga **MySQL Installer for Windows** desde
   [dev.mysql.com/downloads/installer](https://dev.mysql.com/downloads/installer/).
2. Elige **Custom** e instala:
   - **MySQL Server 8.0** (obligatorio).
   - **MySQL Workbench** (opcional, cómodo para administrar la base).
3. En la configuración del servidor:
   - Tipo: **Development Computer**.
   - Puerto: **3306**.
   - Servicio Windows: **MySQL80**, inicio automático.
   - Contraseña de `root`: larga y guardada en un gestor de contraseñas.
4. Comprueba que el servicio está en marcha:

```powershell
Get-Service MySQL80
```

### Añadir MySQL al PATH (recomendado)

Para usar `mysql` y `mysqldump` sin escribir la ruta completa:

1. Abre **Configuración → Sistema → Acerca de → Configuración avanzada del
   sistema → Variables de entorno**.
2. En las variables del usuario, edita `Path` y añade:

```text
C:\Program Files\MySQL\MySQL Server 8.0\bin
```

3. Cierra y vuelve a abrir PowerShell. Comprueba:

```powershell
mysql --version
mysqldump --version
```

Los scripts de VPlan también buscan MySQL automáticamente en
`C:\Program Files\MySQL\MySQL Server *\bin`, aunque no esté en el `PATH`.

### Privacidad: aceptar solo conexiones locales

VPlan es una aplicación privada, así que MySQL debe escuchar **solo en
localhost**:

1. Localiza `my.ini`. En una instalación habitual está en:

```text
C:\ProgramData\MySQL\MySQL Server 8.0\my.ini
```

> `C:\ProgramData` es una carpeta oculta. Puedes abrirla escribiendo la ruta en
> el Explorador de Windows.

2. En la sección `[mysqld]`, añade o cambia:

```ini
bind-address=127.0.0.1
```

3. Reinicia el servicio desde una PowerShell **como administrador**:

```powershell
Restart-Service MySQL80
```

4. Comprueba que solo escucha en loopback:

```powershell
Get-NetTCPConnection -LocalPort 3306 -State Listen | Select-Object LocalAddress
```

Debe aparecer `127.0.0.1`. Si aparece `::` o `0.0.0.0`, MySQL sigue aceptando
conexiones de la red local.

> **Nota:** si no puedes editar `my.ini`, al menos no abras el puerto 3306 en el
> firewall. El usuario `vplan_app` solo existe para `localhost`, así que un
> equipo remoto no puede autenticarse con él, pero es mejor cerrar el puerto.

> **Estado verificado en este equipo (17/11/2026):** MySQL está configurado con
> `bind-address=127.0.0.1` en `my.ini` y escucha únicamente en loopback. El
> servicio `MySQL80` arranca automáticamente. La aplicación se conecta a
> `127.0.0.1:3306`.

---

## 4. Crear la base de datos y el usuario

El script [`database/00_create_database_and_user.sql`](database/00_create_database_and_user.sql)
crea la base `vplan`, el usuario `vplan_app` y le concede permisos **solo
sobre ese esquema**.

1. Abre el archivo y sustituye `CAMBIA_ESTA_CONTRASENA` por una contraseña larga
   (12 caracteres o más, con mayúsculas, minúsculas, números y símbolos).
2. Ejecútalo como `root` **sin guardar el archivo modificado**:

**Opción A — MySQL Workbench:** abre una conexión como `root`, pega el contenido
modificado y ejecútalo.

**Opción B — consola** (desde la carpeta del proyecto):

```powershell
cmd /c "mysql -u root -p < database\00_create_database_and_user.sql"
```

3. Comprueba el resultado:

```powershell
cmd /c "mysql -u root -p < database\01_verify.sql"
```

Deben aparecer la base `vplan`, el usuario `vplan_app` y sus permisos.
No concedas privilegios globales.

> **Importante:** el archivo versionado debe conservar siempre el marcador
> `CAMBIA_ESTA_CONTRASENA`. Si lo sustituyes, deshaz el cambio o ejecuta el
> `ALTER USER` directamente en la consola. Una contraseña real en un archivo
> versionado acabaría en Git.

---

## 5. Configurar la contraseña de la aplicación

Desde la carpeta del proyecto:

```powershell
.\scripts\set-db-password.ps1
. .\scripts\set-dev-env.ps1
```

- El primer script pide la contraseña **sin mostrarla** y la guarda en
  `.env.local`.
- El segundo detecta el JDK, configura `JAVA_HOME` y el `PATH` solo en esa
  ventana y carga `.env.local`.
- `.env.local` está ignorado por Git y no debe compartirse.

Alternativa manual, solo para la sesión actual:

```powershell
$env:VPLAN_DB_PASSWORD = "la_contrasena_de_vplan_app"
```

### Variables disponibles

| Variable | Obligatoria | Valor por defecto | Para qué |
|---|---|---|---|
| `VPLAN_DB_PASSWORD` | Sí | — | Contraseña de `vplan_app` |
| `VPLAN_DB_USER` | No | `vplan_app` | Usuario de MySQL |
| `VPLAN_DB_URL` | No | `jdbc:mysql://127.0.0.1:3306/vplan...` | URL JDBC |
| `VPLAN_JAVA_HOME` | No | — | Ruta a un JDK 21+ concreto |

Nunca escribas la contraseña en `application.yml`, en el README ni en un script.

---

## 6. Uso diario: arrancar y parar

### Arrancar

Desde la carpeta del proyecto:

```powershell
.\scripts\start-vplan.ps1
```

No hace falta cargar el entorno a mano: el script ejecuta `set-dev-env.ps1`,
detecta el JDK 21+, carga `.env.local`, comprueba que MySQL responde, arranca
Spring Boot en segundo plano y espera a que `/api/health` esté `UP`. Después abre
**http://localhost:8080** en el navegador.

La primera vez Maven descarga sus dependencias. Si el equipo es lento, amplía el
tiempo de espera:

```powershell
.\scripts\start-vplan.ps1 -TimeoutSeconds 180
```

Opciones:

| Opción | Para qué |
|---|---|
| `-NoBrowser` | No abrir el navegador automáticamente |
| `-TimeoutSeconds 180` | Esperar más tiempo la primera vez |
| `-Foreground` | Arrancar en primer plano y ver la salida de Maven (modo depuración) |

El script crea un log por arranque en `logs\vplan-AAAA-MM-DD_HHmmss.log`.
La carpeta `logs/` está ignorada por Git. Si el arranque falla, muestra las
últimas líneas del log y no deja el proceso abierto.

Si VPlan ya está en marcha, el script no arranca una segunda copia: abre el
navegador y termina correctamente. Si el puerto 8080 lo ocupa **otro** programa,
se niega a continuar y muestra su PID.

Comprueba la salud real de la base de datos:

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

Flyway aplica las migraciones `V1` y `V2` la primera vez. La aplicación escucha
**solo en `127.0.0.1:8080`** (`server.address` en `application.yml`). No es
accesible desde otro equipo de la red.

### Parar

```powershell
.\scripts\stop-vplan.ps1
```

El script busca el proceso que escucha en 8080, comprueba que es VPlan, lo
detiene, para también el lanzador de Maven, comprueba que el puerto queda libre y
borra `logs\vplan.pid`. Si no hay nada en marcha, termina sin error.

Nunca detiene un proceso ajeno: si el puerto lo ocupa otro programa, se niega.
Solo si estás completamente seguro puedes usar `-Force`.

### Acceso directo de escritorio

Para abrir VPlan como una aplicación de escritorio:

```powershell
.\scripts\create-shortcuts.ps1
```

Crea un único acceso directo **VPlan** en el escritorio. Al hacer doble clic:

1. Arranca Spring Boot si VPlan no está en marcha.
2. Abre VPlan en una ventana independiente de Chrome en modo aplicación, sin
   pestañas ni barra de direcciones.
3. Cuando cierras esa ventana, detiene el servidor que arrancó el propio acceso
   directo.

Si VPlan ya estaba en marcha (por ejemplo, lanzado con
`start-vplan.ps1` o desde el IDE), el acceso directo reutiliza esa instancia
y **no** la detiene al cerrar la ventana. Tampoco cierra Chrome ni otras
ventanas: solo afecta a la ventana de VPlan y al servidor que inició él mismo.

La ventana usa un perfil de Chrome propio en `logs\vplan-chrome-profile`, por lo
que no comparte cookies ni preferencias (como el tema) con tu Chrome habitual.
Ese perfil dedicado es lo que permite detectar el cierre de la ventana de forma
fiable sin tocar otras ventanas de Chrome.

El acceso directo no necesita permisos de administrador. Si el arranque falla,
muestra un aviso con el error y el detalle queda en `logs\vplan-app.log`.

Para detener VPlan manualmente sigue usando:

```powershell
.\scripts\stop-vplan.ps1
```

Si el acceso directo ya existe y quieres reemplazarlo:

```powershell
.\scripts\create-shortcuts.ps1 -Force
```

### Modo manual

Para depurar en primer plano puedes seguir usando Maven directamente:

```powershell
. .\scripts\set-dev-env.ps1
.\mvnw.cmd spring-boot:run
```

En ese caso se para con `Ctrl + C`. El script de parada también puede detener la
aplicación, pero la ventana de Maven debe cerrarse a mano.

---

## 7. Copias de seguridad y restauración

### Qué debe incluir una copia

Toda la base `vplan`:

- La tabla `tareas` con tus datos.
- La tabla `flyway_schema_history` con las migraciones aplicadas.

**No restaures solo `tareas`.** Si falta el historial de Flyway, la aplicación
intentará aplicar `V1` sobre un esquema que ya existe y fallará.

**No copies la carpeta `data/` de MySQL.** No es portable entre versiones ni
equipos. Usa un dump SQL.

### Crear una copia

```powershell
.\scripts\backup-db.ps1
```

Se crea `backups\vplan-AAAA-MM-DD_HHmmss.sql`. El script:

- Usa `--single-transaction`, así que la copia es consistente.
- Incluye `--no-tablespaces`, necesario porque `vplan_app` no tiene el
  privilegio global `PROCESS`.
- Comprueba que el archivo contiene `tareas` y `flyway_schema_history`.
- No imprime la contraseña.

La carpeta `backups/` está ignorada por Git. Guarda una copia en un lugar privado
(por ejemplo, un disco externo o un gestor de copias cifrado).

### Restaurar una copia

Con VPlan **parado**:

```powershell
.\scripts\stop-vplan.ps1
.\scripts\restore-db.ps1 -BackupFile ".\backups\vplan-2026-11-17_120000.sql"
```

El script:

1. Comprueba que el archivo existe y contiene las tablas esperadas.
2. Se niega a continuar si algo escucha en el puerto 8080.
3. Pide escribir `RESTAURAR` antes de modificar nada.
4. Verifica al terminar las migraciones de Flyway y el número de tareas.

`-Force` omite la confirmación interactiva. Úsalo solo con la aplicación parada y
cuando estés seguro de la base de destino.

### Probar una restauración sin tocar tus datos

La forma segura es restaurar en una base independiente, por ejemplo
`vplan_restore_test`. El usuario `vplan_app` **no puede crearla ni usarla**
con los permisos actuales: solo tiene permisos sobre `vplan.*`. Para habilitar
la prueba, un usuario administrador de MySQL debe ejecutar una vez:

```sql
CREATE DATABASE vplan_restore_test
  CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;

GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, REFERENCES, INDEX, ALTER
  ON vplan_restore_test.* TO 'vplan_app'@'localhost';
```

Después:

```powershell
.\scripts\restore-db.ps1 -BackupFile ".\backups\vplan-2026-11-17_120000.sql" `
  -Database vplan_restore_test -Force
```

Al terminar, comprueba el número de tareas y Flyway, y elimina la base de prueba
con un usuario administrador:

```sql
DROP DATABASE vplan_restore_test;
```

**No restaures sobre `vplan` solo para probar.** Si no puedes crear la base de
pruebas, la restauración real queda pendiente; es preferible eso a arriesgar los
datos personales.

> **Verificado en la Fase 9 (17/11/2026):** se creó una copia real de `vplan`
> con 0 tareas y ambas tablas (`backups/vplan-2026-11-17_132926.sql`, 3,6 KB).
> Se probaron las negativas del script: archivo inexistente, archivo sin tablas,
> aplicación en marcha y cancelación de la confirmación. La restauración en
> `vplan_restore_test` **no se pudo ejecutar** porque `vplan_app` recibió
> `ERROR 1044 (42000): Access denied` al intentar crear la base. No se forzó nada
> ni se tocó la base real.

### Copia manual (sin los scripts)

Si prefieres hacerlo a mano, el comando equivalente es:

```powershell
& "C:\Program Files\MySQL\MySQL Server 8.0\bin\mysqldump.exe" `
  --host=127.0.0.1 --port=3306 --user=vplan_app `
  --single-transaction --no-tablespaces --skip-add-locks --skip-triggers `
  --set-gtid-purged=OFF --default-character-set=utf8mb4 `
  --result-file="backups\vplan-manual.sql" vplan
```

La contraseña se pedirá de forma interactiva. Para restaurar, con la aplicación
parada:

```powershell
cmd /c "mysql --host=127.0.0.1 --port=3306 --user=vplan_app --default-character-set=utf8mb4 vplan < backups\vplan-manual.sql"
```

---

## 8. Trasladar VPlan a otro ordenador

### Qué copiar

| Copiar | No copiar |
|---|---|
| Código fuente del proyecto (`src/`, `pom.xml`, `mvnw`, `.mvn/`, `database/`, `scripts/`, `docs/`) | `target/` (se regenera con Maven) |
| El archivo `.sql` de la copia de seguridad | `.env.local` (se crea de nuevo con otra contraseña) |
| `README.md`, `INSTALACION.md` | La carpeta `data/` de MySQL |
| | Copias antiguas que no necesites |

Si el repositorio ya está publicado y tienes acceso, clona la URL. Mientras siga
siendo privado y sin commits, copia la carpeta fuente. En ambos casos excluye
`target/`, `backups/`, `logs/` y `.env.local`: se regeneran o contienen secretos.

### Lista de comprobación en el ordenador nuevo

- [ ] JDK 21 o superior instalado y visible (`java -version`).
- [ ] MySQL 8.0 o superior instalado, en marcha y con `bind-address=127.0.0.1`.
- [ ] Proyecto copiado o clonado, sin `target/`.
- [ ] Copia de seguridad `.sql` copiada de forma privada.
- [ ] Base `vplan` y usuario `vplan_app` creados con una contraseña nueva.
- [ ] `.env.local` creado con `set-db-password.ps1`.
- [ ] Copia restaurada con `restore-db.ps1`.
- [ ] `.\scripts\start-vplan.ps1` arranca sin errores y abre el navegador.
- [ ] `/api/health` responde `UP` y las tareas aparecen en la interfaz.
- [ ] Flyway sigue en la versión 2.
- [ ] `.\scripts\create-shortcuts.ps1` crea el acceso directo VPlan (opcional).
- [ ] La copia `.sql` se borra del equipo viejo si ya no se necesita.

### Restauración en el equipo nuevo, paso a paso

```powershell
# 1. Crear la base y el usuario (con una contraseña nueva)
cmd /c "mysql -u root -p < database\00_create_database_and_user.sql"

# 2. Configurar la contraseña de la aplicación
.\scripts\set-db-password.ps1

# 3. Cargar el entorno
. .\scripts\set-dev-env.ps1

# 4. Restaurar la copia
.\scripts\restore-db.ps1 -BackupFile "C:\ruta\a\vplan-2026-11-17_120000.sql"

# 5. Arrancar y comprobar
.\scripts\start-vplan.ps1
Invoke-RestMethod http://localhost:8080/api/health | ConvertTo-Json
```

El arranque carga el entorno por sí solo; no hace falta ejecutar
`set-dev-env.ps1` antes. La primera vez puede tardar en descargar dependencias:
si el script agota el tiempo, repite con `-TimeoutSeconds 180`.

---

## 9. Problemas habituales

| Síntoma | Causa probable | Solución |
|---|---|---|
| `No se ha encontrado un JDK 21 o superior` | No hay JDK o el que hay es antiguo | Instala Temurin 21+ o usa `-JavaHome` |
| `java -version` muestra 8 u 11 | Otra instalación manda en el `PATH` | El script de entorno busca una válida; si no, indica `-JavaHome` |
| `Access denied for user 'vplan_app'` | Contraseña incorrecta o usuario no creado | Revisa `database/00_create_database_and_user.sql` y `.env.local` |
| `Communications link failure` | MySQL parado | `Get-Service MySQL80` y `Start-Service MySQL80` |
| `Unknown database 'vplan'` | No se ejecutó el script de creación | Ejecuta `00_create_database_and_user.sql` |
| `Port 8080 was already in use` | Otra aplicación usa el puerto | `Get-NetTCPConnection -LocalPort 8080` y detén ese proceso |
| El arranque dice que VPlan ya está en marcha | Ya hay una instancia escuchando en 8080 | Es normal: abre el navegador. Si `/api/health` no responde `UP`, revisa el log y usa `stop-vplan.ps1` |
| El puerto 8080 lo ocupa otro programa | Hay un proceso ajeno | El arranque y la parada se niegan a tocarlo. Identifícalo con `Get-NetTCPConnection -LocalPort 8080` |
| `Falta VPLAN_DB_PASSWORD` | No existe `.env.local` o no se cargó | Ejecuta `.\scripts\set-db-password.ps1` y vuelve a arrancar |
| No sé dónde está el error de arranque | La salida va al log | Abre `logs\vplan-AAAA-MM-DD_HHmmss.log`; el script muestra las últimas líneas si falla |
| `Access denied ... vplan_restore_test` | `vplan_app` no tiene permisos sobre la base de prueba | Pide a un administrador que cree la base y conceda permisos (sección 7) |
| El acceso directo no aparece | No se creó o el escritorio es otro | Ejecuta `.\scripts\create-shortcuts.ps1` y revisa la ruta que imprime |
| Al cerrar la ventana de VPlan no se detiene el servidor | VPlan ya estaba en marcha por otro método | Es intencionado: el acceso directo solo detiene lo que arrancó él. Para pararlo usa `stop-vplan.ps1` |
| La parada no detiene un proceso que no es VPlan | Es una protección deliberada | No uses `-Force` salvo que estés seguro de que puedes cerrar ese proceso |
| `mysqldump: Access denied ... PROCESS privilege` | `vplan_app` no tiene privilegios globales | Usa `backup-db.ps1` o añade `--no-tablespaces` |
| Flyway: `applied migration not resolved locally` | Se editó una migración ya aplicada | No edites `V1` ni `V2`; crea `V3__...` |
| Flyway: `Schema-validation: missing table` | El dump no incluía `flyway_schema_history` | Restaura una copia completa |
| `No se puede cargar el archivo ... porque la ejecución de scripts está deshabilitada` | Política de PowerShell | `Set-ExecutionPolicy -Scope Process Bypass` |
| Acentos o `ñ` corruptos | Codificación incorrecta | Usa `utf8mb4` y los scripts del proyecto |
| `mvnw: Permission denied` (macOS/Linux) | Falta permiso de ejecución | `chmod +x mvnw` |

---

## 10. Privacidad y alcance

VPlan es deliberadamente **local y sin autenticación**:

- Spring Boot escucha solo en `127.0.0.1:8080`.
- MySQL debe escuchar solo en `127.0.0.1:3306`.
- No hay sesiones, cookies de identidad ni CSRF que proteger.
- Las credenciales están en variables de entorno o en `.env.local`, ignorado por
  Git.
- Las copias de seguridad contienen datos personales: no las subas a GitHub ni a
  servicios públicos.
- No expongas el puerto 8080 a internet. Para publicar la aplicación harían falta
  autenticación, HTTPS y una revisión de seguridad.

### Estado verificado en este equipo (17/11/2026)

La aplicación escucha solo en `127.0.0.1:8080`. MySQL está configurado con
`bind-address=127.0.0.1` en `my.ini`, escucha únicamente en loopback y su
servicio `MySQL80` arranca automáticamente. La configuración cumple la
recomendación de la sección 3.

Si en otro equipo MySQL escucha en `::` o `0.0.0.0`, aplica el procedimiento de
[Privacidad: aceptar solo conexiones locales](#privacidad-aceptar-solo-conexiones-locales).

---

## 11. Para el currículum

VPlan demuestra:

- Backend Java 21 con Spring Boot 3.5, Spring MVC, Spring Data JPA y Bean
  Validation.
- MySQL 8 con migraciones versionadas mediante Flyway.
- API REST con validación, errores homogéneos y tests con JUnit 5, MockMvc y H2.
- Frontend responsive con HTML, CSS y JavaScript vanilla, sin dependencias
  externas.
- Configuración por variables de entorno, sin secretos en el repositorio.
- Detección portable del JDK, scripts de arranque/parada, copia y restauración, y
  documentación de instalación reproducible.
- Acceso directo de escritorio en modo aplicación y comprobaciones reales de
  persistencia, copia y restauración.
- Aplicación *local-first*: sin hosting, sin login y con los datos en tu equipo.

---

## Anexo: macOS y Linux

Los scripts `.ps1` son para Windows. En macOS o Linux se puede ejecutar el
proyecto igualmente con estos equivalentes manuales:

```bash
# Java 21+ y MySQL 8.0+ instalados con el gestor de paquetes del sistema
export JAVA_HOME="/ruta/al/jdk"
export VPLAN_DB_PASSWORD="la_contrasena_de_vplan_app"
chmod +x mvnw

./mvnw test
./mvnw spring-boot:run
```

Copia de seguridad manual:

```bash
mysqldump --host=127.0.0.1 --port=3306 --user=vplan_app \
  --single-transaction --no-tablespaces --skip-add-locks --skip-triggers \
  --set-gtid-purged=OFF --default-character-set=utf8mb4 \
  --result-file="backups/vplan.sql" vplan
```

Restauración (con la aplicación parada):

```bash
mysql --host=127.0.0.1 --port=3306 --user=vplan_app \
  --default-character-set=utf8mb4 vplan < backups/vplan.sql
```

La contraseña se pide de forma interactiva o se define en el entorno. `my.cnf`
debe contener `bind-address=127.0.0.1` en la sección `[mysqld]`.
