@echo off
title Stop Nguyen's AI
cd /d "%~dp0"

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "try { Invoke-RestMethod -Method Post -Uri 'http://127.0.0.1:8765/api/stop' -TimeoutSec 2 | Out-Null } catch { $p='%~dp0data\worker.pid'; if(Test-Path $p){ $id=[int](Get-Content $p); Stop-Process -Id $id -Force -ErrorAction SilentlyContinue } }"

echo.
echo [OK] Stop command sent to Nguyen's AI.
timeout /t 2 >nul