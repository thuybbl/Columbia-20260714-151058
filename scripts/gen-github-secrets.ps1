# Generate GitHub Actions secret names and values for release build (keystore).
# Run locally and copy each value into Settings -> Secrets and variables -> Actions.
# Do not commit or share the console output.

param(
    [string]$KeystorePath = "app/keystore.jks",
    [switch]$NoPrompt,
    [switch]$Help
)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RootDir = Split-Path -Parent $ScriptDir
if (-not [System.IO.Path]::IsPathRooted($KeystorePath)) {
    $KeystorePath = Join-Path $RootDir $KeystorePath
}

function Write-Color {
    param([string]$Text, [string]$Color = "White")
    Write-Host $Text -ForegroundColor $Color
}

function Show-Usage {
    Get-Content $MyInvocation.ScriptName | Select-Object -First 30
    @"
Usage: .\gen-github-secrets.ps1 [OPTIONS] [KEYSTORE_PATH]

  KEYSTORE_PATH   Path to .jks keystore (default: app/keystore.jks)

Options:
  -NoPrompt       Use env only: KEYSTORE_PASSWORD, KEY_ALIAS, KEY_PASSWORD
  -Help           Show this help

Env (optional if not -NoPrompt):
  KEYSTORE_PASSWORD   Keystore password
  KEY_ALIAS           Key alias (default: first alias from keystore)
  KEY_PASSWORD        Key password (default: KEYSTORE_PASSWORD)
"@
}

if ($Help) { Show-Usage; exit 0 }

if (-not (Test-Path $KeystorePath)) {
    Write-Color "Keystore not found: $KeystorePath" Red
    Write-Color "Create one first: .\scripts\gen-key.ps1 -Output app/keystore.jks" Red
    exit 1
}

$StorePass = ""
$KeyAlias = ""
$KeyPass = ""

if ($NoPrompt) {
    if (-not $env:KEYSTORE_PASSWORD) {
        Write-Color "Set KEYSTORE_PASSWORD for non-interactive run" Red
        exit 1
    }
    $StorePass = $env:KEYSTORE_PASSWORD
    $KeyAlias = $env:KEY_ALIAS
    $KeyPass = if ($env:KEY_PASSWORD) { $env:KEY_PASSWORD } else { $StorePass }
}

if (-not $StorePass) {
    Write-Color "Keystore: $KeystorePath" Cyan
    $SecurePass = Read-Host "Keystore password" -AsSecureString
    $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecurePass)
    $StorePass = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
    [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)
}

# Get first alias from keystore if not set
if (-not $KeyAlias) {
    $listOutput = & keytool -list -keystore $KeystorePath -storepass $StorePass 2>$null
    $KeyAlias = ($listOutput | Where-Object { $_ -match "^\s+\w" } | Select-Object -First 1) -replace "^\s+|\s+$", "" -split "\s+" | Select-Object -First 1
    if (-not $KeyAlias -and $NoPrompt) {
        Write-Color "Set KEY_ALIAS env or ensure keystore has an alias." Red
        exit 1
    }
    if (-not $KeyAlias) {
        $KeyAlias = Read-Host "Key alias"
    }
}

if (-not $KeyPass -and -not $NoPrompt) {
    $SecureKey = Read-Host "Key password (same as keystore if empty)" -AsSecureString
    if ($SecureKey.Length -gt 0) {
        $BSTR2 = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureKey)
        $KeyPass = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR2)
        [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR2)
    }
}
$KeyPass = if ($KeyPass) { $KeyPass } else { $StorePass }

# Base64 encode keystore (single line for GitHub secret)
$KeystoreBytes = [System.IO.File]::ReadAllBytes($KeystorePath)
$KeystoreB64 = [Convert]::ToBase64String($KeystoreBytes)

Write-Host ""
Write-Color "=== Add these as GitHub Actions secrets ===" Green
Write-Host "Repo -> Settings -> Secrets and variables -> Actions -> New repository secret"
Write-Host ""
Write-Color "Do not commit or share this output. Clear terminal after copying." Yellow
Write-Host ""

function Print-Secret {
    param([string]$Name, [string]$Value, [switch]$Mask)
    Write-Color "Secret name:  $Name" Cyan
    Write-Color "Value:       " Cyan -NoNewline
    if ($Mask) { Write-Host "(paste the value below)" }
    Write-Host $Value
    Write-Host ""
}

Print-Secret "KEYSTORE_BASE64" $KeystoreB64 -Mask
Print-Secret "KEYSTORE_PASSWORD" $StorePass -Mask
Print-Secret "KEY_ALIAS" $KeyAlias -Mask
Print-Secret "KEY_PASSWORD" $KeyPass -Mask

Write-Color "Optional (used by this workflow):" Green
Write-Host "  GITHUB_ACTOR, GH_PACKAGES_TOKEN (or legacy NV_ACTOR/NV_TOKEN) - GitHub Packages if needed"
Write-Host "  DISCORD_WEBHOOK_URL    - for Discord notifications"
Write-Host "  GITHUB_TOKEN           - usually set automatically for Actions"
Write-Host ""
