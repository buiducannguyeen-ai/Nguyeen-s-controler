@echo off
chcp 65001 >nul 2>&1
title Nguyễn's AI - Trợ Lý Điều Khiển Máy Tính Windows (Web Mode)
cd /d "%~dp0"

echo Đang khởi động giao diện Web tại http://127.0.0.1:8765/ ...
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0NguyeensAI.ps1"
if %ERRORLEVEL% NEQ 0 (
    powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "NguyeensAI.ps1"
)

echo.
echo Nguyễn's AI đã dừng. Bấm phím bất kỳ để đóng.
pause >nul