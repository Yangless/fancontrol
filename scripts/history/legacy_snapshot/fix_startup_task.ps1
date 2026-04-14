# 修复启动任务

Write-Host "Fixing FanControl-Startup task..." -ForegroundColor Yellow

# 创建新的启动任务 XML（延迟改为 2 分钟）
$taskXml = @'
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.3" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo>
    <Description>FanControl startup at boot with auto-config (delayed 2min)</Description>
    <URI>\FanControl-Startup</URI>
  </RegistrationInfo>
  <Principals>
    <Principal id="Author">
      <UserId>S-1-5-21-0000000000-0000000000-0000000000-1001</UserId>
      <LogonType>InteractiveToken</LogonType>
      <RunLevel>HighestAvailable</RunLevel>
    </Principal>
  </Principals>
  <Settings>
    <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
    <StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
    <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
    <StartWhenAvailable>true</StartWhenAvailable>
    <IdleSettings>
      <Duration>PT10M</Duration>
      <WaitTimeout>PT1H</WaitTimeout>
      <StopOnIdleEnd>true</StopOnIdleEnd>
      <RestartOnIdle>false</RestartOnIdle>
    </IdleSettings>
    <UseUnifiedSchedulingEngine>true</UseUnifiedSchedulingEngine>
  </Settings>
  <Triggers>
    <BootTrigger>
      <Delay>PT2M</Delay>
    </BootTrigger>
  </Triggers>
  <Actions Context="Author">
    <Exec>
      <Command>powershell.exe</Command>
      <Arguments>-WindowStyle Hidden -ExecutionPolicy Bypass -File C:\FanControl_Auto\auto_switch.ps1</Arguments>
    </Exec>
  </Actions>
</Task>
'@

$xmlPath = "C:\FanControl_Auto\startup_task_fixed_2min.xml"
$taskXml | Out-File -FilePath $xmlPath -Encoding Unicode

# 注册任务
Register-ScheduledTask -TaskName 'FanControl-Startup' -Xml (Get-Content $xmlPath | Out-String) -Force | Out-Null

Write-Host "Startup task fixed with 2-minute delay" -ForegroundColor Green

# 验证
$task = Get-ScheduledTask -TaskName 'FanControl-Startup'
Write-Host ""
Write-Host "Verification:" -ForegroundColor Cyan
Write-Host "  Trigger: $($task.Triggers[0].CimClass.CimClassName)" -ForegroundColor White
Write-Host "  Delay: $($task.Triggers[0].Delay)" -ForegroundColor White
Write-Host "  Enabled: $($task.Triggers[0].Enabled)" -ForegroundColor White
Write-Host ""
Write-Host "Next reboot will trigger the task 2 minutes after boot" -ForegroundColor Green
