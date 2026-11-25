# VPlan - Arranque en modo aplicacion de escritorio.
#
# Lo invoca el acceso directo "VPlan".
#
# 1. Reutiliza start-vplan.ps1 para arrancar o detectar VPlan.
# 2. Abre Chrome en modo --app con un perfil dedicado y espera a que se cierre.
# 3. Solo detiene el servidor si lo arranco este mismo lanzador.
#
# No cierra Chrome entero ni toca otras ventanas o procesos de Chrome.

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$logDirectory = Join-Path $projectRoot "logs"
$pidFile = Join-Path $logDirectory "vplan.pid"
$appPidFile = Join-Path $logDirectory "vplan-app.pid"
$lockFile = Join-Path $logDirectory "vplan-app.lock"
$appLog = Join-Path $logDirectory "vplan-app.log"
$chromeProfile = Join-Path $logDirectory "vplan-chrome-profile"
$startScript = Join-Path $PSScriptRoot "start-vplan.ps1"
$stopScript = Join-Path $PSScriptRoot "stop-vplan.ps1"
$powershell = Join-Path $env:SystemRoot "System32\WindowsPowerShell\v1.0\powershell.exe"

$lockAcquired = $false

function Write-AppLog {
    param([string]$Message)

    try {
        if (-not (Test-Path -LiteralPath $logDirectory)) {
            New-Item -ItemType Directory -Force -Path $logDirectory | Out-Null
        }
        Add-Content -LiteralPath $appLog -Encoding UTF8 `
            -Value "$((Get-Date).ToString('s')) $Message"
    } catch { }
}

function Show-AppError {
    param([string]$Message)

    Write-AppLog "ERROR: $Message"
    try {
        $wshell = New-Object -ComObject WScript.Shell
        $wshell.Popup($Message, 0, "VPlan", 16) | Out-Null
    } catch {
        Write-Host "ERROR: $Message" -ForegroundColor Red
    }
}

function Get-ChromePath {
    $candidates = @()
    if ($env:ProgramFiles) {
        $candidates += Join-Path $env:ProgramFiles "Google\Chrome\Application\chrome.exe"
    }
    if (${env:ProgramFiles(x86)}) {
        $candidates += Join-Path ${env:ProgramFiles(x86)} "Google\Chrome\Application\chrome.exe"
    }
    if ($env:LOCALAPPDATA) {
        $candidates += Join-Path $env:LOCALAPPDATA "Google\Chrome\Application\chrome.exe"
    }
    return $candidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
}

function Read-KeyValueFile {
    param([string]$Path)

    $values = @{}
    if (-not (Test-Path -LiteralPath $Path)) { return $values }

    foreach ($line in Get-Content -LiteralPath $Path -Encoding UTF8 -ErrorAction SilentlyContinue) {
        if ($line -match "^\s*([A-Za-z]+)\s*=\s*(.*)\s*$") {
            $values[$Matches[1]] = $Matches[2].Trim()
        }
    }
    return $values
}

function Get-VPlanHealth {
    try {
        return Invoke-RestMethod -Uri "http://127.0.0.1:8080/api/health" `
            -TimeoutSec 3 -ErrorAction Stop
    } catch {
        return $null
    }
}

