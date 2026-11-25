# VPlan - Parada de uso diario.
#
# Uso:
#     .\scripts\stop-vplan.ps1
#     .\scripts\stop-vplan.ps1 -Force
#
# Que hace:
#   1. Busca el proceso que escucha en el puerto 8080 y lee logs/vplan.pid.
#   2. Comprueba que el proceso es realmente VPlan.
#   3. Intenta un cierre ordenado y, si no termina, fuerza el proceso de VPlan.
#   4. Detiene tambien el lanzador de Maven para no dejar procesos abiertos.
#   5. Comprueba que el puerto 8080 queda libre y borra el archivo de PID.
#
# Seguridad:
#   - Nunca detiene un proceso ajeno si no se pasa -Force.
#   - Con -Force se usa solo cuando la persona esta segura de que el proceso es
#     VPlan o de que quiere liberar el puerto.
#
# Si VPlan se arranco a mano con "mvnw spring-boot:run", este script puede
# detener la aplicacion, pero la ventana de Maven debe cerrarse a mano.

[CmdletBinding()]
param(
    [int]$TimeoutSeconds = 20,
    [switch]$Force,
    [switch]$NoPause
)

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$pidFile = Join-Path (Join-Path $projectRoot "logs") "vplan.pid"

function Write-VPlanError {
    param([string]$Message)
    Write-Host ""
    Write-Host "ERROR: $Message" -ForegroundColor Red
}

function Wait-VPlanExit {
    if (-not $NoPause -and $Host.Name -eq "ConsoleHost") {
        try {
            Read-Host "Pulsa Enter para cerrar" | Out-Null
        } catch {
            # Sin consola interactiva: no bloquear.
        }
    }
}

function Get-VPlanListener {
    return Get-NetTCPConnection -State Listen -LocalPort 8080 `
        -ErrorAction SilentlyContinue | Select-Object -First 1
}

function Get-VPlanProcessInfo {
    param([int]$ProcessId)

    if (-not $ProcessId) { return $null }

    $process = Get-Process -Id $ProcessId -ErrorAction SilentlyContinue
    if (-not $process) { return $null }

    $cim = Get-CimInstance Win32_Process -Filter "ProcessId = $ProcessId" `
        -ErrorAction SilentlyContinue

    return [pscustomobject]@{
        Id          = $ProcessId
        Name        = $process.ProcessName
        CommandLine = if ($cim) { [string]$cim.CommandLine } else { "" }
    }
}

function Test-VPlanProcess {
    param($Info)

    if (-not $Info) { return $false }

    $name = [string]$Info.Name
    $commandLine = [string]$Info.CommandLine

    if ($name -notmatch "^(java|javaw)$") { return $false }
    return $commandLine -match "(?i)(vplan|com\.vplan)"
}

function Read-VPlanPidFile {
    if (-not (Test-Path -LiteralPath $pidFile)) { return $null }

    $values = @{}
    foreach ($line in Get-Content -LiteralPath $pidFile -Encoding UTF8 -ErrorAction SilentlyContinue) {
        if ($line -match "^\s*([A-Za-z]+)\s*=\s*(.*)\s*$") {
            $values[$Matches[1]] = $Matches[2].Trim()
        }
    }

    $launcherPid = 0
    $appPid = 0
    if ($values.ContainsKey("LauncherPid")) {
        [void][int]::TryParse($values["LauncherPid"], [ref]$launcherPid)
    }
    if ($values.ContainsKey("AppPid")) {
        [void][int]::TryParse($values["AppPid"], [ref]$appPid)
    }

    return [pscustomobject]@{
        LauncherPid = $launcherPid
        AppPid      = $appPid
        Log         = if ($values.ContainsKey("Log")) { $values["Log"] } else { "" }
    }
}

function Stop-VPlanProcessTree {
    param([int]$ProcessId)

    if (-not $ProcessId) { return }

    # Primer intento: sin /F. En una consola Java normalmente no basta, pero no
    # hace dano intentarlo antes de forzar.
    try {
        & taskkill.exe /PID $ProcessId /T 2>$null | Out-Null
    } catch { }

    $deadline = (Get-Date).AddSeconds(5)
    while ((Get-Date) -lt $deadline) {
        if (-not (Get-Process -Id $ProcessId -ErrorAction SilentlyContinue)) {
            return
        }
        Start-Sleep -Milliseconds 400
    }

    try {
        & taskkill.exe /PID $ProcessId /T /F 2>$null | Out-Null
    } catch { }
}

