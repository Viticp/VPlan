# Funciones compartidas por los scripts de copia de seguridad y restauracion.
#
# Este archivo NO contiene secretos. La contrasena se lee de .env.local o de la
# variable de entorno VPLAN_DB_PASSWORD, y nunca se imprime por pantalla.

# Lee un archivo .env y devuelve un diccionario nombre -> valor.
# Usa UTF-8 explicito: una contrasena puede contener caracteres no ASCII.
function Read-DotEnvFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    $values = @{}
    if (-not (Test-Path -LiteralPath $Path)) { return $values }

    foreach ($line in Get-Content -LiteralPath $Path -Encoding UTF8) {
        $trimmed = $line.Trim()
        if (-not $trimmed -or $trimmed.StartsWith("#")) { continue }

        $separator = $trimmed.IndexOf("=")
        if ($separator -lt 1) { continue }

        $name = $trimmed.Substring(0, $separator).Trim()
        $value = $trimmed.Substring($separator + 1).Trim()

        if ($value.Length -ge 2) {
            $first = $value.Substring(0, 1)
            $last = $value.Substring($value.Length - 1, 1)
            if (($first -eq '"' -and $last -eq '"') -or ($first -eq "'" -and $last -eq "'")) {
                $value = $value.Substring(1, $value.Length - 2)
            }
        }

        if ($name -match "^[A-Za-z_][A-Za-z0-9_]*$") {
            $values[$name] = $value
        }
    }

    return $values
}

# Prioriza la variable de la sesion actual y, si no existe, .env.local.
function Resolve-VPlanSetting {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,
        [hashtable]$EnvFileValues = @{},
        [string]$Default = ""
    )

    $fromSession = [Environment]::GetEnvironmentVariable($Name, "Process")
    if (-not [string]::IsNullOrEmpty($fromSession)) { return $fromSession }

    if ($EnvFileValues -and $EnvFileValues.ContainsKey($Name)) {
        $fromFile = $EnvFileValues[$Name]
        if (-not [string]::IsNullOrEmpty($fromFile)) { return $fromFile }
    }

    return $Default
}

# Busca una herramienta de MySQL en el PATH o en las rutas habituales de Windows.
function Find-MySqlTool {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    $command = Get-Command "$Name.exe" -ErrorAction SilentlyContinue
    if ($command) { return $command.Source }

    $roots = @()
    foreach ($base in @($env:ProgramFiles, ${env:ProgramFiles(x86)})) {
        if (-not $base) { continue }
        $mysqlRoot = Join-Path $base "MySQL"
        if (Test-Path -LiteralPath $mysqlRoot) { $roots += $mysqlRoot }
    }

    foreach ($root in $roots) {
        $directories = Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue |
            Sort-Object Name -Descending
        foreach ($directory in $directories) {
            $candidate = Join-Path $directory.FullName "bin\$Name.exe"
            if (Test-Path -LiteralPath $candidate) { return $candidate }
        }
    }

    return $null
}
