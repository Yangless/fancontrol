param()

$ErrorActionPreference = "Stop"
$TaskName = "FanControl-Startup"
$ScriptPath = "C:\FanControl_Auto\auto_switch.ps1"
$RuntimePathsHelper = Join-Path $PSScriptRoot "runtime_paths.ps1"

if (Test-Path $RuntimePathsHelper) {
    . $RuntimePathsHelper
    $ScriptPath = (Get-FanControlPaths).RuntimeAutoSwitch
}

Write-Host "=== Fix FanControl Startup Task ===" -ForegroundColor Cyan

# Remove old task
Write-Host "[1/3] Removing old task..." -ForegroundColor Yellow
Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
Write-Host "  Done" -ForegroundColor Green

# Create new task with LogonTrigger + 30s delay
Write-Host "[2/3] Creating new task (LogonTrigger + 30s delay)..." -ForegroundColor Yellow

$action = New-ScheduledTaskAction `
    -Execute "powershell.exe" `
    -Argument "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"$ScriptPath`""

$trigger = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
$trigger.Delay = "PT30S"

$principal = New-ScheduledTaskPrincipal `
    -UserId $env:USERNAME `
    -LogonType Interactive `
    -RunLevel Highest

$settings = New-ScheduledTaskSettingsSet `
    -MultipleInstances IgnoreNew `
    -StartWhenAvailable `
    -ExecutionTimeLimit (New-TimeSpan -Hours 1) `
    -DisallowDemandStart:$false

$task = New-ScheduledTask `
    -Action $action `
    -Trigger $trigger `
    -Principal $principal `
    -Settings $settings `
    -Description "FanControl startup at logon with 30s delay"

Register-ScheduledTask -TaskName $TaskName -InputObject $task -Force | Out-Null
Write-Host "  Registered" -ForegroundColor Green

# Verify
Write-Host "[3/3] Verifying..." -ForegroundColor Yellow
$verify = Get-ScheduledTask -TaskName $TaskName
$info = $verify | Get-ScheduledTaskInfo

Write-Host ""
Write-Host "=== Task Info ===" -ForegroundColor Cyan
Write-Host "  Name     : $($verify.TaskName)"
Write-Host "  State    : $($verify.State)"
Write-Host "  Trigger  : $($verify.Triggers.CimClass.CimClassName)"
Write-Host "  Delay    : $($verify.Triggers.Delay)"
Write-Host "  User     : $($verify.Principal.UserId)"
Write-Host "  RunLevel : $($verify.Principal.RunLevel)"
Write-Host "  LastRun  : $($info.LastRunTime)"

if ($verify.State -eq "Ready") {
    Write-Host ""
    Write-Host "SUCCESS: Task registered. FanControl will auto-start 30s after next login." -ForegroundColor Green
} else {
    Write-Host ""
    Write-Host "WARNING: Unexpected state: $($verify.State)" -ForegroundColor Red
}