$appPid = 0
$launcherPid = 0

try {
    Write-Host ""
    Write-Host "VPlan - parada" -ForegroundColor Cyan

    $pidInfo = Read-VPlanPidFile
    if ($pidInfo) {
        $appPid = [int]$pidInfo.AppPid
        $launcherPid = [int]$pidInfo.LauncherPid
    }

    $listener = Get-VPlanListener
    if ($listener) {
        $appPid = [int]$listener.OwningProcess
    }

    if (-not $appPid -or -not (Get-Process -Id $appPid -ErrorAction SilentlyContinue)) {
        # La aplicacion no esta escuchando. Puede quedar el lanzador de Maven.
        if ($launcherPid -and (Get-Process -Id $launcherPid -ErrorAction SilentlyContinue)) {
            Write-Host "  Deteniendo restos del lanzador de Maven (PID $launcherPid)..."
            Stop-VPlanProcessTree -ProcessId $launcherPid
        }

        if (Test-Path -LiteralPath $pidFile) {
            Remove-Item -LiteralPath $pidFile -Force -ErrorAction SilentlyContinue
        }

        Write-Host "  VPlan no esta en marcha. El puerto 8080 esta libre." -ForegroundColor Green
        exit 0
    }

    $details = Get-VPlanProcessInfo -ProcessId $appPid
    if (-not $details) {
        throw "El PID $appPid ya no existe."
    }

    $isVPlan = Test-VPlanProcess -Info $details
    if (-not $isVPlan) {
        $description = "$($details.Name) (PID $appPid)"
        if (-not $Force) {
            throw "El puerto 8080 lo ocupa $description, que no parece VPlan. No se ha detenido nada. Si estas seguro, repite con -Force."
        }
        Write-Host "  AVISO: el proceso $description no se ha podido verificar como VPlan." -ForegroundColor Yellow
        Write-Host "  -Force autoriza a detenerlo de todos modos." -ForegroundColor Yellow
    }

    Write-Host "  Deteniendo VPlan (PID $appPid, $($details.Name))..."
    Stop-VPlanProcessTree -ProcessId $appPid

    $deadline = (Get-Date).AddSeconds([Math]::Max(5, $TimeoutSeconds))
    while ((Get-Date) -lt $deadline) {
        if (-not (Get-VPlanListener)) { break }
        Start-Sleep -Milliseconds 500
    }

    if ($launcherPid -and $launcherPid -ne $appPid -and (Get-Process -Id $launcherPid -ErrorAction SilentlyContinue)) {
        Write-Host "  Deteniendo el lanzador de Maven (PID $launcherPid)..."
        Stop-VPlanProcessTree -ProcessId $launcherPid
    }

    # Red de seguridad: solo procesos Java que pertenezcan a esta carpeta.
    $remaining = Get-CimInstance Win32_Process -Filter "Name = 'java.exe'" -ErrorAction SilentlyContinue |
        Where-Object {
            $_.CommandLine -and
            $_.CommandLine.IndexOf($projectRoot, [System.StringComparison]::OrdinalIgnoreCase) -ge 0
        }
    foreach ($process in @($remaining)) {
        if ($process -and $process.ProcessId) {
            Write-Host "  Deteniendo proceso Java restante (PID $($process.ProcessId))..."
            try { Stop-Process -Id ([int]$process.ProcessId) -Force -ErrorAction SilentlyContinue } catch { }
        }
    }

    if (Test-Path -LiteralPath $pidFile) {
        Remove-Item -LiteralPath $pidFile -Force -ErrorAction SilentlyContinue
    }

    if (Get-VPlanListener) {
        throw "El puerto 8080 sigue ocupado. Revisa el proceso con Get-NetTCPConnection -LocalPort 8080."
    }

    Write-Host ""
    Write-Host "VPlan detenido. El puerto 8080 esta libre." -ForegroundColor Green
    exit 0
} catch {
    Write-VPlanError $_.Exception.Message
    Wait-VPlanExit
    exit 1
}
