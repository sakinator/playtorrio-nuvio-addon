@echo off
title Update HostHound Addon
cd /d "%~dp0"

echo ============================================================
echo   🐕 Updating HostHound Addon (Git Pull + Rebuild)
echo ============================================================
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0pipeline\update.ps1"
echo.
pause
