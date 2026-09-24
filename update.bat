@echo off
title Update sakinator-MegaScraper Addon
cd /d "%~dp0"

echo ============================================================
echo   🔄 Updating sakinator-MegaScraper Addon (Git Pull + Rebuild)
echo ============================================================
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0pipeline\update.ps1"
echo.
pause
