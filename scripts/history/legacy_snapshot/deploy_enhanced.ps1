# FanControl 增强版部署脚本

Write-Host "======================================" -ForegroundColor Cyan
Write-Host "  FanControl Enhanced Deployment" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan
Write-Host ""

# 备份原文件
Write-Host "[1/3] Backup original scripts..." -ForegroundColor Yellow
$backupDir = "C:\FanControl_Auto\backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
New-Item -ItemType Directory -Force -Path $backupDir | Out-Null
Copy-Item "C:\FanControl_Auto\auto_switch.ps1" "$backupDir\auto_switch.ps1.bak" -ErrorAction SilentlyContinue
Copy-Item "C:\FanControl_Auto\switch.ps1" "$backupDir\switch.ps1.bak" -ErrorAction SilentlyContinue
Write-Host "Backup completed: $backupDir" -ForegroundColor Green
Write-Host ""

# 部署增强版脚本
Write-Host "[2/3] Deploy enhanced scripts..." -ForegroundColor Yellow
Copy-Item "C:\FanControl_Auto\auto_switch_enhanced.ps1" "C:\FanControl_Auto\auto_switch.ps1" -Force
Write-Host "Enhanced script deployed" -ForegroundColor Green
Write-Host ""

# 重新注册任务
Write-Host "[3/3] Re-register scheduled tasks..." -ForegroundColor Yellow
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
    Register-ScheduledTask -TaskName $t.Name -Action $action -Trigger $trigger -Principal $principal -Force | Out-Null
    Write-Host "  Registered: $($t.Name)" -ForegroundColor Green
}

Write-Host ""
Write-Host "======================================" -ForegroundColor Cyan
Write-Host "  Deployment Complete!" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "New Features:" -ForegroundColor Yellow
Write-Host "  1. Config switch verification" -ForegroundColor White
Write-Host "  2. Status file tracking" -ForegroundColor White
Write-Host "  3. Desktop notifications" -ForegroundColor White
Write-Host "  4. Detailed logging" -ForegroundColor White
Write-Host ""
Write-Host "How to check status:" -ForegroundColor Yellow
Write-Host "  .\check_status.ps1          # View current status" -ForegroundColor White
Write-Host "  .\check_status.ps1 -Watch   # Monitor in real-time" -ForegroundColor White
Write-Host ""
