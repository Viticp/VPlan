# VPlan - Restauracion de una copia de seguridad.
#
# Uso:
#     .\scripts\restore-db.ps1 -BackupFile ".\backups\vplan-2026-11-17_120000.sql"
#
# La restauracion REEMPLAZA el contenido actual de la base de datos. Por eso:
#   1. Comprueba que el archivo existe y contiene las tablas de VPlan.
#   2. Se niega a continuar si algo escucha en el puerto 8080 (VPlan abierto).
#   3. Pide escribir RESTAURAR antes de tocar la base de datos.
#
# Para automatizaciones (solo con la aplicacion parada) se puede usar -Force,
# que omite la confirmacion interactiva.
#
# La contrasena se toma de VPLAN_DB_PASSWORD o de .env.local y nunca se
# imprime ni se pasa por la linea de comandos.

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0)]
    [string]$BackupFile,
    [string]$Database = "vplan",
    [string]$DbHost = "127.0.0.1",
    [int]$Port = 3306,
    [string]$User = "",
    [string]$MySqlPath = "",
    [switch]$Force
)

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot "mysql-utils.ps1")

if (-not (Test-Path -LiteralPath $BackupFile)) {
    throw "No existe el archivo de copia de seguridad '$BackupFile'."
}

$resolvedBackup = (Resolve-Path -LiteralPath $BackupFile).Path
$fileInfo = Get-Item -LiteralPath $resolvedBackup
if ($fileInfo.Length -lt 100) {
    throw "El archivo '$resolvedBackup' es demasiado pequeno para ser una copia de VPlan."
}

$content = Get-Content -LiteralPath $resolvedBackup -Raw -Encoding UTF8
if (-not $content.Contains('CREATE TABLE `tareas`') -or
    -not $content.Contains('CREATE TABLE `flyway_schema_history`')) {
    throw "El archivo no parece una copia completa de VPlan: debe contener las tablas tareas y flyway_schema_history."
}

if ($content -match '(?im)^\s*(CREATE\s+DATABASE|USE\s+`?[A-Za-z0-9_]+`?\s*;)') {
    throw "El archivo incluye CREATE DATABASE o USE. Restaura solo copias creadas con scripts\backup-db.ps1, que no cambian de base de datos."
}

$listener = Get-NetTCPConnection -LocalPort 8080 -State Listen -ErrorAction SilentlyContinue
if ($listener -and -not $Force) {
    throw "Hay algo escuchando en el puerto 8080. Deten VPlan con .\scripts\stop-vplan.ps1 (o Ctrl+C si lo arrancaste a mano) antes de restaurar. Si estas seguro de que no es VPlan, repite con -Force."
}

$envValues = Read-DotEnvFile -Path (Join-Path $projectRoot ".env.local")

if (-not $User) {
    $User = Resolve-VPlanSetting -Name "VPLAN_DB_USER" -EnvFileValues $envValues -Default "vplan_app"
}

$password = Resolve-VPlanSetting -Name "VPLAN_DB_PASSWORD" -EnvFileValues $envValues
if (-not $password) {
    throw @"
Falta la contrasena de la base de datos.

Carga el entorno antes de restaurar:
    . .\scripts\set-dev-env.ps1

O crea .env.local con:
    .\scripts\set-db-password.ps1

Nunca escribas la contrasena en un archivo versionado.
"@
}

if (-not $MySqlPath) {
    $MySqlPath = Find-MySqlTool -Name "mysql"
}
if (-not $MySqlPath) {
    throw "No se encuentra mysql.exe. Instala MySQL 8.0 o anade su carpeta bin al PATH."
}

$sizeKb = [math]::Round($fileInfo.Length / 1KB, 1)

Write-Host ""
Write-Host "Restauracion de VPlan" -ForegroundColor Cyan
Write-Host "  Base de datos : $Database ($DbHost`:$Port)"
Write-Host "  Archivo       : $resolvedBackup ($sizeKb KB)"
Write-Host ""

if (-not $Force) {
    Write-Host "ATENCION: se reemplazara el contenido actual de la base '$Database'." -ForegroundColor Yellow
    Write-Host "Las tareas que no esten en esta copia se perderan."
    $answer = Read-Host "Escribe RESTAURAR para continuar"
    if ($answer -ne "RESTAURAR") {
        Write-Host "Restauracion cancelada. No se ha modificado nada." -ForegroundColor Yellow
        exit 1
    }
}

$stdoutFile = [System.IO.Path]::GetTempFileName()
$stderrFile = [System.IO.Path]::GetTempFileName()
$previousPassword = $env:MYSQL_PWD
$env:MYSQL_PWD = $password

try {
    $arguments = @(
        "--host=$DbHost",
        "--port=$Port",
        "--user=$User",
        "--database=$Database",
        "--default-character-set=utf8mb4"
    )

    $process = Start-Process -FilePath $MySqlPath -ArgumentList $arguments `
        -NoNewWindow -Wait -PassThru `
        -RedirectStandardInput $resolvedBackup `
        -RedirectStandardOutput $stdoutFile `
        -RedirectStandardError $stderrFile

    $errorText = ""
    if (Test-Path -LiteralPath $stderrFile) {
        $errorRaw = Get-Content -LiteralPath $stderrFile -Raw -Encoding UTF8
        if ($errorRaw) { $errorText = $errorRaw.Trim() }
    }

    if ($process.ExitCode -ne 0) {
        throw "mysql ha fallado al restaurar (codigo $($process.ExitCode)).`n$errorText"
    }

    # Comprobacion real contra la base restaurada.
    $previousErrorAction = $ErrorActionPreference
    $ErrorActionPreference = "Continue"
    try {
        $migrations = & $MySqlPath @arguments --batch --skip-column-names `
            --execute="SELECT CONCAT('v', version, ' ', description, ' success=', success) FROM flyway_schema_history ORDER BY installed_rank;"
        $migrationExitCode = $LASTEXITCODE

        $taskCount = & $MySqlPath @arguments --batch --skip-column-names `
            --execute="SELECT COUNT(*) FROM tareas;"
        $countExitCode = $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $previousErrorAction
    }

    if ($migrationExitCode -ne 0 -or $countExitCode -ne 0) {
        throw "La restauracion termino, pero la comprobacion posterior ha fallado. Revisa el historial de Flyway y la tabla tareas."
    }
} finally {
    if ($null -eq $previousPassword) {
        Remove-Item Env:MYSQL_PWD -ErrorAction SilentlyContinue
    } else {
        $env:MYSQL_PWD = $previousPassword
    }
    Remove-Item -LiteralPath $stdoutFile, $stderrFile -Force -ErrorAction SilentlyContinue
}

Write-Host "Restauracion completada" -ForegroundColor Green
if ($errorText) {
    Write-Host "  Avisos de mysql: $errorText" -ForegroundColor Yellow
}
Write-Host "  Migraciones Flyway:"
foreach ($migration in @($migrations)) {
    if ($migration) { Write-Host "    $migration" }
}
Write-Host "  Tareas restauradas: $taskCount"
Write-Host ""
Write-Host "Arranca VPlan y comprueba http://localhost:8080/api/health"
