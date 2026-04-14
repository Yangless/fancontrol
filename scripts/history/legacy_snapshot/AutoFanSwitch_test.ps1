# FanControl 智能自动配置脚本

$FanControlDir = "D:\Program Files (x86)\FanControl"
$FanControlPath = Join-Path $FanControlDir "FanControl.exe"
$GameConfig = "Game.json"
$QuietConfig = "Quiet_mode.json"
$CurrentConfigFile = Join-Path $FanControlDir "CurrentConfig.txt"

$CurrentTime = (Get-Date).Hour * 60 + (Get-Date).Minute

$QuietStart1 = 12 * 60 + 30
$QuietEnd1 = 14 * 60 + 30
$QuietStart2 = 22 * 60
$QuietEnd2 = 8 * 60

$IsQuietTime = $false
if (($CurrentTime -ge $QuietStart1 -and $CurrentTime -lt $QuietEnd1) -or
    ($CurrentTime -ge $QuietStart2) -or
    ($CurrentTime -lt $QuietEnd2)) {
    $IsQuietTime = $true
}

$TargetConfig = if ($IsQuietTime) { $QuietConfig } else { $GameConfig }

$CurrentConfig = $null
if (Test-Path $CurrentConfigFile) {
    $CurrentConfig = Get-Content $CurrentConfigFile -ErrorAction SilentlyContinue
}

$NeedSwitch = $false
if ($null -eq $CurrentConfig) {
    $NeedSwitch = $true
} elseif ($CurrentConfig -ne $TargetConfig) {
    $NeedSwitch = $true
}

if ($NeedSwitch) {
    $Process = Get-Process -Name "FanControl" -ErrorAction SilentlyContinue
    if ($Process) {
        Stop-Process -Name "FanControl" -Force
        Start-Sleep -Seconds 2
    }
    Start-Process -FilePath $FanControlPath -ArgumentList "-c `"$TargetConfig`"" -WorkingDirectory $FanControlDir
    Start-Sleep -Seconds 3
    $TargetConfig | Out-File -FilePath $CurrentConfigFile -Encoding UTF8
    $LogEntry = "[$(Get-Date -Format 'yyyy/MM/dd HH:mm:ss')] 切换配置: $TargetConfig"
    $LogEntry | Out-File -FilePath (Join-Path $FanControlDir "AutoSwitch.log") -Encoding UTF8 -Append
}
