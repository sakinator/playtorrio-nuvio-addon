# Pipeline script to update scrapers from PlayTorrioV3
Set-Location -Path "$PSScriptRoot\.."

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " 🔄 PlayTorrio Upstream Scraper Update Pipeline" -ForegroundColor Magenta
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

# 2. Fetch and Pull from Upstream
Write-Host "`n[1/3] Checking for upstream updates from PlayTorrioV3..." -ForegroundColor Yellow
Push-Location "upstream\PlayTorrioV3"
try {
    $beforeHash = git rev-parse HEAD
    git fetch origin main --quiet
    $afterRemote = git rev-parse origin/main

    if ($beforeHash -eq $afterRemote) {
        Write-Host "  -> Already up-to-date with upstream (commit: $beforeHash)" -ForegroundColor Green
    } else {
        Write-Host "  -> New commits found! Pulling updates..." -ForegroundColor Cyan
        git pull origin main
        $newHash = git rev-parse HEAD
        Write-Host "  -> Successfully updated to commit: $newHash" -ForegroundColor Green
    }
} catch {
    Write-Host "  -> Git pull error: $_" -ForegroundColor Red
} finally {
    Pop-Location
}

# 3. Regenerate Scraper Registry
Write-Host "`n[2/3] Scanning scraper sites and regenerating registry..." -ForegroundColor Yellow
& $dartExe run tool/generate_registry.dart
if ($LASTEXITCODE -eq 0) {
    Write-Host "  -> Scraper registry updated successfully." -ForegroundColor Green
} else {
    Write-Host "  -> Failed to generate scraper registry." -ForegroundColor Red
}

# 4. Notify Running Server (Hot-Reload)
Write-Host "`n[3/3] Checking if addon server is running for hot-reload..." -ForegroundColor Yellow
try {
    $res = Invoke-RestMethod -Uri "http://localhost:7000/api/pipeline/update" -Method Post -TimeoutSec 5 -ErrorAction Stop
    Write-Host "  -> Addon server notified! Scrapers hot-reloaded: $($res.message)" -ForegroundColor Green
} catch {
    Write-Host "  -> Server is not currently running. Changes will be loaded automatically on next start." -ForegroundColor Gray
}

Write-Host "`n==========================================================" -ForegroundColor Cyan
Write-Host " ✅ Update Pipeline Complete!" -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Cyan
