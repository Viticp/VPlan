# Entorno, Java y Maven Wrapper

## 1. Por qué el script busca el JDK

En un equipo puede haber varias instalaciones de Java, y la que responde a `java`
puede ser antigua. Es habitual encontrar Java 8 en el `PATH` y un JDK 11 en
`JAVA_HOME`, aunque haya un JDK 21 o 25 instalado aparte.

Spring Boot 3.5 exige **Java 17 o superior** y VPlan compila para Java 21, así
que necesita un **JDK 21 o superior**. Para no depender de una ruta concreta, el
script prueba candidatos en este orden y se queda con el primero que sea válido:

1. El parámetro `-JavaHome`.
2. La variable `VPLAN_JAVA_HOME`.
3. La variable `JAVA_HOME`.
4. `javac.exe` disponible en el `PATH`.
5. Las rutas habituales de instalación de Windows (Adoptium, Java, Microsoft,
   Corretto, Zulu, BellSoft y el JDK que incluye NetBeans).

Si un candidato existe pero es anterior a Java 21, se descarta y se sigue
buscando. Si ninguno sirve, el script se detiene con un mensaje que indica qué
versiones se descartaron y cómo pasar una ruta.

## 2. Java 21 de destino, JDK 25 de ejecución

En `pom.xml`:

```xml
<java.version>21</java.version>
```

Maven compila con `--release 21`: el `.class` resultante funciona en cualquier
JVM 21 o superior. Se puede ejecutar tanto en un JDK 21 LTS como en uno más
moderno, sin cambiar el `pom.xml`.

## 3. El script de entorno

```powershell
. .\scripts\set-dev-env.ps1
```

El **punto inicial** es obligatorio: hace que el script se ejecute en la sesión
actual en lugar de en un proceso hijo. Si se ejecuta sin el punto, los cambios se
pierden al terminar.

Si el JDK está en otra ruta: `. .\scripts\set-dev-env.ps1 -JavaHome "C:\ruta\al\jdk"`.

Qué hace:

1. Busca un JDK 21 o superior en el orden explicado arriba.
2. Asigna `JAVA_HOME` **solo a esta ventana**.
3. Añade `bin` del JDK al principio del `PATH`, sin duplicarlo si ya está.
4. Carga `.env.local` con UTF-8 explícito, sin sobrescribir variables que ya
   existan en la sesión.
5. Muestra la versión de Java y avisa si falta `VPLAN_DB_PASSWORD`.

No toca el Registro de Windows, ni las variables de entorno del usuario, ni las
del sistema. Al cerrar PowerShell, todo vuelve a su estado anterior.

## 4. Por qué Maven Wrapper

Maven no está instalado. El wrapper (`mvnw.cmd`) es un lanzador pequeño incluido en
el repositorio que:

1. Lee `.mvn/wrapper/maven-wrapper.properties`.
2. Descarga Maven 3.9.16 en `%USERPROFILE%\.m2\wrapper\dists` la primera vez.
3. Ejecuta Maven con la versión exacta del proyecto.

Ventajas:

- Cualquiera que clone el repositorio usa la misma versión de Maven.
- No hace falta instalar nada globalmente.
- No depende de la versión de Maven que tenga el equipo.

Requisito: `JAVA_HOME` debe apuntar a un JDK válido (lo hace el script).

## 5. Variables de entorno del proyecto

| Variable | Obligatoria | Valor por defecto | Para qué |
|---|---|---|---|
| `JAVA_HOME` | Sí | — | JDK usado por Maven |
| `VPLAN_DB_PASSWORD` | Sí | — | Contraseña de `vplan_app` |
| `VPLAN_DB_USER` | No | `vplan_app` | Usuario de MySQL |
| `VPLAN_DB_URL` | No | `jdbc:mysql://127.0.0.1:3306/vplan...` | URL JDBC |

`VPLAN_DB_PASSWORD` no tiene valor por defecto a propósito: si falta, la
aplicación falla al arrancar con un error claro, en lugar de intentar conectarse
con una contraseña vacía.

## 6. Comandos útiles

```powershell
# Cargar entorno
. .\scripts\set-dev-env.ps1
$env:VPLAN_DB_PASSWORD = "..."

# Versión de Maven y Java que se están usando
.\mvnw.cmd -v

# Compilar sin tests
.\mvnw.cmd -DskipTests package

# Arrancar (Fase 3 en adelante)
.\mvnw.cmd spring-boot:run

# Tests
.\mvnw.cmd test
```

## 7. Qué hacer si cambia el JDK

El script admite una ruta distinta sin editar el archivo:

```powershell
. .\scripts\set-dev-env.ps1 -JavaHome "C:\ruta\al\jdk"
```

o, para no repetirla:

```powershell
$env:VPLAN_JAVA_HOME = "C:\ruta\al\jdk"
. .\scripts\set-dev-env.ps1
```

El script comprueba que existe `javac.exe` y que la versión es **21 o superior**;
si no, se detiene con un mensaje claro. No hay ninguna ruta fija en el código: si
un candidato no sirve, continúa con el siguiente.

Si en el futuro se instala un JDK propio, basta con apuntar `$JavaHome` a esa ruta
o definir `VPLAN_JAVA_HOME`.
