# VPlan - Acceso directo de escritorio en modo aplicacion.
#
# Uso:
#     .\scripts\create-shortcuts.ps1
#     .\scripts\create-shortcuts.ps1 -Force
#
# Crea en el escritorio:
#   - "VPlan" -> arranca VPlan, abre Chrome en modo aplicacion y detiene el
#                servidor cuando se cierra esa ventana.
#
# Mantiene un unico acceso directo: elimina "Detener VPlan" si existe.
# No requiere permisos de administrador y no modifica el sistema.
#
# Si el acceso ya existe, no se sobrescribe salvo que se use -Force.

[CmdletBinding()]
param(
    [switch]$Force
)

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$desktop = [Environment]::GetFolderPath("Desktop")

if (-not $desktop -or -not (Test-Path -LiteralPath $desktop)) {
    throw "No se ha encontrado la carpeta del escritorio."
}

$powershell = Join-Path $env:SystemRoot "System32\WindowsPowerShell\v1.0\powershell.exe"
if (-not (Test-Path -LiteralPath $powershell)) {
    throw "No se ha encontrado powershell.exe en '$powershell'."
}

$appScript = Join-Path $PSScriptRoot "start-vplan-app.ps1"

if (-not (Test-Path -LiteralPath $appScript)) {
    throw "No se encuentra scripts\start-vplan-app.ps1."
}

function New-VPlanShortcut {
    param(
        [string]$Name,
        [string]$ScriptPath,
        [string]$Description
    )

    $shortcutPath = Join-Path $desktop "$Name.lnk"
    if ((Test-Path -LiteralPath $shortcutPath) -and -not $Force) {
        Write-Host "  Ya existe: $shortcutPath" -ForegroundColor Yellow
        Write-Host "  Usa -Force para reemplazarlo."
        return $shortcutPath
    }

    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = $powershell
    $shortcut.Arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$ScriptPath`""
    $shortcut.WorkingDirectory = $projectRoot
    $shortcut.Description = $Description
    $shortcut.WindowStyle = 7
    $shortcut.Save()

    Write-Host "  Creado: $shortcutPath" -ForegroundColor Green
    return $shortcutPath
}

Write-Host ""
Write-Host "VPlan - acceso directo" -ForegroundColor Cyan
Write-Host "  Escritorio: $desktop"
Write-Host ""

New-VPlanShortcut -Name "VPlan" -ScriptPath $appScript `
    -Description "Abre VPlan en una ventana de Chrome y detiene el servidor al cerrarla" | Out-Null

$stopShortcut = Join-Path $desktop "Detener VPlan.lnk"
if (Test-Path -LiteralPath $stopShortcut) {
    Remove-Item -LiteralPath $stopShortcut -Force
    Write-Host "  Eliminado: $stopShortcut" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Acceso directo preparado. Doble clic en 'VPlan' para abrir la aplicacion." -ForegroundColor Green
