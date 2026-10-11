@echo off
chcp 65001 >nul 2>&1
title Nguyễn's AI - Trợ Lý Điều Khiển Máy Tính Windows (Gemini Edition)
cd /d "%~dp0"

echo ==================================================================
echo   NGUYỄN'S AI - GEMINI WINDOWS COPILOT (10 FPS LIÊN TỤC)
echo   Điều khiển máy tính thật bằng chuột vật lý và bàn phím thật
echo ==================================================================
echo.
echo Đang chuẩn bị môi trường và khởi động Command Prompt...
echo (Lưu ý: Nếu muốn dùng giao diện Web, hãy chạy tệp 'web.bat')
echo.

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0NguyeensCLI.ps1"
if %ERRORLEVEL% NEQ 0 (
    powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "NguyeensCLI.ps1"
)

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo [LƯU Ý] Quá trình kết thúc với mã: %ERRORLEVEL%
)

echo.
echo Nguyễn's AI đã dừng. Bấm phím bất kỳ để đóng cửa sổ này.
pause >nul
