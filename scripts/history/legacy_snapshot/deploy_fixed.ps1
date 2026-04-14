# FanControl 修复版部署脚本

Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "  FanControl 修复部署工具" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""

# 备份原文件
Write-Host "[1/4] 备份原始脚本..." -ForegroundColor Yellow

$backupDir = "C:\FanControl_Auto\backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
New-Item -ItemType Directory -Force -Path $backupDir | Out-Null

Copy-Item "C:\FanControl_Auto\auto_switch.ps1" "$backupDir\auto_switch.ps1.bak" -ErrorAction SilentlyContinue
Copy-Item "C:\FanControl_Auto\switch.ps1" "$backupDir\switch.ps1.bak" -ErrorAction SilentlyContinue

Write-Host "Backup completed: $backupDir" -ForegroundColor Green
Write-Host ""

# 部署修复版脚本
Write-Host "[2/4] 部署修复版脚本..." -ForegroundColor Yellow

Copy-Item "C:\FanControl_Auto\auto_switch_fixed.ps1" "C:\FanControl_Auto\auto_switch.ps1" -Force
Copy-Item "C:\FanControl_Auto\switch_fixed.ps1" "C:\FanControl_Auto\switch.ps1" -Force

Write-Host "Scripts updated" -ForegroundColor Green
Write-Host ""

# 重新注册任务计划
Write-Host "[3/4] 重新注册任务计划..." -ForegroundColor Yellow

$psExe = "powershell.exe"
$psArg = "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"C:\FanControl_Auto\auto_switch.ps1`""
$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Highest

$tasks = @(
    @{ Name = "FanControl-0800(Game)"; Time = "08:00" },
    @{ Name = "FanControl-1240(Quiet)"; Time = "12:40" },
    @{ Name = "FanControl-1400(Game)"; Time = "14:00" },
    @{ Name = "FanControl-2100(Quiet)"; Time = "21:00" }
)

foreach ($t in $tasks) {
    $action = New-ScheduledTaskAction -Execute $psExe -Argument $psArg
    $trigger = New-ScheduledTaskTrigger -Daily -At $t.Time
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBattery -DontStopIfGoingOnBattery -StartWhenAvailable

    Register-ScheduledTask -TaskName $t.Name -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force | Out-Null
    Write-Host "  Registered: $($t.Name)" -ForegroundColor Green
}

Write-Host ""

# 重新注册启动任务
Write-Host "[4/4] 注册启动任务..." -ForegroundColor Yellow

$startupXmlPath = "C:\FanControl_Auto\startup_task_fixed_v2.xml"

Register-ScheduledTask -TaskName 'FanControl-Startup' -Xml (Get-Content $startupXmlPath | Out-String) -Force | Out-Null

Write-Host "  Registered: FanControl-Startup" -ForegroundColor Green
Write-Host ""

# 验证部署
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host "  验证结果" -ForegroundColor Cyan
Write-Host "=====================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "任务列表:" -ForegroundColor Yellow
Get-ScheduledTask | Where-Object { $_.TaskName -like 'FanControl*' } |
    Select-Object TaskName, State |
    Format-Table -AutoSize

Write-Host "部署完成!" -ForegroundColor Green
