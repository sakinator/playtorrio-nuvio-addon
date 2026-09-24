# =============================================================================
#  PlayTorrio Nuvio Addon — Windows Service Installer
#  
#  Installs the addon as a Windows Service using NSSM (Non-Sucking Service
#  Manager) so it starts automatically at boot — even before any user logs in.
#  
#  Run this script once as Administrator. After that the addon is always
#  reachable at http://<your-lan-ip>:7000 whenever your PC is on.
#
#  Requirements:
#    - Run as Administrator
#    - NSSM (downloaded automatically if not found)
#    - Dart SDK or the compiled playtorrio-addon.exe
# =============================================================================

#Requires -RunAsAdministrator

$ErrorActionPreference = "Stop"
$ProjectRoot = $PSScriptRoot | Split-Path -Parent
$ServiceName = "PlayTorrioNuvioAddon"
$ServiceDisplayName = "PlayTorrio Nuvio Addon (HTTP Stream Server)"
$ServiceDescription = "Local HTTP stream addon server for Nuvio, powered by PlayTorrio scrapers."

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  🔧 PlayTorrio Nuvio Addon — Windows Service Installer" -ForegroundColor Magenta
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

# ── 1. Locate the binary to run ──────────────────────────────────────────────

$ExePath = $null
$ExeArgs = ""

# Prefer the compiled exe (fastest startup, no dart runtime needed at run time)
$compiledExe = Join-Path $ProjectRoot "playtorrio-addon.exe"
if (Test-Path $compiledExe) {
    $ExePath = $compiledExe
    Write-Host "  → Using compiled binary: $ExePath" -ForegroundColor Green
} else {
    # Fall back to dart run
    $dartExe = $null
    $dartSdk = Join-Path $ProjectRoot "..\dart-sdk\bin\dart.exe"
    if (Test-Path $dartSdk) {
        $dartExe = (Resolve-Path $dartSdk).Path
    } else {
        $dartCmd = Get-Command dart -ErrorAction SilentlyContinue
        if ($dartCmd) { $dartExe = $dartCmd.Source }
    }
    if ($dartExe) {
        $ExePath = $dartExe
        $ExeArgs = "run bin/server.dart"
        Write-Host "  → Using dart run: $dartExe" -ForegroundColor Yellow
    } else {
        Write-Host "[ERROR] Neither playtorrio-addon.exe nor dart.exe found." -ForegroundColor Red
        Write-Host "        Build the exe first:  dart compile exe bin/server.dart -o playtorrio-addon.exe" -ForegroundColor Gray
        exit 1
    }
}

# ── 2. Get or download NSSM ──────────────────────────────────────────────────

$NssmExe = Get-Command nssm -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source -ErrorAction SilentlyContinue

if (-not $NssmExe) {
    Write-Host ""
    Write-Host "  NSSM not found on PATH. Downloading nssm 2.24..." -ForegroundColor Yellow

    $NssmDir  = Join-Path $ProjectRoot "pipeline\nssm"
    $NssmZip  = Join-Path $NssmDir "nssm.zip"
    $NssmExe  = Join-Path $NssmDir "nssm.exe"

    if (-not (Test-Path $NssmDir)) { New-Item -ItemType Directory -Path $NssmDir | Out-Null }

    if (-not (Test-Path $NssmExe)) {
        $NssmUrl = "https://nssm.cc/release/nssm-2.24.zip"
        Invoke-WebRequest -Uri $NssmUrl -OutFile $NssmZip -UseBasicParsing
        Expand-Archive -Path $NssmZip -DestinationPath $NssmDir -Force

        # nssm zip contains nssm-2.24\win64\nssm.exe
        $extracted = Get-ChildItem -Recurse $NssmDir -Filter "nssm.exe" |
                     Where-Object { $_.FullName -match "win64" } |
                     Select-Object -First 1
        if ($extracted) {
            Copy-Item $extracted.FullName $NssmExe -Force
        }
        Remove-Item $NssmZip -Force
    }

    if (-not (Test-Path $NssmExe)) {
        Write-Host "[ERROR] Failed to download NSSM. Install it manually: https://nssm.cc" -ForegroundColor Red
        exit 1
    }

    Write-Host "  → NSSM ready: $NssmExe" -ForegroundColor Green
}

# ── 3. Remove old service if it exists ───────────────────────────────────────

