# Analyze assets and provide optimization recommendations to reduce APK size
# Usage: .\optimize-assets.ps1

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RootDir = Split-Path -Parent $ScriptDir
$DrawablePath = Join-Path $RootDir "app/src/main/res/drawable"
$AssetsPath = Join-Path $RootDir "app/src/main/assets"

Write-Host "Analyzing asset sizes..." -ForegroundColor Cyan
Write-Host ""

Write-Host "Top 10 largest files in res/drawable:" -ForegroundColor Cyan
if (Test-Path $DrawablePath) {
    Get-ChildItem $DrawablePath -Recurse -File |
        Select-Object @{N='Size';E={$_.Length}}, FullName |
        Sort-Object Size -Descending |
        Select-Object -First 10 |
        ForEach-Object {
            $size = if ($_.Size -gt 1MB) { "{0:N2} MB" -f ($_.Size/1MB) } else { "{0:N0} KB" -f ($_.Size/1KB) }
            Write-Host "  $size - $($_.FullName)"
        }
} else {
    Write-Host "  No drawable folder found"
}

Write-Host ""
Write-Host "Assets folder size:" -ForegroundColor Cyan
if (Test-Path $AssetsPath) {
    $total = (Get-ChildItem $AssetsPath -Recurse -File | Measure-Object -Property Length -Sum).Sum
    Write-Host "  $([math]::Round($total/1MB, 2)) MB total"
    Write-Host ""
    Write-Host "  Details:"
    Get-ChildItem $AssetsPath -Directory | ForEach-Object {
        $size = (Get-ChildItem $_.FullName -Recurse -File | Measure-Object -Property Length -Sum).Sum
        Write-Host "    $($_.Name): $([math]::Round($size/1MB, 2)) MB"
    }
} else {
    Write-Host "  No assets folder"
}

Write-Host ""
Write-Host "Files to optimize:" -ForegroundColor Green
Write-Host ""
Write-Host "1. Videos (~29MB):"
Write-Host "   app/src/main/assets/videos/*.mp4"
Write-Host "   -> Recommendation: Compress with ffmpeg or stream from server"
Write-Host ""
Write-Host "2. Large GIF files:"
Write-Host "   ic_gif_ob_2.gif (3.6MB), ic_gif_ob_1.gif (2.2MB)"
Write-Host "   -> Recommendation: Compress or convert to WebP"
Write-Host ""
Write-Host "3. Large PNG files:"
Write-Host "   da027b12e6eb1fe4ee19023876921b77ad2a05fe.png (2.2MB)"
Write-Host "   ic_onboarding_*.png (500KB-760KB)"
Write-Host "   -> Recommendation: Convert to WebP at 80-85% quality"
Write-Host ""
Write-Host "4. Sounds (2.4MB):"
Write-Host "   29 MP3 files"
Write-Host "   -> Recommendation: Encode at lower bitrate (64-96kbps)"
Write-Host ""
Write-Host "Tips:" -ForegroundColor Yellow
Write-Host "  Compress video: ffmpeg -i input.mp4 -vcodec libx264 -crf 28 -preset slow -vf scale=1920:1080 output.mp4"
Write-Host "  PNG to WebP: cwebp -q 85 input.png -o output.webp"
Write-Host "  Compress MP3: ffmpeg -i input.mp3 -b:a 64k output.mp3"
Write-Host ""
