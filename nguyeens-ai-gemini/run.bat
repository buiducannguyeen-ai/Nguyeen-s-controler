@echo off
title Nguyeen's AI - Gemini Windows Copilot (Command Prompt Mode)
chcp 65001 >nul 2>&1
cd /d "%~dp0"

echo ==================================================================
echo   NGUYEN'S AI - GEMINI WINDOWS COPILOT (10 FPS LIEN TUC)
echo   Dieu khien may tinh that bang chuot vat ly va ban phim that
echo ==================================================================
echo.
echo Dang khoi dong che do Command Prompt truc tiep...
echo (Luu y: Neu muon dung giao dien Web, hay chay tep 'web.bat')
echo.

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0NguyeensCLI.ps1"

echo.
echo Nguyeen's AI da dung. Bam phim bat ky de dong cua so nay.
pause >nul
