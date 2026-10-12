@echo off
chcp 65001 >nul 2>&1
title Nguyen's AI - Windows Desktop Copilot (Web Mode)
cd /d "%~dp0"

echo Starting Web UI at http://127.0.0.1:8765/ ...
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0NguyeensAI.ps1"
if %ERRORLEVEL% NEQ 0 (
    powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "NguyeensAI.ps1"
)

echo.
echo Nguyen's AI has stopped. Press any key to close.
pause >nul