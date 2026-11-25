# Guarda la contrasena de vplan_app en .env.local (ignorado por Git).
#
# Uso:
#     .\scripts\set-db-password.ps1
#
# La contrasena se escribe una sola vez y no se muestra por pantalla.
# No se guarda en el historial de PowerShell porque no forma parte del comando.

$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $PSScriptRoot
$envFile = Join-Path $projectRoot ".env.local"

Write-Host "Introduce la contrasena de vplan_app (no se mostrara)."
$secure = Read-Host "Contrasena" -AsSecureString

$bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
try {
    $plain = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
} finally {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
}

if (-not $plain) {
    throw "La contrasena no puede estar vacia."
}

$content = "# Archivo local, ignorado por Git. No compartir.`r`nVPLAN_DB_PASSWORD=$plain`r`n"
[System.IO.File]::WriteAllText($envFile, $content, (New-Object System.Text.UTF8Encoding($false)))
$plain = $null

Write-Host "Contrasena guardada en .env.local" -ForegroundColor Green
Write-Host "Se cargara automaticamente al ejecutar . .\scripts\set-dev-env.ps1"