$existing = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
if ($existing) {
    Write-Host ""
    Write-Host "  Removing existing service '$ServiceName'..." -ForegroundColor Yellow
    & $NssmExe stop $ServiceName 2>$null
    & $NssmExe remove $ServiceName confirm
    Start-Sleep -Seconds 2
}

# ── 4. Install the service ───────────────────────────────────────────────────

Write-Host ""
Write-Host "  Installing Windows Service '$ServiceName'..." -ForegroundColor Yellow

& $NssmExe install $ServiceName $ExePath $ExeArgs

# Set working directory to project root so all relative paths resolve correctly
& $NssmExe set $ServiceName AppDirectory $ProjectRoot

# Log stdout/stderr to project logs folder
$LogDir = Join-Path $ProjectRoot "logs"
if (-not (Test-Path $LogDir)) { New-Item -ItemType Directory -Path $LogDir | Out-Null }
& $NssmExe set $ServiceName AppStdout (Join-Path $LogDir "addon-stdout.log")
& $NssmExe set $ServiceName AppStderr (Join-Path $LogDir "addon-stderr.log")
& $NssmExe set $ServiceName AppRotateFiles 1
& $NssmExe set $ServiceName AppRotateBytes 5242880  # 5 MB rotate

# Service metadata
& $NssmExe set $ServiceName DisplayName $ServiceDisplayName
& $NssmExe set $ServiceName Description $ServiceDescription

# Start type: automatic (starts at boot)
& $NssmExe set $ServiceName Start SERVICE_AUTO_START

# Restart automatically on crash, after 5 seconds
& $NssmExe set $ServiceName AppRestartDelay 5000

# ── 5. Start the service ─────────────────────────────────────────────────────

Write-Host ""
Write-Host "  Starting service..." -ForegroundColor Yellow
& $NssmExe start $ServiceName
Start-Sleep -Seconds 3

$svc = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
if ($svc -and $svc.Status -eq "Running") {
    Write-Host "  → Service is RUNNING ✅" -ForegroundColor Green
} else {
    Write-Host "  → Service status: $($svc.Status)" -ForegroundColor Yellow
    Write-Host "     Check logs at: $LogDir" -ForegroundColor Gray
}

# ── 6. Open firewall port ─────────────────────────────────────────────────────

$cfgFile = Join-Path $ProjectRoot "data\config.json"
$port = 7000
if (Test-Path $cfgFile) {
    try {
        $cfg = Get-Content $cfgFile | ConvertFrom-Json
        if ($cfg.port) { $port = $cfg.port }
    } catch {}
}

Write-Host ""
Write-Host "  Adding Windows Firewall rule for port $port..." -ForegroundColor Yellow
$ruleName = "PlayTorrio Nuvio Addon (TCP $port)"
$existing = Get-NetFirewallRule -DisplayName $ruleName -ErrorAction SilentlyContinue
if (-not $existing) {
    New-NetFirewallRule `
        -DisplayName $ruleName `
        -Direction Inbound `
        -Protocol TCP `
        -LocalPort $port `
        -Action Allow `
        -Profile Private | Out-Null
    Write-Host "  → Firewall rule added ✅" -ForegroundColor Green
} else {
    Write-Host "  → Firewall rule already exists ✅" -ForegroundColor Green
}

# ── Done ──────────────────────────────────────────────────────────────────────

Write-Host ""
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  ✅ Service installed and running!" -ForegroundColor Green
Write-Host ""
Write-Host "  The addon now starts automatically at every Windows boot" -ForegroundColor White
Write-Host "  — even before you log in."
Write-Host ""
Write-Host "  Useful commands:" -ForegroundColor White
Write-Host "    Start:    Start-Service $ServiceName" -ForegroundColor Gray
Write-Host "    Stop:     Stop-Service  $ServiceName" -ForegroundColor Gray
Write-Host "    Restart:  Restart-Service $ServiceName" -ForegroundColor Gray
Write-Host "    Logs:     Get-Content '$LogDir\addon-stdout.log' -Tail 50 -Wait" -ForegroundColor Gray
Write-Host "    Uninstall: & '$NssmExe' remove $ServiceName confirm" -ForegroundColor Gray
Write-Host ""
Write-Host "  Addon URL (install in Nuvio):" -ForegroundColor White

# Print LAN IP
$lanIp = (Get-NetIPAddress -AddressFamily IPv4 |
    Where-Object { $_.IPAddress -notmatch "^127\." -and $_.IPAddress -notmatch "^169\." } |
    Select-Object -First 1).IPAddress
Write-Host "    http://${lanIp}:${port}/manifest.json" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""
