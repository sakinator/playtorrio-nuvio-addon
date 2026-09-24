@echo off
title PlayTorrio HTTP Streams Addon for Nuvio
cd /d "%~dp0"

echo ===============================================================
echo        PlayTorrio HTTP Streams Addon for Nuvio
echo ===============================================================
echo.

:: ── Find Dart ──────────────────────────────────────────────────────────────
set DART_EXE=
if exist "..\dart-sdk\bin\dart.exe" (
    set "DART_EXE=..\dart-sdk\bin\dart.exe"
) else if exist "dart-sdk\bin\dart.exe" (
    set "DART_EXE=dart-sdk\bin\dart.exe"
) else (
    where dart >nul 2>nul
    if %errorlevel% equ 0 (
        set "DART_EXE=dart"
    )
)

:: ── First-time setup (creates lib\upstream junction + dart pub get) ─────────
if not exist "lib\upstream" (
    if defined DART_EXE (
        echo Running first-time setup...
        "%DART_EXE%" run tool/setup.dart
        echo.
    )
)

:: ── Start server ─────────────────────────────────────────────────────────────
if exist "playtorrio-addon.exe" (
    echo Using compiled binary (fastest^)...
    "playtorrio-addon.exe" %*
    goto end
)

if not defined DART_EXE (
    echo [ERROR] Dart SDK not found! Install from https://dart.dev/get-dart
    pause
    exit /b 1
)

echo Using dart run...
"%DART_EXE%" run bin/server.dart %*

:end
pause
