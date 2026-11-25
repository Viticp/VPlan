# VPlan - Entorno de desarrollo SOLO para la sesion actual de PowerShell.
#
# Uso (importante: el punto inicial hace que los cambios afecten a TU sesion):
#     . .\scripts\set-dev-env.ps1
#
# Ruta de JDK personalizada (opcional):
#     . .\scripts\set-dev-env.ps1 -JavaHome "C:\ruta\al\jdk"
#     o define VPLAN_JAVA_HOME antes de ejecutarlo.
#
# Busqueda del JDK: se usa el primero que sea 21 o superior.
#   1. Parametro -JavaHome
#   2. Variable VPLAN_JAVA_HOME
#   3. Variable JAVA_HOME
#   4. javac.exe disponible en el PATH
#   5. Rutas habituales de instalacion en Windows
#
# Este script NO modifica variables de entorno del sistema ni del usuario.
# Cuando cierres la ventana de PowerShell, todo vuelve a como estaba.

param(
    [string]$JavaHome = ""
)

$jdk = & {
    function Get-VPlanJdkInfo {
        param([string]$Path)

        if (-not $Path) { return $null }

        $clean = $Path.Trim().Trim('"')
        $javac = Join-Path $clean "bin\javac.exe"
        if (-not (Test-Path -LiteralPath $javac)) { return $null }

        $raw = (& $javac -version 2>&1 | Out-String).Trim()
        $major = 0
        if ($raw -match "javac\s+1\.(\d+)") {
            $major = [int]$Matches[1]
        } elseif ($raw -match "javac\s+(\d+)") {
            $major = [int]$Matches[1]
        }
        if ($major -lt 1) { return $null }

        return [pscustomobject]@{
            Path    = $clean
            Version = $raw
            Major   = $major
        }
    }

    $seen = @{}
    $candidates = New-Object System.Collections.Generic.List[string]

    function Add-VPlanCandidate {
        param([string]$Path)

        if (-not $Path) { return }
        try {
            $full = [System.IO.Path]::GetFullPath($Path).TrimEnd('\')
        } catch {
            return
        }
        if (-not $seen.ContainsKey($full)) {
            $seen[$full] = $true
            $candidates.Add($full)
        }
    }

    Add-VPlanCandidate $JavaHome
    Add-VPlanCandidate $env:VPLAN_JAVA_HOME
    Add-VPlanCandidate $env:JAVA_HOME

    $javacOnPath = Get-Command "javac.exe" -ErrorAction SilentlyContinue
    if ($javacOnPath) {
        Add-VPlanCandidate (Split-Path -Parent (Split-Path -Parent $javacOnPath.Source))
    }

    # Rutas habituales de instalacion. No son un requisito: solo se usan si
    # existen y ninguna de las opciones anteriores ha servido.
    function Join-VPlanPath {
        param([string]$Base, [string]$Child)
        if (-not $Base) { return "" }
        return (Join-Path $Base $Child)
    }

    $installRoots = @(
        (Join-VPlanPath $env:ProgramFiles "Eclipse Adoptium"),
        (Join-VPlanPath $env:ProgramFiles "Java"),
        (Join-VPlanPath $env:ProgramFiles "Microsoft"),
        (Join-VPlanPath $env:ProgramFiles "Amazon Corretto"),
        (Join-VPlanPath $env:ProgramFiles "Zulu"),
        (Join-VPlanPath $env:ProgramFiles "BellSoft"),
        (Join-VPlanPath $env:LOCALAPPDATA "Programs\Eclipse Adoptium")
    )
    foreach ($root in $installRoots) {
        if (-not $root -or -not (Test-Path -LiteralPath $root)) { continue }
        $directories = Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue |
            Sort-Object Name -Descending
        foreach ($directory in $directories) {
            Add-VPlanCandidate $directory.FullName
        }
    }

    # NetBeans incluye un JDK en esta ruta habitual. No es un requisito.
    Add-VPlanCandidate (Join-VPlanPath $env:ProgramFiles "Apache NetBeans\jdk")

    $rejected = @()
    $selected = $null
    foreach ($candidate in $candidates) {
        $info = Get-VPlanJdkInfo -Path $candidate
        if (-not $info) { continue }
        if ($info.Major -lt 21) {
            $rejected += $info
            continue
        }
        $selected = $info
        break
    }

    if (-not $selected) {
        $message = "No se ha encontrado un JDK 21 o superior.`n`nBusqueda realizada:`n  1. Parametro -JavaHome`n  2. Variable VPLAN_JAVA_HOME`n  3. Variable JAVA_HOME`n  4. javac.exe en el PATH`n  5. Rutas habituales de instalacion en Windows`n"

        if ($rejected.Count -gt 0) {
            $message += "`nSe descartaron por ser anteriores a Java 21:`n"
            foreach ($item in $rejected) {
                $message += "  - $($item.Path) ($($item.Version))`n"
            }
        }

        $message += "`nInstala un JDK 21 o superior (por ejemplo Temurin 21 LTS) o indica la ruta:`n    . .\scripts\set-dev-env.ps1 -JavaHome ""C:\ruta\al\jdk""`n"
        throw $message
    }

    $selected
}

$env:JAVA_HOME = $jdk.Path

# Evita duplicar la ruta si el script se ejecuta varias veces.
$javaBin = Join-Path $jdk.Path "bin"
$pathParts = $env:PATH -split ";"
if ($pathParts -notcontains $javaBin) {
    $env:PATH = "$javaBin;$env:PATH"
}

# Carga .env.local (ignorado por Git) sin mostrar nunca sus valores.
# Solo define variables que no esten ya en la sesion.
# UTF-8 explicito: la contrasena puede contener caracteres no ASCII.
$projectRoot = Split-Path -Parent $PSScriptRoot
$envFile = Join-Path $projectRoot ".env.local"
$envLoaded = 0
if (Test-Path -LiteralPath $envFile) {
    foreach ($line in Get-Content -LiteralPath $envFile -Encoding UTF8) {
        $trimmed = $line.Trim()
        if (-not $trimmed -or $trimmed.StartsWith("#")) { continue }

        $separator = $trimmed.IndexOf("=")
        if ($separator -lt 1) { continue }

        $name = $trimmed.Substring(0, $separator).Trim()
        $value = $trimmed.Substring($separator + 1).Trim()

        $isDoubleQuoted = $value.Length -ge 2 -and $value.StartsWith('"') -and $value.EndsWith('"')
        $isSingleQuoted = $value.Length -ge 2 -and $value.StartsWith("'") -and $value.EndsWith("'")
        if ($isDoubleQuoted -or $isSingleQuoted) {
            $value = $value.Substring(1, $value.Length - 2)
        }

        if ($name -match "^[A-Za-z_][A-Za-z0-9_]*$" -and -not (Test-Path "Env:$name")) {
            Set-Item -Path "Env:$name" -Value $value
            $envLoaded++
        }
    }
}

$javacVersion = $jdk.Version -replace "^javac\s+", ""

Write-Host ""
Write-Host "Entorno VPlan cargado (solo esta sesion)" -ForegroundColor Green
Write-Host "  JAVA_HOME = $env:JAVA_HOME"
Write-Host "  javac     = $javacVersion"
Write-Host "  Maven     = .\mvnw.cmd (Maven Wrapper)"
if (Test-Path -LiteralPath $envFile) {
    Write-Host "  .env.local = cargado ($envLoaded variables)"
}
Write-Host ""

# cmd /c evita el ruido de PowerShell 5.1 con la salida de error de "java -version".
& cmd /c "java -version 2>&1" | ForEach-Object { Write-Host "  $_" }

if (-not $env:VPLAN_DB_PASSWORD) {
    Write-Host ""
    Write-Host "AVISO: VPLAN_DB_PASSWORD no esta definida." -ForegroundColor Yellow
    Write-Host '  Ejecuta: $env:VPLAN_DB_PASSWORD = "la_contrasena_de_vplan_app"'
    Write-Host "  Sin ella, la aplicacion no podra conectarse a MySQL."
}
