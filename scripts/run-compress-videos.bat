@echo off
REM Launcher for compress-videos.ps1 - Windows batch
cd /d "%~dp0"
powershell -ExecutionPolicy Bypass -File "%~dp0compress-videos.ps1" %*
