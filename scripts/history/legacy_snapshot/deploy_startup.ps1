# FanControl Startup Task Deployment Script

$action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument '-WindowStyle Hidden -ExecutionPolicy Bypass -File "C:\FanControl_Auto\auto_switch.ps1"'
$trigger = New-ScheduledTaskTrigger -AtStartup
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable
$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Highest
$task = New-ScheduledTask -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Description 'FanControl startup at boot with auto-config'

try {
    Register-ScheduledTask -TaskName 'FanControl-Startup' -InputObject $task -Force
    Write-Host "Success: Created startup task" -ForegroundColor Green
} catch {
    Write-Host "Error: Failed to create task - $_" -ForegroundColor Red
    exit 1
}

$taskInfo = Get-ScheduledTask -TaskName 'FanControl-Startup' -ErrorAction SilentlyContinue
if ($taskInfo) {
    Write-Host "Task Status: $($taskInfo.State)" -ForegroundColor Green
    Write-Host ""
    Write-Host "Task Details:" -ForegroundColor Cyan
    Write-Host "  Name: FanControl-Startup"
    Write-Host "  Trigger: At system startup"
    Write-Host "  Action: Run auto_switch.ps1"
    Write-Host ""
    Write-Host "Next reboot will auto-start FanControl with correct config" -ForegroundColor Yellow
} else {
    Write-Host "Error: Task verification failed" -ForegroundColor Red
}

Write-Host ""
Write-Host "All FanControl Tasks:" -ForegroundColor Cyan
Get-ScheduledTask | Where-Object { $_.TaskName -like '*FanControl*' } | Select-Object TaskName, State | Format-Table -AutoSize
