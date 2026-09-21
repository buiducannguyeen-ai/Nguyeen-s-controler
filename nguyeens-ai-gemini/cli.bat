@echo off
title Nguyeen's AI - Gemini Windows Copilot (Command Prompt Mode)
chcp 65001 >nul 2>&1
cd /d "%~dp0"

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0NguyeensCLI.ps1"

echo.
echo Da dung chuong trinh. Bam phim bat ky de dong.
pause >nul