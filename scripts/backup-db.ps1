# VPlan - Copia de seguridad completa de la base de datos.
#
# Uso:
#     .\scripts\backup-db.ps1
#     .\scripts\backup-db.ps1 -OutputDirectory "D:\copias"
#
# Genera un archivo .sql con TODA la base vplan: la tabla tareas y el
# historial de Flyway. Restaurar solo tareas romperia Flyway, asi que el dump
# siempre incluye flyway_schema_history.
#
# La contrasena se toma de VPLAN_DB_PASSWORD o de .env.local. Nunca se
# imprime ni se pasa por la linea de comandos.
#
# Requisito: la base de datos debe existir. La aplicacion puede estar en marcha
# (el dump se hace con --single-transaction), pero lo mas seguro es pararla.

[CmdletBinding()]
param(
    [string]$Database = "vplan",
    [string]$OutputDirectory = "",
    [string]$DbHost = "127.0.0.1",
    [int]$Port = 3306,
    [string]$User = "",
    [string]$MySqlDumpPath = ""
)

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $PSScriptRoot "mysql-utils.ps1")

if (-not $OutputDirectory) {
    $OutputDirectory = Join-Path $projectRoot "backups"
}

$envValues = Read-DotEnvFile -Path (Join-Path $projectRoot ".env.local")

if (-not $User) {
    $User = Resolve-VPlanSetting -Name "VPLAN_DB_USER" -EnvFileValues $envValues -Default "vplan_app"
}

$password = Resolve-VPlanSetting -Name "VPLAN_DB_PASSWORD" -EnvFileValues $envValues
if (-not $password) {
    throw @"
Falta la contrasena de la base de datos.

Carga el entorno antes de hacer la copia:
    . .\scripts\set-dev-env.ps1

O crea .env.local con:
    .\scripts\set-db-password.ps1

Nunca escribas la contrasena en un archivo versionado.
"@
}

if (-not $MySqlDumpPath) {
    $MySqlDumpPath = Find-MySqlTool -Name "mysqldump"
}
if (-not $MySqlDumpPath) {
    throw "No se encuentra mysqldump.exe. Instala MySQL 8.0 o anade su carpeta bin al PATH."
}

New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null

$stamp = Get-Date -Format "yyyy-MM-dd_HHmmss"
$target = Join-Path $OutputDirectory "vplan-$stamp.sql"
if (Test-Path -LiteralPath $target) {
    throw "Ya existe el archivo '$target'. Espera un segundo y vuelve a intentarlo."
}

$arguments = @(
    "--host=$DbHost",
    "--port=$Port",
    "--user=$User",
    "--single-transaction",
    "--no-tablespaces",
    "--skip-add-locks",
    "--skip-triggers",
    "--set-gtid-purged=OFF",
    "--default-character-set=utf8mb4",
    "--result-file=$target",
    $Database
)

$previousPassword = $env:MYSQL_PWD
$previousErrorAction = $ErrorActionPreference
$env:MYSQL_PWD = $password
$ErrorActionPreference = "Continue"
try {
    $output = & $MySqlDumpPath @arguments 2>&1
    $exitCode = $LASTEXITCODE
} finally {
    $ErrorActionPreference = $previousErrorAction
    if ($null -eq $previousPassword) {
        Remove-Item Env:MYSQL_PWD -ErrorAction SilentlyContinue
    } else {
        $env:MYSQL_PWD = $previousPassword
    }
}

if ($exitCode -ne 0) {
    Remove-Item -LiteralPath $target -Force -ErrorAction SilentlyContinue
    throw "mysqldump ha fallado (codigo $exitCode). Comprueba que MySQL esta en marcha y que las credenciales son correctas.`n$output"
}

if (-not (Test-Path -LiteralPath $target)) {
    throw "mysqldump termino sin errores pero no creo el archivo '$target'."
}

$content = Get-Content -LiteralPath $target -Raw -Encoding UTF8
if (-not $content) {
    Remove-Item -LiteralPath $target -Force -ErrorAction SilentlyContinue
    throw "La copia esta vacia. No se ha conservado el archivo."
}
$missing = @()
if (-not $content.Contains('CREATE TABLE `tareas`')) { $missing += "tareas" }
if (-not $content.Contains('CREATE TABLE `flyway_schema_history`')) { $missing += "flyway_schema_history" }

if ($missing.Count -gt 0) {
    Remove-Item -LiteralPath $target -Force -ErrorAction SilentlyContinue
    throw "La copia no contiene las tablas esperadas: $($missing -join ', '). No se ha conservado el archivo."
}

$size = (Get-Item -LiteralPath $target).Length
$sizeKb = [math]::Round($size / 1KB, 1)

Write-Host ""
Write-Host "Copia de seguridad creada" -ForegroundColor Green
Write-Host "  Archivo : $target"
Write-Host "  Tamano  : $sizeKb KB"
Write-Host "  Base    : $Database ($DbHost`:$Port)"
Write-Host "  Incluye : tareas y flyway_schema_history"
Write-Host ""
Write-Host "Guarda el archivo en un lugar privado. La carpeta backups\ esta ignorada por Git."
Write-Host "Para restaurarlo: .\scripts\restore-db.ps1 -BackupFile `"$target`""
