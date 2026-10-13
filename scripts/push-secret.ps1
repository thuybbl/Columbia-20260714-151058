# Sync GitHub Actions secrets/variables from scripts/.env (section-based format).
# Run from repo root or scripts folder:  .\scripts\push-secret.ps1
# Requires: GitHub CLI (gh) in PATH, authenticated: gh auth login
# .env format:
#   # secret
#   KEY=value
#   # var
#   KEY=value

#Requires -Version 5.1

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$EnvFile = Join-Path $ScriptDir ".env"

if (-not (Test-Path -LiteralPath $EnvFile)) {
    Write-Host "Lỗi: Không tìm thấy file .env tại $EnvFile" -ForegroundColor Red
    exit 1
}

$ghRepoJson = & gh repo view --json nameWithOwner -q .nameWithOwner 2>$null
if ([string]::IsNullOrWhiteSpace($ghRepoJson)) {
    Write-Host "Lỗi: Không xác định được repo GitHub. Chạy trong thư mục clone và đăng nhập: gh auth login" -ForegroundColor Red
    exit 1
}

$CurrentRepo = $ghRepoJson.Trim()
Write-Host "🚀 Đang bắt đầu đồng bộ Secret và Variable lên GitHub ($CurrentRepo)..."
Write-Host "   Định dạng .env: khối # secret rồi KEY=VALUE; khối # var rồi KEY=VALUE"

function Unquote-EnvValue {
    param([string]$Value)
    if ($Value.Length -ge 2) {
        if ($Value.StartsWith('"') -and $Value.EndsWith('"')) {
            return $Value.Substring(1, $Value.Length - 2)
        }
        if ($Value.StartsWith("'") -and $Value.EndsWith("'")) {
            return $Value.Substring(1, $Value.Length - 2)
        }
    }
    return $Value
}

function Join-ProcessArguments {
    param([string[]]$Parts)
    ($Parts | ForEach-Object {
        $p = $_
        if ($null -eq $p) { return '""' }
        if ($p -match '[\s"]') { return '"' + ($p -replace '"', '\"') + '"' }
        return $p
    }) -join ' '
}

function Set-GhSecretFromStdin {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$Repo,
        [Parameter(Mandatory)][string]$Body
    )
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "gh"
    $psi.Arguments = Join-ProcessArguments @("secret", "set", $Name, "--repo", $Repo)
    $psi.UseShellExecute = $false
    $psi.RedirectStandardInput = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true

    $p = New-Object System.Diagnostics.Process
    $p.StartInfo = $psi
    if (-not $p.Start()) {
        throw "Không chạy được gh (đã cài và thêm vào PATH chưa?)"
    }
    # UTF-8 không BOM qua stdin (tương thích .NET Framework / Windows PowerShell 5.1)
    $utf8 = New-Object System.Text.UTF8Encoding $false
    $bytes = $utf8.GetBytes($Body)
    $p.StandardInput.BaseStream.Write($bytes, 0, $bytes.Length)
    $p.StandardInput.Close()
    $stderr = $p.StandardError.ReadToEnd()
    $stdout = $p.StandardOutput.ReadToEnd()
    $p.WaitForExit()
    if ($p.ExitCode -ne 0) {
        throw "gh secret set ${Name}: $stderr"
    }
}

$script:mode = $null
Get-Content -LiteralPath $EnvFile -Encoding UTF8 | ForEach-Object {
    $line = $_
    $stripped = $line.Trim()
    if ([string]::IsNullOrWhiteSpace($stripped)) {
        return
    }

    if ($stripped.StartsWith("#")) {
        $rest = $stripped.Substring(1).Trim().ToLowerInvariant()
        if ($rest -eq "secret") {
            $script:mode = "secret"
            return
        }
        if ($rest -eq "var" -or $rest -eq "variable") {
            $script:mode = "var"
            return
        }
        return
    }

    if ($stripped.IndexOf("=") -lt 0) {
        return
    }

    if (-not $script:mode) {
        Write-Host "⚠️  Bỏ qua (đặt dòng này sau # secret hoặc # var): $stripped" -ForegroundColor Yellow
        return
    }

    $eq = $stripped.IndexOf("=")
    $key = $stripped.Substring(0, $eq).Trim()
    $value = $stripped.Substring($eq + 1)
    if ([string]::IsNullOrWhiteSpace($key)) {
        return
    }

    $value = Unquote-EnvValue $value

    $placeholders = @('', 'ghp_your_token_here', 'your_token_here', 'changeme', 'TODO', 'xxx', 'XXX')
    if ([string]::IsNullOrWhiteSpace($value) -or $placeholders -contains $value) {
        Write-Host "⏭️  Bỏ qua $key (rỗng/placeholder — không đè org)" -ForegroundColor Yellow
        return
    }
    $orgKeys = @(
        'GITHUB_TOKEN','GITHUB_ACTOR','GH_PACKAGES_TOKEN','NV_ACTOR','NV_TOKEN',
        'NEXUS_URL','NEXUS_USER','NEXUS_PASS','NEXUS_RAW_REPO','NEXUS_USERNAME','NEXUS_PASSWORD',
        'NEXUS_USERNAME_PROD','NEXUS_PASSWORD_PROD',
        'DISCORD_WEBHOOK_URL','DISCORD_USER_IDS','DISCORD_RELEASE_MANAGER_IDS',
        'PLAY_DEPLOY_BOT_URL','PLAY_DEPLOY_NOTIFY_TOKEN','DISCORD_DEPLOY_WEBHOOK_URL'
    )
    if ($orgKeys -contains $key) {
        Write-Host "⏭️  Bỏ qua $key (org secret af-products)" -ForegroundColor Yellow
        return
    }

    if ($script:mode -eq "secret") {
        Write-Host "🔐 Đang tạo Secret: $key"
        Set-GhSecretFromStdin -Name $key -Repo $CurrentRepo -Body $value
    }
    else {
        Write-Host "📊 Đang tạo Variable: $key"
        & gh @("variable", "set", $key, "--body", $value, "--repo", $CurrentRepo)
        if ($LASTEXITCODE -ne 0) {
            throw "gh variable set $key failed (exit $LASTEXITCODE)"
        }
    }
}

Write-Host "✅ Hoàn tất! Hãy kiểm tra lại trong phần Settings > Secrets and variables của Repo." -ForegroundColor Green
