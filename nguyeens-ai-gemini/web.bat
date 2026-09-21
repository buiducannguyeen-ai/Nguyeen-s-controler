@echo off
title Nguyeen's AI - Web Interface Mode
chcp 65001 >nul 2>&1
cd /d "%~dp0"

echo Dang khoi dong giao dien Web tai http://127.0.0.1:8765/ ...
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0NguyeensAI.ps1"

echo.
echo Da dung chuong trinh. Bam phim bat ky de dong.
pause >nul