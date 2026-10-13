<#
.SYNOPSIS
    Recreate GitHub release from existing build files or rebuild.
.DESCRIPTION
    Usage: .\recreate-release.ps1 [options] <version> [-TriggerWorkflow]
    Use -Force to rebuild APK/AAB before creating release.
#>
param(
    [Parameter(Mandatory=$true, Position=0)]
    [string]$Version,
    [switch]$Force,
    [switch]$Test,
    [switch]$Qa,
    [switch]$Qc,
    [switch]$TriggerWorkflow,
    [switch]$Help
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RootDir = Split-Path -Parent $ScriptDir

function Write-Info { param($m) Write-Host $m -ForegroundColor Green }
function Write-Warn { param($m) Write-Host $m -ForegroundColor Yellow }
function Write-Err  { param($m) Write-Host "Error: $m" -ForegroundColor Red; exit 1 }

if ($Help) {
    Write-Host @"
Usage: .\recreate-release.ps1 [options] <version> [-TriggerWorkflow]

Options:
  -Force          Force rebuild APK/AAB before creating release
  -Test|-Qa|-Qc   Build type (default: RC)
  -TriggerWorkflow  Trigger workflow dispatch after release

Examples:
  .\recreate-release.ps1 -Test 1.1.9
  .\recreate-release.ps1 -Force -Test 1.1.9
  .\recreate-release.ps1 1.1.9 -TriggerWorkflow
"@
    exit 0
}

$BUILD_TYPE = "RC"
$TAG_SUFFIX = "-rc"
if ($Test) { $BUILD_TYPE = "TEST"; $TAG_SUFFIX = "-test" }
if ($Qa)   { $BUILD_TYPE = "QA";  $TAG_SUFFIX = "-qa" }
if ($Qc)   { $BUILD_TYPE = "QC";  $TAG_SUFFIX = "-qc" }

$TAG_NAME = "v$Version$TAG_SUFFIX"

# Load .env
$envFile = Join-Path $ScriptDir ".env"
if (Test-Path $envFile) {
    Get-Content $envFile | ForEach-Object {
        if ($_ -match '^\s*#') { return }
        if ($_ -match '^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)$') {
            $key = $Matches[1].Trim()
            $val = $Matches[2].Trim() -replace '^["'']|["'']$'
            Set-Item -Path "env:$key" -Value $val -Force
        }
    }
}

if (-not $env:GITHUB_TOKEN) { Write-Err "GITHUB_TOKEN not found. Set it in scripts/.env or environment variable" }

function Build-Release {
    param([string]$BuildType, [string]$VersionSuffix)
    Write-Info "`nBuilding release..."
    Push-Location $RootDir
    try {
        $gradlew = if (Test-Path ".\gradlew.bat") { ".\gradlew.bat" } else { ".\gradlew" }
        if (-not (Test-Path ".\gradlew") -and -not (Test-Path ".\gradlew.bat")) { Write-Err "gradlew not found" }
        $gradleCmd = "$gradlew assembleRelease"
        $isTest = $BuildType -in "TEST","QA","QC"
        if (-not $isTest) { $gradleCmd += " bundleRelease" }
        if ($VersionSuffix) { $gradleCmd += " -PversionSuffix=`"$VersionSuffix`"" }
        Write-Info "Running: $gradleCmd"
        Invoke-Expression "$gradleCmd --no-daemon"
        if ($LASTEXITCODE -ne 0) { Write-Err "Gradle build failed" }
        $apkDir = "app\build\outputs\apk\release"
        $aabDir = "app\build\outputs\bundle\release"
        $apk = Get-ChildItem $apkDir -Filter "*.apk" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
        if (-not $apk) { Write-Err "APK file not found after build" }
        $apkPath = $apk.FullName
        Write-Info "APK built: $apkPath"
        $aabPath = $null
        if (-not $isTest) {
            $aab = Get-ChildItem $aabDir -Filter "*.aab" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
            if (-not $aab) { Write-Err "AAB file not found after build" }
            $aabPath = $aab.FullName
            Write-Info "AAB built: $aabPath"
        }
        return @{ Apk = $apkPath; Aab = $aabPath }
    } finally { Pop-Location }
}

if ($Force) { Write-Info "Force rebuild enabled. Will rebuild APK/AAB before creating release." }
Write-Info "Recreating $BUILD_TYPE release for version: $Version"
Write-Info "Tag: $TAG_NAME"

# Tag
if (-not (git rev-parse -q --verify "refs/tags/$TAG_NAME" 2>$null)) {
    Write-Warn "Tag $TAG_NAME does not exist locally. Fetching..."
    git fetch origin --tags --quiet
    if (-not (git rev-parse -q --verify "refs/tags/$TAG_NAME" 2>$null)) {
        Write-Warn "Tag does not exist. Creating at current HEAD..."
        git tag $TAG_NAME
    }
}
git fetch --tags --quiet 2>$null
$remoteHasTag = git ls-remote --tags origin $TAG_NAME 2>$null
if (-not $remoteHasTag) {
    Write-Warn "Tag not on remote. Pushing..."
    git push origin $TAG_NAME
    Start-Sleep -Seconds 2
}

# Build or find files
if ($Force) {
    $verSuffix = ""
    if ($BUILD_TYPE -ne "RC") { $verSuffix = $TAG_SUFFIX }
    $buildResult = Build-Release -BuildType $BUILD_TYPE -VersionSuffix $verSuffix
    $APK_FILE = $buildResult.Apk
    $AAB_FILE = $buildResult.Aab
} else {
    Write-Info "Looking for existing build files..."
    $apkDir = Join-Path $RootDir "app\build\outputs\apk\release"
    $aabDir = Join-Path $RootDir "app\build\outputs\bundle\release"
    $APK_FILE = Get-ChildItem $apkDir -Filter "*$Version*.apk" -ErrorAction SilentlyContinue | Select-Object -First 1
    $AAB_FILE = $null
    if ($BUILD_TYPE -eq "RC") {
        $AAB_FILE = Get-ChildItem $aabDir -Filter "*$Version*.aab" -ErrorAction SilentlyContinue | Select-Object -First 1
    }
    if (-not $APK_FILE) {
        $APK_FILE = Get-ChildItem $apkDir -Filter "*.apk" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    }
    if ($BUILD_TYPE -eq "RC" -and -not $AAB_FILE) {
        $AAB_FILE = Get-ChildItem $aabDir -Filter "*.aab" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    }
    if (-not $APK_FILE) { Write-Err "APK file not found. Checked app/build/outputs/apk/release" }
    if ($BUILD_TYPE -eq "RC" -and -not $AAB_FILE) { Write-Warn "AAB not found for RC. Only APK will be uploaded." }
    $APK_FILE = $APK_FILE.FullName
    $AAB_FILE = if ($AAB_FILE) { $AAB_FILE.FullName } else { $null }
}

$REPO = (git remote get-url origin 2>$null) -replace '.*github\.com[:/]([^/]+/[^/]+)(\.git)?$','$1' -replace '\.git$',''
if (-not $REPO) { Write-Err "Could not determine repository name" }

# Check/delete existing release
$h = @{
    Authorization = "Bearer $env:GITHUB_TOKEN"
    Accept = "application/vnd.github.v3+json"
}
$check = Invoke-RestMethod -Uri "https://api.github.com/repos/$REPO/releases/tags/$TAG_NAME" -Headers $h -Method Get -ErrorAction SilentlyContinue
if ($check) {
    Write-Warn "Release exists (ID: $($check.id)). Deleting..."
    Invoke-RestMethod -Uri "https://api.github.com/repos/$REPO/releases/$($check.id)" -Headers $h -Method Delete
    Write-Info "Deleted existing release"
    Start-Sleep -Seconds 2
}

# Create release
$releaseTitle = if ($BUILD_TYPE -eq "RC") { "Release Candidate $Version" } else { "$BUILD_TYPE Build $Version" }
$body = @{
    tag_name = $TAG_NAME
    name = $releaseTitle
    body = "$BUILD_TYPE Build $Version`n`nRecreated release"
    prerelease = $true
} | ConvertTo-Json

$release = Invoke-RestMethod -Uri "https://api.github.com/repos/$REPO/releases" -Headers $h -Method Post -Body $body -ContentType "application/json"
$uploadUrl = $release.upload_url -replace '\{[\w,]*\}',''

Write-Info "Release created (ID: $($release.id))"

# Upload APK
Write-Info "Uploading APK..."
$apkBytes = [System.IO.File]::ReadAllBytes($APK_FILE)
$apkName = [System.IO.Path]::GetFileName($APK_FILE)
$uploadUri = "$uploadUrl`?name=$apkName"
try {
    Invoke-RestMethod -Uri $uploadUri -Headers @{
        Authorization = "Bearer $env:GITHUB_TOKEN"
        Accept = "application/vnd.github.v3+json"
        "Content-Type" = "application/vnd.android.package-archive"
    } -Method Post -Body $apkBytes
    Write-Info "APK uploaded successfully"
} catch { Write-Warn "APK upload failed: $_" }

# Upload AAB
if ($AAB_FILE) {
    Write-Info "Uploading AAB..."
    $aabBytes = [System.IO.File]::ReadAllBytes($AAB_FILE)
    $aabName = [System.IO.Path]::GetFileName($AAB_FILE)
    $uploadUri = "$uploadUrl`?name=$aabName"
    try {
        Invoke-RestMethod -Uri $uploadUri -Headers @{
            Authorization = "Bearer $env:GITHUB_TOKEN"
            Accept = "application/vnd.github.v3+json"
            "Content-Type" = "application/octet-stream"
        } -Method Post -Body $aabBytes
        Write-Info "AAB uploaded successfully"
    } catch { Write-Warn "AAB upload failed: $_" }
}

# Trigger workflow
if ($TriggerWorkflow) {
    $branch = git rev-parse --abbrev-ref HEAD
    $body = @{ ref = $branch; inputs = @{ tag_name = $TAG_NAME; build_type = $BUILD_TYPE } } | ConvertTo-Json -Depth 3
    try {
        Invoke-RestMethod -Uri "https://api.github.com/repos/$REPO/actions/workflows/release-rc.yml/dispatches" -Headers $h -Method Post -Body $body -ContentType "application/json" | Out-Null
        Write-Info "Workflow dispatch triggered"
    } catch { Write-Warn "Workflow dispatch failed: $_" }
}

Write-Host ""
Write-Info "Release recreated successfully!"
Write-Info "Tag: $TAG_NAME"
Write-Info "URL: https://github.com/$REPO/releases/tag/$TAG_NAME"
