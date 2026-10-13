# Compress videos in assets/videos
# Usage: .\compress-videos.ps1 [quality]
# quality: high (CRF 23, 1.5Mbps) or medium (CRF 28, 1Mbps)
# Default: high

param(
    [ValidateSet("high", "medium")]
    [string]$Quality = "high"
)

$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RootDir = Split-Path -Parent $ScriptDir
$VideosDir = Join-Path $RootDir "app/src/main/assets/videos"
$BackupDir = Join-Path $RootDir "app/src/main/assets/videos_backup"

# Check ffmpeg
if (-not (Get-Command ffmpeg -ErrorAction SilentlyContinue)) {
    Write-Host "ffmpeg is not installed!" -ForegroundColor Red
    Write-Host "Install: choco install ffmpeg (Windows) or brew install ffmpeg (macOS)"
    exit 1
}

# Create backup
Write-Host "Creating backup videos..."
New-Item -ItemType Directory -Force -Path $BackupDir | Out-Null
if (Test-Path $VideosDir) {
    Copy-Item "$VideosDir/*" $BackupDir -Force
}
Write-Host "Backup saved at: $BackupDir" -ForegroundColor Green

# Set compression params
if ($Quality -eq "high") {
    $CRF = 23
    $Bitrate = "1.5M"
    $Maxrate = "2M"
    $Bufsize = "3M"
    Write-Host "Mode: HIGH QUALITY (CRF 23, 1.5Mbps)"
} else {
    $CRF = 28
    $Bitrate = "1M"
    $Maxrate = "1.5M"
    $Bufsize = "2M"
    Write-Host "Mode: MEDIUM QUALITY (CRF 28, 1Mbps) - More savings"
}

function Compress-Video {
    param([string]$InputPath)
    $filename = [System.IO.Path]::GetFileName($InputPath)
    $base = [System.IO.Path]::GetFileNameWithoutExtension($InputPath)
    $dir = Split-Path -Parent $InputPath
    $OutputPath = Join-Path $dir "${base}_compressed.mp4"

    Write-Host ""
    Write-Host "Compressing: $filename"

    # Get video info
    $width = (ffprobe -v error -select_streams v:0 -show_entries stream=width -of default=noprint_wrappers=1 $InputPath 2>$null) -replace "width=", ""
    $height = (ffprobe -v error -select_streams v:0 -show_entries stream=height -of default=noprint_wrappers=1 $InputPath 2>$null) -replace "height=", ""
    $originalSize = (Get-Item $InputPath).Length / 1MB
    Write-Host "   Original size: $([math]::Round($originalSize, 2)) MB"
    Write-Host "   Resolution: ${width}x${height}"

    & ffmpeg -i $InputPath -vcodec libx264 -crf $CRF -preset medium `
        -vf "scale=${width}:${height}" -b:v $Bitrate -maxrate $Maxrate -bufsize $Bufsize `
        -movflags +faststart -y $OutputPath 2>$null

    if ($LASTEXITCODE -eq 0) {
        $newSize = (Get-Item $OutputPath).Length / 1MB
        $reduction = [math]::Round(100 - ($newSize / $originalSize * 100), 0)
        Write-Host "   Done! New size: $([math]::Round($newSize, 2)) MB" -ForegroundColor Green
        Write-Host "   Reduction: ~${reduction}%"
    } else {
        Write-Host "   Compression error!" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "Starting video compression..."

$videos = @("video_iap.mp4", "splash.mp4", "smoke.mp4", "video_discord.mp4")
foreach ($v in $videos) {
    $p = Join-Path $VideosDir $v
    if (Test-Path $p) {
        Compress-Video $p
    }
}

Write-Host ""
Write-Host "Video compression complete!" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:"
Write-Host "   1. Check quality of compressed videos (*_compressed.mp4)"
Write-Host "   2. If OK, replace originals:"
Write-Host "      Move-Item '$VideosDir\video_iap_compressed.mp4' '$VideosDir\video_iap.mp4' -Force"
Write-Host "   3. Remove backup if not needed: Remove-Item -Recurse -Force '$BackupDir'"
Write-Host ""
Write-Host "Tip: Compare videos on phone before replacing!"
