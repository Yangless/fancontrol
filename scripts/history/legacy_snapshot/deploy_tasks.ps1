# 部署定时任务 - 需要管理员权限运行
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
  Register-ScheduledTask -TaskName $t.Name -Action $action -Trigger $trigger -Principal $principal -Force
  Write-Host "Deployed: $($t.Name)" -ForegroundColor Green
}

Write-Host "All tasks deployed!" -ForegroundColor Cyan
