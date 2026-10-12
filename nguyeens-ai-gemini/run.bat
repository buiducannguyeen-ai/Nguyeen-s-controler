@echo off
chcp 65001 >nul 2>&1
title Nguyen's AI - Windows Desktop Copilot (Gemini Edition)
cd /d "%~dp0"

echo ==================================================================
echo   NGUYEN'S AI - GEMINI WINDOWS COPILOT (10 FPS CONTINUOUS)
echo   Real desktop control with physical mouse and native keyboard
echo   (Vietnamese Unicode keyboard output supported)
echo ==================================================================
echo.
echo Preparing environment and starting Command Prompt...
echo (Note: For local Web GUI interface, launch 'web.bat')
echo.

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0NguyeensCLI.ps1"
if %ERRORLEVEL% NEQ 0 (
    powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "NguyeensCLI.ps1"
)

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo [NOTE] Process exited with code: %ERRORLEVEL%
)

echo.
echo Nguyen's AI has stopped. Press any key to close this window.
pause >nul
