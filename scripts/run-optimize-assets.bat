@echo off
REM Launcher for optimize-assets.ps1 - Windows batch
cd /d "%~dp0"
powershell -ExecutionPolicy Bypass -File "%~dp0optimize-assets.ps1"
