@echo off
REM Launcher for test-github-api.ps1 - Windows batch
cd /d "%~dp0"
powershell -ExecutionPolicy Bypass -File "%~dp0test-github-api.ps1"
