<#
.SYNOPSIS
    Tạo production release (không phải RC).
.DESCRIPTION
    Bump version, build APK+AAB, commit, tag, push. Tag không có suffix (-rc, -test).
.PARAMETER VersionArg
    major|minor|patch hoặc version cụ thể (vd: 1.2.3).
.PARAMETER Force
    Xóa tag cũ và rebuild nếu tag đã tồn tại.
.EXAMPLE
    .\release.ps1 patch
    .\release.ps1 2.0.0
    .\release.ps1 1.0.0 -Force
#>
param(
    [Parameter(Mandatory=$true, Position=0)]
    [string]$VersionArg,
    [switch]$Force
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RootDir = Split-Path -Parent $ScriptDir
$BuildGradle = Join-Path $RootDir "app\build.gradle.kts"

function Write-Info { param($m) Write-Host $m -ForegroundColor Green }
function Write-Warn { param($m) Write-Host $m -ForegroundColor Yellow }
function Write-Err { param($m) Write-Host "Error: $m" -ForegroundColor Red; exit 1 }

function Get-CurrentVersion {
    $content = Get-Content $BuildGradle -Raw
    if ($content -match 'versionName\s*=\s*"([^"]+)"') { $vn = $Matches[1] } else { Write-Err "versionName not found" }
    if ($content -match 'versionCode\s*=\s*(\d+)') { $vc = $Matches[1] } else { Write-Err "versionCode not found" }
    return @{ Name = $vn; Code = [int]$vc }
}

function Get-BumpVersion { param($cur, $type)
    $p = $cur -split '\.'
    $patch = $p[2] -replace '-.*',''
    switch ($type) {
        "major" { return "$([int]$p[0]+1).0.0" }
        "minor" { return "$($p[0]).$([int]$p[1]+1).0" }
        "patch" { return "$($p[0]).$($p[1]).$([int]$patch+1)" }
        default { Write-Err "Invalid bump: $type" }
    }
}

function Test-VersionFormat { param($v)
    if ($v -notmatch '^\d+\.\d+\.\d+(-[a-zA-Z0-9.-]+)?(\+[a-zA-Z0-9.-]+)?$') {
        Write-Err "Invalid version format: $v"
    }
}

function Set-Version { param($name, $code)
    $content = Get-Content $BuildGradle -Raw
    $content = $content -replace '(versionName\s*=\s*")[^"]+(")', "`${1}$name`$2"
    $content = $content -replace '(versionCode\s*=\s*)\d+', "`${1}$code"
    Set-Content $BuildGradle -Value $content -NoNewline
}

$current = Get-CurrentVersion
Write-Info "Current version: $($current.Name) (code: $($current.Code))"

if ($VersionArg -match '^(major|minor|patch)$') {
    $newName = Get-BumpVersion $current.Name $VersionArg
    $newCode = $current.Code + 1
} else {
    Test-VersionFormat $VersionArg
    $newName = $VersionArg
    $newCode = $current.Code + 1
}

Write-Info "New version: $newName (code: $newCode)"

if (git status --porcelain 2>$null) {
    Write-Err "You have uncommitted changes. Commit or stash first."
}

$tagName = "v$newName"
if (git rev-parse -q "refs/tags/$tagName" 2>$null) {
    if ($Force) {
        Write-Warn "Tag $tagName exists. Removing (force)..."
        git tag -d $tagName 2>$null
        git push origin --delete $tagName 2>$null
    } else {
        Write-Err "Tag $tagName exists. Use -Force to rebuild."
    }
}

Write-Info "`nUpdating app/build.gradle.kts..."
Set-Version $newName $newCode

Write-Info "`nCommitting version change..."
Set-Location $RootDir
git add app/build.gradle.kts
git commit -m "chore: bump version to $newName (code: $newCode)"

Write-Info "`nCreating tag $tagName..."
git tag -a $tagName -m "Release v$newName"

Write-Info "`nPushing to GitHub..."
git push origin HEAD
git push origin $tagName

Write-Info "`nSuccessfully released $tagName!"
Write-Info "  Tag pushed: $tagName"
Write-Info "  This will trigger the GitHub Actions build workflow."
