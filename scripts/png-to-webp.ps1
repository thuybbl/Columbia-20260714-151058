<#
.SYNOPSIS
  Convert all .png files under the project (or a given directory) to .webp using cwebp.

.DESCRIPTION
  Requires cwebp in PATH (e.g. install WebP from https://developers.google.com/speed/webp/download
  or use a package manager that provides cwebp).

  By default PNG sources are removed after a successful conversion. Under Android res/, PNG
  removal is always enforced to avoid duplicate drawable names.

  The script refuses to run unless the git working tree is clean (commit or stash first) so
  you can roll back with git checkout or git reset.

.PARAMETER Root
  Directory to search (default: repo root = parent of scripts/)

.PARAMETER Quality
  WebP quality 0-100 (default: 85)

.PARAMETER Keep
  Keep original .png files (not recommended under res/)

.PARAMETER DryRun
  Print actions only (skips git clean check)

.PARAMETER Force
  Run even if git working tree is not clean

.EXAMPLE
  git add -A; git commit -m "chore: checkpoint before png-to-webp"
  .\scripts\png-to-webp.ps1
#>

param(
    [string] $Root = "",
    [ValidateRange(0, 100)]
    [int] $Quality = 85,
    [switch] $Keep,
    [switch] $Replace,
    [switch] $DryRun,
    [switch] $Force
)

$ErrorActionPreference = "Stop"

function Test-ShouldRemovePng {
    param([string] $PngPath)
    if ($PngPath -match "[\\/]res[\\/]") { return $true }
    return -not $Keep
}

function Assert-CleanGit {
    param([string] $ProjectRoot)

    if ($DryRun -or $Force) { return }

    Push-Location $ProjectRoot
    try {
        $inside = git rev-parse --is-inside-work-tree 2>$null
        if ($inside -ne "true") {
            throw "Not a git repository. Commit checkpoints are required for rollback. Use -Force to override."
        }

        $status = git status --porcelain
        if ($status) {
            Write-Host "Error: Git working tree is not clean." -ForegroundColor Red
            Write-Host ""
            Write-Host "This script deletes PNG files after conversion. Commit first so you can roll back:"
            Write-Host '  git add -A; git commit -m "chore: checkpoint before png-to-webp"'
            Write-Host "  .\scripts\png-to-webp.ps1"
            Write-Host ""
            Write-Host "Rollback if needed:"
            Write-Host "  git checkout -- .          # undo uncommitted conversion"
            Write-Host "  git reset --hard HEAD~1    # restore pre-checkpoint state"
            Write-Host ""
            Write-Host "Use -DryRun to preview without changes, or -Force to skip this check."
            exit 1
        }

        $head = git rev-parse --short HEAD
        Write-Host "Git working tree is clean — rollback checkpoint: $head"
    }
    finally {
        Pop-Location
    }
}

$cwebp = Get-Command cwebp -ErrorAction SilentlyContinue
if (-not $cwebp) {
    Write-Error "cwebp not found in PATH. Install WebP tools and ensure cwebp is available."
}

# -Replace kept for backward compatibility; default is already to remove PNGs outside -Keep
if ($Replace) { $Keep = $false }

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Resolve-Path (Join-Path $scriptDir "..")
$searchRoot = if ($Root) { (Resolve-Path $Root).Path } else { $projectRoot.Path }

$resInScope = ($searchRoot -match "[\\/]res([\\/]|$)")
if (-not $resInScope) {
    $skipRegex = '(\\|/)(\.git|build|\.gradle|\.idea)(\\|/)'
    $resInScope = [bool](Get-ChildItem -Path $searchRoot -Recurse -File -Filter "*.png" -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notmatch $skipRegex -and $_.FullName -match "[\\/]res[\\/]" } |
        Select-Object -First 1)
}

if ($resInScope -and $Keep) {
    Write-Warning "--Keep under res/ leaves duplicate drawable names (png + webp)."
    Write-Warning "Android resource merge will fail. Omit -Keep for res/ migrations."
    Write-Host ""
}

Assert-CleanGit -ProjectRoot $projectRoot.Path

$skipRegex = '(\\|/)(\.git|build|\.gradle|\.idea)(\\|/)'
$pngs = Get-ChildItem -Path $searchRoot -Recurse -File -Filter "*.png" |
    Where-Object { $_.FullName -notmatch $skipRegex }
$count = 0

foreach ($png in $pngs) {
    $webpPath = [System.IO.Path]::ChangeExtension($png.FullName, ".webp")
    $remove = Test-ShouldRemovePng -PngPath $png.FullName

    if ($DryRun) {
        Write-Host "Would: cwebp -q $Quality `"$($png.FullName)`" -o `"$webpPath`""
        if ($remove) { Write-Host "Would: Remove-Item `"$($png.FullName)`"" }
    }
    else {
        & cwebp -quiet -q $Quality $png.FullName -o $webpPath
        if (-not (Test-Path -LiteralPath $webpPath) -or (Get-Item -LiteralPath $webpPath).Length -eq 0) {
            Write-Error "Failed to convert: $($png.FullName)"
        }
        if ($remove) {
            Remove-Item -LiteralPath $png.FullName -Force
        }
    }
    $count++
}

Write-Host "Done. Converted $count file(s) under: $searchRoot"
if (-not $DryRun -and -not $Force) {
    Write-Host "Review changes, then commit or rollback with: git checkout -- ."
}
