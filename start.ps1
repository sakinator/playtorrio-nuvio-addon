# PowerShell launcher for PlayTorrio HTTP Streams Addon (Windows)
Set-Location -Path $PSScriptRoot

Write-Host "===============================================================" -ForegroundColor Cyan
Write-Host "       ⚡ PlayTorrio HTTP Streams Addon for Nuvio ⚡" -ForegroundColor Magenta
Write-Host "===============================================================" -ForegroundColor Cyan
Write-Host ""

# ── Find Dart ─────────────────────────────────────────────────────────────────
$dartExe = $null
if     (Test-Path "..\dart-sdk\bin\dart.exe") { $dartExe = (Resolve-Path "..\dart-sdk\bin\dart.exe").Path }
elseif (Test-Path "dart-sdk\bin\dart.exe")    { $dartExe = (Resolve-Path "dart-sdk\bin\dart.exe").Path    }
else {
    $dartCmd = Get-Command dart -ErrorAction SilentlyContinue
    if ($dartCmd) { $dartExe = $dartCmd.Source }
}

# ── First-time setup: create lib\upstream junction + dart pub get ─────────────
if (-not (Test-Path "lib\upstream") -and $dartExe) {
    Write-Host " Running first-time setup..." -ForegroundColor Yellow
    & $dartExe run tool/setup.dart
    Write-Host ""
}

# ── Start server ──────────────────────────────────────────────────────────────
if (Test-Path "playtorrio-addon.exe") {
    Write-Host " Using compiled binary (fastest startup)..." -ForegroundColor Green
    & ".\playtorrio-addon.exe" @args
}
elseif ($dartExe) {
    Write-Host " Using dart run: $dartExe" -ForegroundColor Green
    & $dartExe run bin/server.dart @args
}
else {
    Write-Host " [ERROR] Dart SDK not found!" -ForegroundColor Red
    Write-Host "         Install from https://dart.dev/get-dart" -ForegroundColor Gray
    pause
    exit 1
}
