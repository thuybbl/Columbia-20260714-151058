@echo off
REM Launcher for gen-github-secrets.ps1 - Windows batch
cd /d "%~dp0"
powershell -ExecutionPolicy Bypass -File "%~dp0gen-github-secrets.ps1" %*