function Get-VPlanChromeProcess {
    # Solo el proceso principal de Chrome con el perfil dedicado de VPlan.
    $cim = Get-CimInstance Win32_Process -Filter "Name = 'chrome.exe'" `
        -ErrorAction SilentlyContinue |
        Where-Object {
            $_.CommandLine -and
            ($_.CommandLine.IndexOf($chromeProfile, [System.StringComparison]::OrdinalIgnoreCase) -ge 0 -or
             $_.CommandLine -match "vplan-chrome-profile") -and
            $_.CommandLine -notmatch "--type="
        } | Select-Object -First 1

    if (-not $cim) { return $null }
    return Get-Process -Id $cim.ProcessId -ErrorAction SilentlyContinue
}

function Exit-App {
    param([int]$Code)

    if ($script:lockAcquired) {
        Remove-Item -LiteralPath $lockFile -Force -ErrorAction SilentlyContinue
        $script:lockAcquired = $false
    }
    exit $Code
}

try {
    if (-not (Test-Path -LiteralPath $startScript)) {
        throw "No se encuentra scripts\start-vplan.ps1."
    }
    if (-not (Test-Path -LiteralPath $stopScript)) {
        throw "No se encuentra scripts\stop-vplan.ps1."
    }

    $chrome = Get-ChromePath
    if (-not $chrome) {
        throw "No se ha encontrado Google Chrome. Instalalo o usa .\scripts\start-vplan.ps1."
    }

    if (-not (Test-Path -LiteralPath $logDirectory)) {
        New-Item -ItemType Directory -Force -Path $logDirectory | Out-Null
    }

    Write-AppLog "Inicio del lanzador VPlan."

    # Si ya hay una ventana VPlan abierta, solo traerla al frente.
    $existingChrome = Get-VPlanChromeProcess
    if ($existingChrome) {
        Write-AppLog "Ya hay una ventana VPlan abierta (Chrome PID $($existingChrome.Id))."
        try {
            $wshell = New-Object -ComObject WScript.Shell
            $wshell.AppActivate($existingChrome.Id) | Out-Null
        } catch { }
        Exit-App 0
    }

    # Evitar dos lanzadores simultaneos mientras el primero arranca Spring Boot.
    if (Test-Path -LiteralPath $lockFile) {
        $lockInfo = Read-KeyValueFile -Path $lockFile
        $lockPid = 0
        if ($lockInfo.ContainsKey("Pid")) {
            [void][int]::TryParse($lockInfo["Pid"], [ref]$lockPid)
        }

        if ($lockPid -gt 0) {
            $lockCim = Get-CimInstance Win32_Process -Filter "ProcessId = $lockPid" `
                -ErrorAction SilentlyContinue
            if ($lockCim -and $lockCim.CommandLine -match "start-vplan-app\.ps1") {
                Write-AppLog "Otro lanzador VPlan esta en marcha (PID $lockPid). No se inicia otra instancia."
                Exit-App 0
            }
        }

        Remove-Item -LiteralPath $lockFile -Force -ErrorAction SilentlyContinue
    }

    [System.IO.File]::WriteAllText(
        $lockFile,
        "Pid=$PID`r`nStarted=$((Get-Date).ToString('s'))`r`n",
        (New-Object System.Text.UTF8Encoding($false))
    )
    $script:lockAcquired = $true

    $healthBefore = Get-VPlanHealth
    $wasRunning = $healthBefore -and $healthBefore.status -eq "UP" -and $healthBefore.database -eq "UP"
    Write-AppLog "VPlan ya estaba en marcha antes del lanzador: $wasRunning"

    # Reutiliza toda la logica de arranque existente, sin abrir el navegador.
    & $powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden `
        -File $startScript -NoBrowser -NoPause -OwnerPid $PID
    $startExit = $LASTEXITCODE
    if ($startExit -ne 0) {
        throw "No se pudo arrancar VPlan (codigo $startExit). Revisa logs\vplan-*.log."
    }

    $healthAfter = Get-VPlanHealth
    if (-not $healthAfter -or $healthAfter.status -ne "UP" -or $healthAfter.database -ne "UP") {
        throw "VPlan no responde UP despues del arranque."
    }

    $pidInfo = Read-KeyValueFile -Path $pidFile
    $appPid = 0
    $launcherPid = 0
    $ownerPid = 0
    if ($pidInfo.ContainsKey("AppPid")) { [void][int]::TryParse($pidInfo["AppPid"], [ref]$appPid) }
    if ($pidInfo.ContainsKey("LauncherPid")) { [void][int]::TryParse($pidInfo["LauncherPid"], [ref]$launcherPid) }
    if ($pidInfo.ContainsKey("OwnerPid")) { [void][int]::TryParse($pidInfo["OwnerPid"], [ref]$ownerPid) }

    # Solo se detiene al cerrar si este lanzador arranco el servidor.
    $startedByMe = (-not $wasRunning) -and ($ownerPid -eq $PID)
    Write-AppLog "AppPid=$appPid LauncherPid=$launcherPid OwnerPid=$ownerPid StartedByMe=$startedByMe"

    $chromeArgs = @(
        "--app=http://localhost:8080",
        "--user-data-dir=`"$chromeProfile`"",
        "--no-first-run",
        "--no-default-browser-check",
        "--disable-background-mode",
        "--disable-session-crashed-bubble",
        "--hide-crash-restore-bubble"
    ) -join " "

    Write-AppLog "Lanzando Chrome en modo aplicacion."
    $chromeProc = Start-Process -FilePath $chrome -ArgumentList $chromeArgs -PassThru

    # Si Chrome delega en una instancia ya existente de este perfil, localizarla.
    Start-Sleep -Milliseconds 1500
    if ($chromeProc.HasExited) {
        $realChrome = Get-VPlanChromeProcess
        if (-not $realChrome) {
            throw "Chrome se cerro inmediatamente y no se encontro la ventana de VPlan."
        }
        $chromeProc = $realChrome
    }

    [System.IO.File]::WriteAllText(
        $appPidFile,
        "ChromePid=$($chromeProc.Id)`r`nAppPid=$appPid`r`nOwnerPid=$PID`r`n",
        (New-Object System.Text.UTF8Encoding($false))
    )

    Write-AppLog "Ventana VPlan abierta (Chrome PID $($chromeProc.Id)). Esperando su cierre."
    $chromeProc.WaitForExit()
    Write-AppLog "Ventana VPlan cerrada (Chrome PID $($chromeProc.Id))."

    Remove-Item -LiteralPath $appPidFile -Force -ErrorAction SilentlyContinue

    if ($startedByMe) {
        $listener = Get-NetTCPConnection -State Listen -LocalPort 8080 `
            -ErrorAction SilentlyContinue | Select-Object -First 1

        $currentInfo = Read-KeyValueFile -Path $pidFile
        $currentAppPid = 0
        $currentLauncherPid = 0
        if ($currentInfo.ContainsKey("AppPid")) {
            [void][int]::TryParse($currentInfo["AppPid"], [ref]$currentAppPid)
        }
        if ($currentInfo.ContainsKey("LauncherPid")) {
            [void][int]::TryParse($currentInfo["LauncherPid"], [ref]$currentLauncherPid)
        }

        $listenerPid = if ($listener) { [int]$listener.OwningProcess } else { 0 }
        $isOurs = if ($listenerPid -gt 0) {
            $listenerPid -eq $appPid
        } else {
            ($currentAppPid -eq $appPid) -and ($currentLauncherPid -eq $launcherPid)
        }

        if ($isOurs) {
            Write-AppLog "Deteniendo VPlan iniciado por este lanzador (AppPid=$appPid)."
            & $powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden `
                -File $stopScript -NoPause
            Write-AppLog "stop-vplan.ps1 termino con codigo $LASTEXITCODE."
        } else {
            Write-AppLog "No se detiene VPlan: el PID que escucha ($listenerPid) no coincide con el iniciado ($appPid)."
        }
    } else {
        Write-AppLog "VPlan ya estaba en marcha o lo inicio otro metodo. No se detiene al cerrar la ventana."
    }

    Exit-App 0
} catch {
    $message = $_.Exception.Message
    Write-AppLog "ERROR: $message"

    # Si este lanzador arranco el servidor y Chrome fallo, no dejarlo huerfano.
    try {
        $pidInfo = Read-KeyValueFile -Path $pidFile
        $ownerPid = 0
        if ($pidInfo.ContainsKey("OwnerPid")) {
            [void][int]::TryParse($pidInfo["OwnerPid"], [ref]$ownerPid)
        }
        if ($ownerPid -eq $PID) {
            & $powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden `
                -File $stopScript -NoPause
        }
    } catch { }

    Show-AppError $message
    Exit-App 1
}
