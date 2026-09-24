@echo off
title Update saket Streams Addon
cd /d "%~dp0"

echo ============================================================
echo   🔄 Updating saket Streams Addon (Git Pull + Rebuild)
echo ============================================================
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0pipeline\update.ps1"
echo.
pause
