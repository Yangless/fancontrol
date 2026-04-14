# Fix startup task delay
$trigger = New-ScheduledTaskTrigger -AtStartup -RandomDelay (New-TimeSpan -Minutes 1)
$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument '-WindowStyle Hidden -ExecutionPolicy Bypass -File "C:\FanControl_Auto\auto_switch.ps1"'
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Highest
$task = New-ScheduledTask -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Description 'FanControl startup at boot with auto-config'

try {
    Set-ScheduledTask -TaskName 'FanControl-Startup' -Trigger $trigger
    Write-Host "Success: Updated startup task with 1-minute delay" -ForegroundColor Green
} catch {
    Write-Host "Error: Failed to update task - $_" -ForegroundColor Red
    exit 1
}

$taskInfo = Get-ScheduledTask -TaskName 'FanControl-Startup' -ErrorAction SilentlyContinue
if ($taskInfo) {
    Write-Host "`nTask Status: $($taskInfo.State)" -ForegroundColor Green
    Write-Host "Trigger Delay: 1 minute after startup" -ForegroundColor Cyan
}
