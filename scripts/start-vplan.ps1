# VPlan - Arranque de uso diario.
#
# Uso:
#     .\scripts\start-vplan.ps1
#     .\scripts\start-vplan.ps1 -NoBrowser
#     .\scripts\start-vplan.ps1 -TimeoutSeconds 120
#     .\scripts\start-vplan.ps1 -Foreground
#
# Que hace:
#   1. Carga el entorno de la sesion con set-dev-env.ps1 (JDK 21+ y .env.local).
#   2. Comprueba que MySQL responde en 127.0.0.1:3306.
#   3. Comprueba que el puerto 8080 esta libre o que ya lo usa VPlan.
#   4. Arranca mvnw spring-boot:run en segundo plano, con la salida en logs/.
#   5. Espera a que /api/health responda UP y abre el navegador.
#   6. Guarda los PID en logs/vplan.pid para que stop-vplan.ps1 los use.
#
# La contrasena nunca se imprime: set-dev-env.ps1 solo carga la variable.
#
# Si algo falla, muestra las ultimas lineas del log. En una ventana interactiva
# espera a que pulses Enter para que puedas leer el error.

[CmdletBinding()]
param(
    [switch]$NoBrowser,
    [int]$TimeoutSeconds = 90,
    [switch]$Foreground,
    [switch]$NoPause,
    [int]$OwnerPid = 0
)

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$mvnwPath = Join-Path $projectRoot "mvnw.cmd"
$logDirectory = Join-Path $projectRoot "logs"
$pidFile = Join-Path $logDirectory "vplan.pid"
$logPath = ""

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

