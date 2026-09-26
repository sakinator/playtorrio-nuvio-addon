# Windows PowerShell wrapper for the cross-platform Dart update pipeline
Set-Location -Path "$PSScriptRoot\.."

# Locate Dart executable
$dartExe = Get-Command dart -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source
if (-not $dartExe) {
    if (Test-Path "..\dart-sdk\bin\dart.exe") {
        $dartExe = (Resolve-Path "..\dart-sdk\bin\dart.exe").Path
    } elseif (Test-Path "dart-sdk\bin\dart.exe") {
        $dartExe = (Resolve-Path "dart-sdk\bin\dart.exe").Path
    }
}

if (-not $dartExe) {
    Write-Host "[ERROR] Dart SDK not found in PATH! Please install Dart: https://dart.dev/get-dart" -ForegroundColor Red
    exit 1
}

& $dartExe run tool/update.dart $args
