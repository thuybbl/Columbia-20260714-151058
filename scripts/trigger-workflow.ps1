<#
.SYNOPSIS
    Kích hoạt GitHub Actions workflow dispatch.
.DESCRIPTION
    Gọi GitHub API để trigger workflow release-rc.yml với inputs (tag_name, build_type).
.PARAMETER TagName
    Tên tag Git (vd: v1.1.9-rc).
.PARAMETER Branch
    Branch để trigger (mặc định: branch hiện tại).
.PARAMETER BuildType
    RC, TEST, QA, QC (tự động detect từ tag nếu không chỉ định).
.EXAMPLE
    .\trigger-workflow.ps1 v1.1.9-rc
    .\trigger-workflow.ps1 v1.1.9-rc -Branch main
    .\trigger-workflow.ps1 v1.1.9-test -BuildType TEST
#>
param(
    [Parameter(Mandatory=$true, Position=0)]
    [string]$TagName,
    [Parameter(Position=1)]
    [string]$Branch = "",
    [Parameter(Position=2)]
    [ValidateSet("RC","TEST","QA","QC")]
    [string]$BuildType = ""
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RootDir = Split-Path -Parent $ScriptDir

function Write-Info { param($m) Write-Host $m -ForegroundColor Green }
function Write-Warn { param($m) Write-Host $m -ForegroundColor Yellow }
function Write-Err { param($m) Write-Host "Error: $m" -ForegroundColor Red; exit 1 }

function Load-EnvFile {
    $envFile = Join-Path $ScriptDir ".env"
    if (Test-Path $envFile) {
        Get-Content $envFile | ForEach-Object {
            if ($_ -match '^\s*#') { return }
            if ($_ -match '^\s*([A-Za-z_][A-Za-z0-9_]*)=(.*)$') {
                $key = $matches[1]
                $val = $matches[2].Trim().Trim('"',"'")
                [Environment]::SetEnvironmentVariable($key, $val, "Process")
            }
        }
    }
}

Load-EnvFile

if (-not $env:GITHUB_TOKEN) { Write-Err "GITHUB_TOKEN not found. Set it in scripts\.env or environment" }
if (-not $Branch) { $Branch = (git rev-parse --abbrev-ref HEAD 2>$null).Trim() }
if (-not $BuildType) {
    if ($TagName -match "-test$") { $BuildType = "TEST" }
    elseif ($TagName -match "-qa$") { $BuildType = "QA" }
    elseif ($TagName -match "-qc$") { $BuildType = "QC" }
    else { $BuildType = "RC" }
}

$WorkflowFile = "release-rc.yml"
$remoteUrl = git remote get-url origin 2>$null
if ($remoteUrl -match 'github\.com[:/]([^/]+/[^/.]+)') { $Repo = $Matches[1] -replace '\.git$','' }
else { Write-Err "Could not determine repository name" }

Write-Info "Triggering workflow dispatch..."
Write-Info "  Tag: $TagName"
Write-Info "  Branch: $Branch"
Write-Info "  Build Type: $BuildType"
Write-Info "  Workflow: $WorkflowFile"
Write-Info "Repository: $Repo"
Write-Host ""

$headers = @{
    "Authorization" = "Bearer $env:GITHUB_TOKEN"
    "Accept" = "application/vnd.github.v3+json"
}
$body = @{
    ref = $Branch
    inputs = @{
        tag_name = $TagName
        build_type = $BuildType
    }
} | ConvertTo-Json

try {
    $r = Invoke-RestMethod -Uri "https://api.github.com/repos/$Repo/actions/workflows/$WorkflowFile/dispatches" `
        -Method Post -Headers $headers -Body $body -ContentType "application/json"
} catch {
    $code = $_.Exception.Response.StatusCode.value__
    if ($code -eq 403) {
        Write-Err "HTTP 403 - Permission denied. Add 'workflow' scope to GITHUB_TOKEN or 'Actions: Write' for fine-grained token."
    } elseif ($code -eq 404) {
        Write-Err "HTTP 404 - Workflow '$WorkflowFile' not found on branch '$Branch'."
    } else {
        Write-Err "HTTP $code - $($_.Exception.Message)"
    }
}

Write-Info "Workflow dispatch triggered successfully!"
Write-Info ""
Write-Info "Workflow details:"
Write-Info "  Tag: $TagName"
Write-Info "  Branch: $Branch"
Write-Info "  Workflow: $WorkflowFile"
Write-Info ""
Write-Info "View runs: https://github.com/$Repo/actions"
