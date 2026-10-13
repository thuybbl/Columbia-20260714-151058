@echo off
REM Launcher for release.ps1 - Windows batch
cd /d "%~dp0"
powershell -ExecutionPolicy Bypass -File "%~dp0release.ps1" %*
