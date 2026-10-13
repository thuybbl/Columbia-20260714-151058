# Build and create RC/Test/QA/QC release
# Usage: .\release-rc.ps1 [options] <version|major|minor|patch>
# Example: .\release-rc.ps1 patch
# Example: .\release-rc.ps1 --test patch

param(
    [string]$VersionArg,
    [switch]$Force,
    [switch]$Test,
    [switch]$Qa,
    [switch]$Qc,
    [switch]$Help
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RootDir = Split-Path -Parent $ScriptDir
$BuildGradle = Join-Path $RootDir "app\build.gradle.kts"

function Write-Info { param($msg) Write-Host $msg -ForegroundColor Green }
function Write-Warn { param($msg) Write-Host $msg -ForegroundColor Yellow }
function Write-Err  { param($msg) Write-Host "Error: $msg" -ForegroundColor Red; exit 1 }

function Load-EnvFile {
    $envFile = Join-Path $ScriptDir ".env"
    if (Test-Path $envFile) {
        Write-Info "Loading environment variables from $envFile..."
        Get-Content $envFile | ForEach-Object {
            $line = $_.Trim()
            if ([string]::IsNullOrWhiteSpace($line) -or $line.StartsWith("#")) { return }
            if ($line -match '^([A-Za-z_][A-Za-z0-9_]*)=(.*)$') {
                $key = $Matches[1]
                $val = $Matches[2].Trim().Trim('"').Trim("'")
                [Environment]::SetEnvironmentVariable($key, $val, "Process")
            }
        }
        Write-Info "Environment variables loaded"
    } else {
        Write-Warn ".env file not found at $envFile (optional)"
    }
}

function Get-CurrentVersion {
    $content = Get-Content $BuildGradle -Raw
    $vn = $null; $vc = $null
    if ($content -match 'versionName\s*=\s*"([^"]+)"') { $vn = $Matches[1] }
    if ($content -match 'versionCode\s*=\s*(\d+)') { $vc = $Matches[1] }
    if (-not $vn -or -not $vc) { Write-Err "versionName or versionCode not found in build.gradle.kts" }
    return @{ Name = $vn; Code = [int]$vc }
}

function Test-VersionFormat {
    param([string]$v)
    if ($v -notmatch '^\d+\.\d+\.\d+(-[a-zA-Z0-9.-]+)?(\+[a-zA-Z0-9.-]+)?$') {
        Write-Err "Invalid version format: $v. Must be semver (e.g. 1.0.0, 1.0.0-beta.1)"
    }
}

function Bump-Version {
    param([string]$Current, [string]$BumpType)
    $parts = $Current -replace '-.*', '' -split '\.'
    $major = [int]$parts[0]; $minor = [int]$parts[1]; $patch = [int]$parts[2]
    switch ($BumpType) {
        "major" { return "$($major + 1).0.0" }
        "minor" { return "$major.$($minor + 1).0" }
        "patch" { return "$major.$minor.$($patch + 1)" }
        default { Write-Err "Invalid bump type: $BumpType. Use major, minor, or patch" }
    }
}

function Set-Version {
    param([string]$Name, [int]$Code)
    $content = Get-Content $BuildGradle -Raw
    $content = $content -replace '(versionName\s*=\s*")[^"]+(")', "`${1}$Name`$2"
    $content = $content -replace '(versionCode\s*=\s*)\d+', "`${1}$Code"
    Set-Content -Path $BuildGradle -Value $content -NoNewline
}

function Build-Release {
    param([string]$BuildType, [string]$VersionSuffix)
    Write-Info "`nBuilding release..."
    Set-Location $RootDir
    if (-not (Test-Path ".\gradlew.bat") -and -not (Test-Path ".\gradlew")) {
        Write-Err "gradlew not found. Make sure you're in the project root."
    }
    $gradlew = if (Test-Path ".\gradlew.bat") { ".\gradlew.bat" } else { ".\gradlew" }
    Write-Info "Cleaning the project..."
    & $gradlew clean 2>&1 | Out-Host
    $tasks = @("assembleRelease")
    $isTest = $BuildType -in @("TEST","QA","QC")
    if (-not $isTest) { $tasks += "bundleRelease" }
    $gradleArgs = @("--no-daemon") + $tasks
    if ($VersionSuffix) { $gradleArgs = @("-PversionSuffix=$VersionSuffix") + $gradleArgs }
    Write-Info "Running: $gradlew $($gradleArgs -join ' ')"
    & $gradlew @gradleArgs 2>&1 | Out-Host
    if ($LASTEXITCODE -ne 0) { Write-Err "Gradle build failed" }
    $apkDir = Join-Path $RootDir "app\build\outputs\apk\release"
    $apks = Get-ChildItem -Path $apkDir -Filter "*.apk" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending
    if (-not $apks) { Write-Err "APK file not found after build!" }
    $apkFile = $apks[0].FullName
    Write-Info "APK built: $apkFile"
    $aabFile = ""
    if (-not $isTest) {
        $aabDir = Join-Path $RootDir "app\build\outputs\bundle\release"
        $aabs = Get-ChildItem -Path $aabDir -Filter "*.aab" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending
        if (-not $aabs) { Write-Err "AAB file not found after build!" }
        $aabFile = $aabs[0].FullName
        Write-Info "AAB built: $aabFile"
    }
    return @{ Apk = $apkFile; Aab = $aabFile }
}

function Get-RepoName {
    $url = git config --get remote.origin.url 2>$null
    if (-not $url) { return $null }
    if ($url -match 'github\.com[:/]([^/]+/[^/]+?)(\.git)?$') { return $Matches[1] }
    return $null
}

function Create-GitHubRelease {
    param($TagName, $VersionName, $Token, $ApkFile, $AabFile, $BuildType)
    Set-Location $RootDir
    if (-not $ApkFile -or -not (Test-Path $ApkFile)) { Write-Err "APK file not found: $ApkFile" }
    $apkAbs = [System.IO.Path]::GetFullPath($ApkFile)
    $repo = Get-RepoName
    if (-not $repo) { Write-Err "Could not parse repository name" }
    Write-Info "Repository: $repo"
    $headers = @{
        "Authorization" = "Bearer $Token"
        "Accept" = "application/vnd.github.v3+json"
        "X-GitHub-Api-Version" = "2022-11-28"
    }
    try {
        $r = Invoke-RestMethod -Uri "https://api.github.com/repos/$repo" -Headers $headers -Method Get
    } catch {
        Write-Err "Failed to access repository: $_"
    }
    Write-Info "Checking if release exists for tag $TagName..."
    $existing = $null
    try {
        $existing = Invoke-RestMethod -Uri "https://api.github.com/repos/$repo/releases/tags/$TagName" -Headers $headers -Method Get
    } catch { }
    if ($existing) {
        Write-Warn "Release already exists (ID: $($existing.id)). Deleting..."
        Invoke-RestMethod -Uri "https://api.github.com/repos/$repo/releases/$($existing.id)" -Headers $headers -Method Delete
        Start-Sleep -Seconds 2
    }
    $releaseTitle = if ($BuildType -eq "RC") { "Release Candidate $VersionName" } else { "$BuildType Build $VersionName" }
    $body = @{
        tag_name = $TagName
        name = $releaseTitle
        body = "$BuildType build for $VersionName`n`nThis is an automated $BuildType build."
        prerelease = $true
        draft = $false
    } | ConvertTo-Json
    $release = Invoke-RestMethod -Uri "https://api.github.com/repos/$repo/releases" -Headers $headers -Method Post -Body $body -ContentType "application/json"
    $uploadUrl = $release.upload_url -replace '\{.*$', ''
    Write-Info "Uploading APK..."
    $apkBytes = [System.IO.File]::ReadAllBytes($apkAbs)
    $apkName = [System.IO.Path]::GetFileName($apkAbs)
    try {
        Invoke-RestMethod -Uri "$uploadUrl`?name=$apkName" -Headers @{
            "Authorization" = "Bearer $Token"
            "Accept" = "application/vnd.github.v3+json"
            "Content-Type" = "application/vnd.android.package-archive"
        } -Method Post -Body $apkBytes
        Write-Info "APK uploaded: $apkName"
    } catch { Write-Warn "APK upload failed: $_" }
    if ($AabFile -and (Test-Path $AabFile)) {
        Write-Info "Uploading AAB..."
        $aabBytes = [System.IO.File]::ReadAllBytes($AabFile)
        $aabName = [System.IO.Path]::GetFileName($AabFile)
        try {
            Invoke-RestMethod -Uri "$uploadUrl`?name=$aabName" -Headers @{
                "Authorization" = "Bearer $Token"
                "Accept" = "application/vnd.github.v3+json"
                "Content-Type" = "application/octet-stream"
            } -Method Post -Body $aabBytes
            Write-Info "AAB uploaded: $aabName"
        } catch { Write-Warn "AAB upload failed: $_" }
    }
}

function Invoke-WorkflowDispatch {
    param($TagName, $Token, $BuildType)
    Write-Info "`nTriggering workflow dispatch..."
    $repo = Get-RepoName
    if (-not $repo) { Write-Warn "Could not determine repository. Skipping."; return }
    $branch = git rev-parse --abbrev-ref HEAD 2>$null
    if (-not $branch) { Write-Warn "Could not determine branch."; return }
    $body = @{
        ref = $branch
        inputs = @{ tag_name = $TagName; build_type = $BuildType }
    } | ConvertTo-Json
    try {
        Invoke-RestMethod -Uri "https://api.github.com/repos/$repo/actions/workflows/release-rc.yml/dispatches" `
            -Headers @{
                "Authorization" = "Bearer $Token"
                "Accept" = "application/vnd.github.v3+json"
            } -Method Post -Body $body -ContentType "application/json"
        Write-Info "Workflow dispatch triggered successfully"
    } catch { Write-Warn "Workflow dispatch failed: $_" }
}

# Parse positional args
$posArgs = @()
foreach ($a in $args) {
    if ($a -eq "-f" -or $a -eq "--force") { $Force = $true }
    elseif ($a -eq "--test") { $Test = $true }
    elseif ($a -eq "--qa") { $Qa = $true }
    elseif ($a -eq "--qc") { $Qc = $true }
    elseif ($a -eq "-h" -or $a -eq "--help") { $Help = $true }
    else { $posArgs += $a }
}
if (-not $VersionArg -and $posArgs.Count -gt 0) { $VersionArg = $posArgs[0] }

if ($Help) {
    Write-Host @"
Usage: .\release-rc.ps1 [options] <version|major|minor|patch>

Options:
  -Force         Force rebuild even if build files exist
  -Test          Build for TEST (only APK, adds -test suffix)
  -Qa            Build for QA (only APK, adds -qa suffix)
  -Qc            Build for QC (only APK, adds -qc suffix)
  -Help          Show help

Examples:
  .\release-rc.ps1 patch           # 1.0.0 -> 1.0.1-rc (APK + AAB)
  .\release-rc.ps1 -Test patch     # 1.0.0 -> 1.0.1-test (Only APK)
  .\release-rc.ps1 -Qa minor      # 1.0.0 -> 1.1.0-qa (Only APK)
  .\release-rc.ps1 1.2.3           # Create v1.2.3-rc

Environment: GITHUB_TOKEN (or in scripts/.env)
"@
    exit 0
}

if (-not $VersionArg) {
    Write-Err "Usage: .\release-rc.ps1 [options] <version|major|minor|patch>. Use -Help for help."
}

$BuildType = "RC"
if ($Test) { $BuildType = "TEST" }
elseif ($Qa) { $BuildType = "QA" }
elseif ($Qc) { $BuildType = "QC" }

Load-EnvFile
if (-not $env:GITHUB_TOKEN) { Write-Err "GITHUB_TOKEN environment variable is required." }

$current = Get-CurrentVersion
Write-Info "Current version: $($current.Name) (code: $($current.Code))"

$newVersionName = ""
$newVersionCode = 0

if ($VersionArg -match '^(major|minor|patch)$') {
    $newVersionName = Bump-Version -Current $current.Name -BumpType $VersionArg
    $newVersionCode = $current.Code + 1
} else {
    $newVersionName = $VersionArg
    Test-VersionFormat $newVersionName
    $newVersionCode = $current.Code + 1
    if ($BuildType -ne "RC" -and $newVersionName -eq $current.Name) {
        Write-Info "Test build with existing version name $newVersionName. Incrementing versionCode: $($current.Code) -> $newVersionCode"
    }
}

$versionSuffix = ""
$tagName = ""
if ($BuildType -eq "RC") {
    $tagName = "v$newVersionName-rc"
} else {
    $versionSuffix = "-$($BuildType.ToLower())"
    $tagName = "v$newVersionName$versionSuffix"
}

Write-Info "Build type: $BuildType"
Write-Info "New version base: $newVersionName (code: $newVersionCode)"
if ($versionSuffix) { Write-Info "Version suffix: $versionSuffix" }
Write-Info "Tag name: $tagName"

$status = git status --porcelain 2>$null
if ($status -and ($status | Where-Object { $_ -notmatch 'app/build/' })) {
    Write-Err "You have uncommitted changes. Please commit or stash them first."
}

Write-Info "Checking if tag exists on remote..."
git fetch --tags --quiet 2>$null
if (git ls-remote --tags origin $tagName 2>$null) {
    Write-Warn "Tag $tagName already exists. Will delete and recreate..."
    git push origin --delete $tagName 2>$null
}
if (git rev-parse -q --verify "refs/tags/$tagName" 2>$null) {
    git tag -d $tagName 2>$null
}

Write-Info "`nUpdating app/build.gradle.kts..."
Set-Version -Name $newVersionName -Code $newVersionCode

$buildResult = Build-Release -BuildType $BuildType -VersionSuffix $versionSuffix

Write-Info "`nCommitting version change..."
git add app/build.gradle.kts 2>$null
$hasCommit = $false
$diff = git diff --cached -- app/build.gradle.kts 2>$null
if ($diff) {
    git commit -m "chore: bump version to $newVersionName (code: $newVersionCode) [$BuildType]"
    $hasCommit = $true
} else {
    Write-Warn "No version changes detected. Skipping commit."
}

Write-Info "`nCreating git tag $tagName..."
git tag -a $tagName -m "$BuildType build $newVersionName"

Write-Info "`nPushing commit and tag to GitHub..."
if ($hasCommit) { git push origin HEAD }
git push origin $tagName

Start-Sleep -Seconds 2

Create-GitHubRelease -TagName $tagName -VersionName "$newVersionName$versionSuffix" `
    -Token $env:GITHUB_TOKEN -ApkFile $buildResult.Apk -AabFile $buildResult.Aab -BuildType $BuildType

Invoke-WorkflowDispatch -TagName $tagName -Token $env:GITHUB_TOKEN -BuildType $BuildType

Write-Info "`nSuccessfully created $BuildType release $tagName!"