function Get-VPlanHealth {
    try {
        return Invoke-RestMethod -Uri "http://127.0.0.1:8080/api/health" `
            -TimeoutSec 3 -ErrorAction Stop
    } catch {
        return $null
    }
}

function Test-VPlanTcpPort {
    param(
        [string]$HostName,
        [int]$Port,
        [int]$TimeoutMilliseconds = 1500
    )

    $client = New-Object System.Net.Sockets.TcpClient
    try {
        $task = $client.ConnectAsync($HostName, $Port)
        if (-not $task.Wait($TimeoutMilliseconds)) { return $false }
        return $client.Connected
    } catch {
        return $false
    } finally {
        $client.Dispose()
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

function Show-VPlanLogTail {
    if (-not $logPath -or -not (Test-Path -LiteralPath $logPath)) { return }

    Write-Host ""
    Write-Host "Ultimas lineas del log:" -ForegroundColor Yellow
    Get-Content -LiteralPath $logPath -Tail 25 -ErrorAction SilentlyContinue |
        ForEach-Object { Write-Host "  $_" }
}

function Open-VPlanBrowser {
    if ($NoBrowser) { return }

    # Preferir Chrome, que es el navegador indicado para VPlan. Si no esta
    # instalado, usar el navegador predeterminado del sistema.
    $chromeCandidates = @()
    if ($env:ProgramFiles) {
        $chromeCandidates += Join-Path $env:ProgramFiles "Google\Chrome\Application\chrome.exe"
    }
    if (${env:ProgramFiles(x86)}) {
        $chromeCandidates += Join-Path ${env:ProgramFiles(x86)} "Google\Chrome\Application\chrome.exe"
    }
    if ($env:LOCALAPPDATA) {
        $chromeCandidates += Join-Path $env:LOCALAPPDATA "Google\Chrome\Application\chrome.exe"
    }
    $chrome = $chromeCandidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1

    try {
        if ($chrome) {
            Start-Process -FilePath $chrome -ArgumentList "http://localhost:8080" | Out-Null
        } else {
            Start-Process "http://localhost:8080" | Out-Null
        }
    } catch {
        Write-Host "  No se pudo abrir el navegador automaticamente." -ForegroundColor Yellow
        Write-Host "  Abre http://localhost:8080 a mano."
    }
}

$launcher = $null
$appPid = 0

try {
    if (-not (Test-Path -LiteralPath $mvnwPath)) {
        throw "No se encuentra mvnw.cmd en '$projectRoot'."
    }

    Write-Host ""
    Write-Host "VPlan - arranque" -ForegroundColor Cyan
    Write-Host "  Proyecto: $projectRoot"

    # set-dev-env.ps1 solo cambia esta sesion. El proceso hijo hereda JAVA_HOME,
    # PATH y VPLAN_DB_PASSWORD. La salida se silencia para no repetir el banner.
    $envScript = Join-Path $PSScriptRoot "set-dev-env.ps1"
    if (-not (Test-Path -LiteralPath $envScript)) {
        throw "No se encuentra scripts\set-dev-env.ps1."
    }
    . $envScript *> $null

    if (-not $env:VPLAN_DB_PASSWORD) {
        throw "Falta VPLAN_DB_PASSWORD. Ejecuta .\scripts\set-db-password.ps1 y vuelve a intentarlo."
    }

    $javac = Get-Command "javac.exe" -ErrorAction SilentlyContinue
    if (-not $javac) {
        throw "No se encuentra javac.exe. Instala un JDK 21 o superior."
    }
    $javacVersion = (& $javac.Source -version 2>&1 | Out-String).Trim()
    if ($javacVersion -notmatch "javac\s+(?:1\.)?(\d+)") {
        throw "No se pudo determinar la version de Java: $javacVersion"
    }
    $javaMajor = [int]$Matches[1]
    if ($javaMajor -lt 21) {
        throw "Java $javaMajor es demasiado antiguo. VPlan necesita JDK 21 o superior."
    }
    Write-Host "  Java    : $javacVersion"

    if (-not (Test-VPlanTcpPort -HostName "127.0.0.1" -Port 3306)) {
        throw "MySQL no responde en 127.0.0.1:3306. Comprueba el servicio: Get-Service MySQL80"
    }
    Write-Host "  MySQL   : 127.0.0.1:3306 responde"

    $listener = Get-VPlanListener
    if ($listener) {
        $existing = Get-VPlanProcessInfo -ProcessId ([int]$listener.OwningProcess)
        if (Test-VPlanProcess -Info $existing) {
            Write-Host "  VPlan ya esta en marcha (PID $($existing.Id))." -ForegroundColor Yellow

            $deadlineExisting = (Get-Date).AddSeconds(15)
            $healthExisting = $null
            while ((Get-Date) -lt $deadlineExisting) {
                $healthExisting = Get-VPlanHealth
                if ($healthExisting -and $healthExisting.status -eq "UP" -and $healthExisting.database -eq "UP") {
                    break
                }
                Start-Sleep -Milliseconds 750
            }

            if ($healthExisting -and $healthExisting.status -eq "UP" -and $healthExisting.database -eq "UP") {
                if (-not $NoBrowser) {
                    Write-Host "  Abriendo http://localhost:8080" -ForegroundColor Green
                }
                Open-VPlanBrowser
                exit 0
            }

            throw "VPlan esta en marcha, pero /api/health no responde UP. Revisa el proceso o usa stop-vplan.ps1."
        }

        $name = if ($existing) { $existing.Name } else { "desconocido" }
        throw "El puerto 8080 esta ocupado por el proceso PID $($listener.OwningProcess) ($name). VPlan no lo tocara."
    }

    if ($Foreground) {
        Write-Host "  Modo primer plano: la salida de Maven se muestra en esta consola." -ForegroundColor Yellow
        Write-Host "  Para parar: Ctrl + C. Para el modo normal, ejecuta el script sin -Foreground."
        Write-Host ""
        & $mvnwPath spring-boot:run
        exit $LASTEXITCODE
    }

    if (-not (Test-Path -LiteralPath $logDirectory)) {
        New-Item -ItemType Directory -Force -Path $logDirectory | Out-Null
    }

    $stamp = Get-Date -Format "yyyy-MM-dd_HHmmss"
    $logPath = Join-Path $logDirectory "vplan-$stamp.log"
    $wrapperPath = Join-Path $logDirectory "vplan-launch.cmd"

    # Un wrapper .cmd evita problemas de comillas de Start-Process con rutas que
    # contienen espacios. La salida completa de Maven y de Spring queda en el log.
    $wrapper = @"
@echo off
cd /d "$projectRoot"
call "$mvnwPath" spring-boot:run > "$logPath" 2>&1
"@
    Set-Content -LiteralPath $wrapperPath -Value $wrapper -Encoding ASCII

    Write-Host "  Log     : $logPath"
    Write-Host "  Arrancando Spring Boot..."
    $launcher = Start-Process -FilePath $wrapperPath -WorkingDirectory $projectRoot `
        -WindowStyle Hidden -PassThru

    $deadline = (Get-Date).AddSeconds([Math]::Max(10, $TimeoutSeconds))
    $health = $null
    while ((Get-Date) -lt $deadline) {
        if ($launcher.HasExited) { break }

        $health = Get-VPlanHealth
        if ($health -and $health.status -eq "UP" -and $health.database -eq "UP") {
            break
        }
        Start-Sleep -Milliseconds 1000
    }

    if (-not $health -or $health.status -ne "UP" -or $health.database -ne "UP") {
        Show-VPlanLogTail
        throw "VPlan no ha respondido UP en $TimeoutSeconds segundos. Revisa el log: $logPath"
    }

    $listener = Get-VPlanListener
    if ($listener) {
        $appPid = [int]$listener.OwningProcess
    }

    $pidLines = @(
        "LauncherPid=$($launcher.Id)"
        "AppPid=$appPid"
        "Started=$((Get-Date).ToString('s'))"
        "Log=$logPath"
    )
    if ($OwnerPid -gt 0) {
        $pidLines += "OwnerPid=$OwnerPid"
    }
    [System.IO.File]::WriteAllText(
        $pidFile,
        (($pidLines -join "`r`n") + "`r`n"),
        (New-Object System.Text.UTF8Encoding($false))
    )

    Write-Host ""
    Write-Host "VPlan iniciado" -ForegroundColor Green
    Write-Host "  URL    : http://localhost:8080"
    Write-Host "  PID    : $appPid"
    Write-Host "  Log    : $logPath"
    Write-Host "  Parar  : .\scripts\stop-vplan.ps1"
    Write-Host ""
    Write-Host "  Health :"
    $health | ConvertTo-Json -Compress | ForEach-Object { Write-Host "    $_" }

    Open-VPlanBrowser
    exit 0
} catch {
    Write-VPlanError $_.Exception.Message
    Show-VPlanLogTail

    if ($appPid -gt 0) {
        try { Stop-Process -Id $appPid -Force -ErrorAction SilentlyContinue } catch { }
    }

    $listener = Get-VPlanListener
    if ($listener) {
        $remaining = Get-VPlanProcessInfo -ProcessId ([int]$listener.OwningProcess)
        if (Test-VPlanProcess -Info $remaining) {
            try { Stop-Process -Id $remaining.Id -Force -ErrorAction SilentlyContinue } catch { }
        }
    }

    if ($launcher -and -not $launcher.HasExited) {
        try {
            & taskkill.exe /PID $launcher.Id /T /F 2>$null | Out-Null
        } catch { }
    }

    if (Test-Path -LiteralPath $pidFile) {
        Remove-Item -LiteralPath $pidFile -Force -ErrorAction SilentlyContinue
    }

    Wait-VPlanExit
    exit 1
}
