# Test GitHub API access with token from .env
$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$EnvFile = Join-Path $ScriptDir ".env"

function Load-EnvFile {
    if (Test-Path $EnvFile) {
        Write-Host "Loading .env file..."
        Get-Content $EnvFile | ForEach-Object {
            $line = $_.Trim()
            if ($line -and -not $line.StartsWith("#") -and $line -match "^([A-Za-z_][A-Za-z0-9_]*)=(.*)$") {
                $key = $Matches[1]
                $val = $Matches[2].Trim().Trim('"', "'")
                [Environment]::SetEnvironmentVariable($key, $val, "Process")
            }
        }
    }
}

Load-EnvFile

if (-not $env:GITHUB_TOKEN) {
    Write-Host "GITHUB_TOKEN not found" -ForegroundColor Red
    exit 1
}

Write-Host "GITHUB_TOKEN loaded ($($env:GITHUB_TOKEN.Length) chars)" -ForegroundColor Green

$RemoteUrl = git remote get-url origin 2>$null
if (-not $RemoteUrl) {
    Write-Host "Could not determine repository name" -ForegroundColor Red
    exit 1
}
$Repo = ($RemoteUrl -replace ".*github\.com[:/]([^/]+/[^/]+)(\.git)?$", '$1').TrimEnd('.git')
Write-Host "Repository: $Repo"
Write-Host ""

# Test 1: Check repository access
Write-Host "Test 1: Checking repository access..."
try {
    $headers = @{
        "Authorization" = "Bearer $($env:GITHUB_TOKEN)"
        "Accept" = "application/vnd.github.v3+json"
    }
    $r = Invoke-RestMethod -Uri "https://api.github.com/repos/$Repo" -Headers $headers -Method Get
    Write-Host "Repository access: OK" -ForegroundColor Green
    Write-Host "   Full name: $($r.full_name)"
} catch {
    Write-Host "Repository access failed: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host ""

# Test 2: Check workflow access
Write-Host "Test 2: Checking workflow access..."
try {
    $wf = Invoke-RestMethod -Uri "https://api.github.com/repos/$Repo/actions/workflows/release-rc.yml" -Headers $headers -Method Get
    Write-Host "Workflow access: OK" -ForegroundColor Green
    Write-Host "   Workflow name: $($wf.name)"
} catch {
    if ($_.Exception.Response.StatusCode.value__ -eq 404) {
        Write-Host "Workflow not found (HTTP 404)" -ForegroundColor Yellow
        Write-Host "   This is OK if workflow doesn't exist on current branch"
    } else {
        Write-Host "Workflow access failed: $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "All tests completed!" -ForegroundColor Green
