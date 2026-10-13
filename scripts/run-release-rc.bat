@echo off
REM Launcher for release-rc.ps1 - Windows batch
cd /d "%~dp0"
powershell -ExecutionPolicy Bypass -File "%~dp0release-rc.ps1" %*
