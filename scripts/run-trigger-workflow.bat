@echo off
REM Launcher for trigger-workflow.ps1 - Windows batch
cd /d "%~dp0"
powershell -ExecutionPolicy Bypass -File "%~dp0trigger-workflow.ps1" %*
