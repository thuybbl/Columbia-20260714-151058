@echo off
REM Launcher for recreate-release.ps1 - Windows batch
cd /d "%~dp0"
powershell -ExecutionPolicy Bypass -File "%~dp0recreate-release.ps1" %*
