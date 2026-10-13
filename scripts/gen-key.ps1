# Generate Android release keystore (JKS) for app signing.
# Use for new apps or when rotating signing keys. Backup the keystore and
# store passwords securely; losing them prevents publishing updates.
# Usage: .\gen-key.ps1 [options]

param(
    [string]$Output = "app/keystore.jks",
    [string]$Alias = "key0",
    [int]$Validity = 10000,
    [switch]$NoPrompt,
    [switch]$Help
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RootDir = Split-Path -Parent $ScriptDir

# Resolve output path
if (-not [System.IO.Path]::IsPathRooted($Output)) {
    $Output = Join-Path $RootDir $Output
}

# Certificate DN defaults (can be overridden by env)
$KEYSTORE_CN = if ($env:KEYSTORE_CN) { $env:KEYSTORE_CN } else { "Android" }
$KEYSTORE_OU = if ($env:KEYSTORE_OU) { $env:KEYSTORE_OU } else { "Android" }
$KEYSTORE_O  = if ($env:KEYSTORE_O)  { $env:KEYSTORE_O }  else { "App" }
$KEYSTORE_L  = if ($env:KEYSTORE_L)  { $env:KEYSTORE_L }  else { "HCM" }
$KEYSTORE_ST = if ($env:KEYSTORE_ST) { $env:KEYSTORE_ST } else { "HCM" }
$KEYSTORE_C  = if ($env:KEYSTORE_C)  { $env:KEYSTORE_C }  else { "VN" }

function Write-Info { param($msg) Write-Host $msg -ForegroundColor Green }
function Write-Warn { param($msg) Write-Host $msg -ForegroundColor Yellow }
function Write-Err  { param($msg) Write-Host "Error: $msg" -ForegroundColor Red; exit 1 }

if ($Help) {
    Write-Host @"
Usage: .\gen-key.ps1 [options]

Generate an Android release keystore (JKS) for app signing.

Options:
  -Output PATH   Output keystore path (default: app/keystore.jks)
  -Alias NAME   Key alias (default: release)
  -Validity N   Validity in days (default: 10000)
  -NoPrompt     Non-interactive: use env KEYSTORE_PASSWORD, KEY_PASSWORD
  -Help         Show this help

Environment (for -NoPrompt):
  KEYSTORE_PASSWORD   Keystore password (required if -NoPrompt)
  KEY_PASSWORD        Key password (defaults to KEYSTORE_PASSWORD)

Certificate (optional env):
  KEYSTORE_CN, KEYSTORE_OU, KEYSTORE_O, KEYSTORE_L, KEYSTORE_ST, KEYSTORE_C
  KEYSTORE_DNAME      Full -dname string (overrides others if set)

Examples:
  .\gen-key.ps1
  .`\gen-key.ps1 -Output app/my_release.jks -Alias mykey
  `$env:KEYSTORE_PASSWORD='secret'; .`\gen-key.ps1 -NoPrompt
"@
    exit 0
}

if (Test-Path $Output) {
    if ($NoPrompt) {
        Write-Warn "Already exists: $Output — skip (xóa file rồi chạy lại để rotate)"
        exit 0
    }
    $ans = Read-Host "Warning: $Output already exists. Overwrite? [y/N]"
    if ($ans -notmatch '^[yY]') { Write-Host "Aborted."; exit 0 }
}

$STORE_PASS = ""
$KEY_PASS = ""

if ($NoPrompt) {
    if (-not $env:KEYSTORE_PASSWORD) { Write-Err "Set KEYSTORE_PASSWORD for non-interactive run" }
    $STORE_PASS = $env:KEYSTORE_PASSWORD
    $KEY_PASS = if ($env:KEY_PASSWORD) { $env:KEY_PASSWORD } else { $STORE_PASS }
} else {
    Write-Info "Generate Android release keystore"
    Write-Host "Output: $Output"
    Write-Host "Alias:  $Alias"
    Write-Host "Validity: $Validity days"
    Write-Host ""
    $sec = Read-Host "Keystore password" -AsSecureString
    $STORE_PASS = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec))
    $sec = Read-Host "Key password (same as keystore if empty)" -AsSecureString
    $KEY_PASS = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec))
    if ([string]::IsNullOrWhiteSpace($KEY_PASS)) { $KEY_PASS = $STORE_PASS }
}

$outDir = Split-Path -Parent $Output
if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir -Force | Out-Null }

$DNAME = if ($env:KEYSTORE_DNAME) { $env:KEYSTORE_DNAME } else {
    "CN=$KEYSTORE_CN, OU=$KEYSTORE_OU, O=$KEYSTORE_O, L=$KEYSTORE_L, ST=$KEYSTORE_ST, C=$KEYSTORE_C"
}

$keytool = "keytool"
if (-not (Get-Command $keytool -ErrorAction SilentlyContinue)) {
    $jdk = Get-ChildItem "C:\Program Files\Java" -ErrorAction SilentlyContinue | Where-Object { $_.Name -match "jdk" } | Select-Object -First 1
    if ($jdk) { $keytool = Join-Path $jdk.FullName "bin\keytool.exe" }
}
if (-not (Test-Path $keytool) -and -not (Get-Command "keytool" -ErrorAction SilentlyContinue)) {
    $keytool = "keytool"
}

& keytool -genkey -v -keystore $Output -alias $Alias -keyalg RSA -keysize 2048 `
    -validity $Validity -storepass $STORE_PASS -keypass $KEY_PASS -dname $DNAME

if ($LASTEXITCODE -ne 0) { Write-Err "keytool failed" }

Write-Host ""
Write-Info "Keystore created: $Output"
Write-Host ""
Write-Warn "Next steps:"
Write-Host "  1. Back up the keystore file and store it securely."
Write-Host "  2. Keep keystore and key passwords in a password manager."
Write-Host "  3. Ensure the keystore path is in .gitignore (e.g. *.jks, *.keystore)."
Write-Host "  4. For CI: base64-encode the keystore and set KEYSTORE_BASE64; set KEYSTORE_PASSWORD, KEY_ALIAS, KEY_PASSWORD secrets."
Write-Host "  5. In app/build.gradle.kts, point signingConfig release to this keystore."
