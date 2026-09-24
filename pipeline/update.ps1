# Pipeline script to update saket Streams Addon
Set-Location -Path "$PSScriptRoot\.."

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " 🔄 saket Streams Addon Update & Pull Pipeline" -ForegroundColor Magenta
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. Locate Dart SDK
$dartExe = $null
if (Test-Path "..\dart-sdk\bin\dart.exe") {
    $dartExe = (Resolve-Path "..\dart-sdk\bin\dart.exe").Path
} elseif (Test-Path "dart-sdk\bin\dart.exe") {
    $dartExe = (Resolve-Path "dart-sdk\bin\dart.exe").Path
} else {
    $dartCmd = Get-Command dart -ErrorAction SilentlyContinue
    if ($dartCmd) {
        $dartExe = $dartCmd.Source
    }
}

if (-not $dartExe) {
    Write-Host "[ERROR] Dart SDK not found!" -ForegroundColor Red
    exit 1
}

# 2. Pull updates from GitHub repository
Write-Host "`n[1/4] Pulling latest updates from GitHub..." -ForegroundColor Yellow
try {
    $pullOut = git pull origin main
    Write-Host "  -> $pullOut" -ForegroundColor Green
} catch {
    Write-Host "  -> Git pull error: $_" -ForegroundColor Red
}

# 3. Pull Upstream if present
if (Test-Path "upstream\PlayTorrioV3\.git") {
    Write-Host "`n[2/4] Checking for upstream updates from PlayTorrioV3..." -ForegroundColor Yellow
    Push-Location "upstream\PlayTorrioV3"
    try {
        git pull origin main --quiet
        Write-Host "  -> Upstream checked." -ForegroundColor Green
    } catch {
        Write-Host "  -> Upstream git pull error: $_" -ForegroundColor Gray
    } finally {
        Pop-Location
    }
} else {
    Write-Host "`n[2/4] Skipping PlayTorrioV3 submodule (standalone mode)." -ForegroundColor Gray
}

# 4. Regenerate Scraper Registry
Write-Host "`n[3/4] Scanning scraper sites and regenerating registry..." -ForegroundColor Yellow
& $dartExe run tool/generate_registry.dart
if ($LASTEXITCODE -eq 0) {
    Write-Host "  -> Scraper registry updated successfully." -ForegroundColor Green
} else {
    Write-Host "  -> Failed to generate scraper registry." -ForegroundColor Red
}

# 5. Compile binary
Write-Host "`n[4/4] Compiling updated standalone server executable..." -ForegroundColor Yellow
& $dartExe compile exe bin/server.dart -o playtorrio-addon-new.exe
if ($LASTEXITCODE -eq 0) {
    # If server is not running or can be replaced
    try {
        Move-Item -Path "playtorrio-addon-new.exe" -Destination "playtorrio-addon.exe" -Force -ErrorAction Stop
        Write-Host "  -> Successfully updated playtorrio-addon.exe!" -ForegroundColor Green
    } catch {
        Write-Host "  -> Server is currently running. Binary will be replaced on next restart." -ForegroundColor Yellow
    }
}

# 6. Notify Running Server (Hot-Reload)
try {
    $port = 7002
    $res = Invoke-RestMethod -Uri "http://localhost:$port/api/pipeline/update" -Method Post -TimeoutSec 5 -ErrorAction Stop
    Write-Host "  -> Addon server notified on port $port! Scrapers hot-reloaded: $($res.message)" -ForegroundColor Green
} catch {
    Write-Host "  -> Changes loaded. If server is running on a different port, please restart it." -ForegroundColor Gray
}

Write-Host "`n==========================================================" -ForegroundColor Cyan
Write-Host " ✅ Update Pipeline Complete!" -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Cyan
