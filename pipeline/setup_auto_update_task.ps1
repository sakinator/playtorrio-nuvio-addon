# Script to set up a Windows Scheduled Task for daily automated updates
$taskName = "PlayTorrioAddonDailyUpdate"
$actionScript = (Resolve-Path "$PSScriptRoot\update.ps1").Path

Write-Host "Creating/Updating Scheduled Task '$taskName' to run daily at 04:00 AM..." -ForegroundColor Cyan

$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$actionScript`""
$trigger = New-ScheduledTaskTrigger -Daily -At 4am
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable

Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings -Description "Automatically checks and updates PlayTorrio HTTP scrapers for Nuvio addon." -Force

Write-Host "Scheduled Task '$taskName' created successfully!" -ForegroundColor Green
Write-Host "To remove it in the future, run: Unregister-ScheduledTask -TaskName '$taskName' -Confirm:`$false" -ForegroundColor Gray
