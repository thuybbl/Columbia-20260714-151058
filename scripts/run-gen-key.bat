@echo off
REM Launcher for gen-key.ps1 - Windows batch
cd /d "%~dp0"
powershell -ExecutionPolicy Bypass -File "%~dp0gen-key.ps1" %*
