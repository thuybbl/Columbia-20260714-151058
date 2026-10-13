# Encode release.jks + google-services.json into scripts/.env
# (KEYSTORE_BASE64, GOOGLE_SERVICES_JSON_BASE64) for push-secret / CI.
#
#   .\scripts\gen-env-base64.ps1
#   .\scripts\gen-env-base64.ps1 -Keystore app\release.jks -GoogleServices app\google-services.json
#   .\scripts\gen-env-base64.ps1 -Print

param(
    [string]$Keystore = "",
    [string]$GoogleServices = "",
    [string]$EnvFile = "",
    [switch]$Print,
    [switch]$Help
)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RootDir = Split-Path -Parent $ScriptDir

if (-not $EnvFile) { $EnvFile = Join-Path $ScriptDir ".env" }
$EnvExample = Join-Path $ScriptDir ".env.example"

function Resolve-RootPath([string]$Path) {
    if ([System.IO.Path]::IsPathRooted($Path)) { return $Path }
    return (Join-Path $RootDir $Path)
}

function Show-Usage {
    @"
Usage: .\gen-env-base64.ps1 [OPTIONS]

Encode keystore + google-services.json as base64 into scripts/.env.

Options:
  -Keystore PATH          Keystore .jks (default: app/release.jks, else app/keystore.jks)
  -GoogleServices PATH    google-services.json (default: app/google-services.json)
  -EnvFile PATH           Target .env (default: scripts/.env)
  -Print                  Print values only; do not write .env
  -Help                   Show this help
"@
}

if ($Help) { Show-Usage; exit 0 }

if (-not $Keystore) {
    $release = Join-Path $RootDir "app\release.jks"
    $fallback = Join-Path $RootDir "app\keystore.jks"
    if (Test-Path $release) { $Keystore = $release }
    elseif (Test-Path $fallback) { $Keystore = $fallback }
    else { $Keystore = $release }
} else {
    $Keystore = Resolve-RootPath $Keystore
}

if (-not $GoogleServices) {
    $GoogleServices = Join-Path $RootDir "app\google-services.json"
} else {
    $GoogleServices = Resolve-RootPath $GoogleServices
}

$EnvFile = Resolve-RootPath $EnvFile

function Get-Base64File([string]$Path) {
    $bytes = [System.IO.File]::ReadAllBytes($Path)
    return [Convert]::ToBase64String($bytes)
}

function Set-EnvKey([string]$File, [string]$Key, [string]$Value) {
    $lines = @(Get-Content -LiteralPath $File -ErrorAction Stop)
    $found = $false
    $out = New-Object System.Collections.Generic.List[string]
    foreach ($line in $lines) {
        if ($line -match ("^" + [regex]::Escape($Key) + "=")) {
            $out.Add("$Key=$Value") | Out-Null
            $found = $true
        } else {
            $out.Add($line) | Out-Null
        }
    }
    if (-not $found) {
        $inserted = $false
        $final = New-Object System.Collections.Generic.List[string]
        foreach ($line in $out) {
            if (-not $inserted -and $line -match '^#\s*[Vv][Aa][Rr]') {
                $final.Add("$Key=$Value") | Out-Null
                $final.Add("") | Out-Null
                $inserted = $true
            }
            $final.Add($line) | Out-Null
        }
        if (-not $inserted) { $final.Add("$Key=$Value") | Out-Null }
        $out = $final
    }
    Set-Content -LiteralPath $File -Value $out -Encoding UTF8
}

$hasKs = Test-Path -LiteralPath $Keystore
$hasGs = Test-Path -LiteralPath $GoogleServices

$KeystoreB64 = ""
$GsB64 = ""
if ($hasKs) {
    $KeystoreB64 = Get-Base64File $Keystore
    $ksLen = (Get-Item -LiteralPath $Keystore).Length
    Write-Host "Keystore:  $Keystore ($ksLen bytes → $($KeystoreB64.Length) chars b64)" -ForegroundColor Cyan
} else {
    Write-Host "Keystore not found: $Keystore — skip KEYSTORE_BASE64" -ForegroundColor Yellow
    Write-Host "  Create one: .\scripts\gen-key.ps1 -Output app\release.jks" -ForegroundColor Yellow
}
if ($hasGs) {
    $GsB64 = Get-Base64File $GoogleServices
    $gsLen = (Get-Item -LiteralPath $GoogleServices).Length
    Write-Host "Firebase:  $GoogleServices ($gsLen bytes → $($GsB64.Length) chars b64)" -ForegroundColor Cyan
} else {
    Write-Host "google-services.json not found: $GoogleServices — skip GOOGLE_SERVICES_JSON_BASE64" -ForegroundColor Yellow
}
if (-not $KeystoreB64 -and -not $GsB64) {
    Write-Host "Nothing to encode — need app/release.jks and/or app/google-services.json" -ForegroundColor Red
    exit 1
}

if ($Print) {
    Write-Host ""
    if ($KeystoreB64) { Write-Host "KEYSTORE_BASE64=$KeystoreB64" }
    if ($GsB64) { Write-Host "GOOGLE_SERVICES_JSON_BASE64=$GsB64" }
    Write-Host ""
    Write-Host "Printed only — .env not modified. Clear terminal after copying." -ForegroundColor Yellow
    exit 0
}

if (-not (Test-Path -LiteralPath $EnvFile)) {
    if (Test-Path -LiteralPath $EnvExample) {
        Copy-Item -LiteralPath $EnvExample -Destination $EnvFile -Force
        Write-Host "Created $EnvFile from .env.example" -ForegroundColor Yellow
    } else {
        @(
            "# local env for release scripts",
            "",
            "# secret",
            "",
            "KEYSTORE_BASE64=",
            "GOOGLE_SERVICES_JSON_BASE64=",
            "",
            "# var"
        ) | Set-Content -LiteralPath $EnvFile -Encoding UTF8
        Write-Host "Created minimal $EnvFile" -ForegroundColor Yellow
    }
}

if ($KeystoreB64) { Set-EnvKey $EnvFile "KEYSTORE_BASE64" $KeystoreB64 }
if ($GsB64) { Set-EnvKey $EnvFile "GOOGLE_SERVICES_JSON_BASE64" $GsB64 }

Write-Host ""
Write-Host "Updated: $EnvFile" -ForegroundColor Green
if ($KeystoreB64) { Write-Host "  KEYSTORE_BASE64=… ($($KeystoreB64.Length) chars)" }
if ($GsB64) { Write-Host "  GOOGLE_SERVICES_JSON_BASE64=… ($($GsB64.Length) chars)" }
Write-Host ""
Write-Host "Next: .\scripts\push-secret.ps1"
Write-Host "Do not commit scripts/.env" -ForegroundColor Yellow
