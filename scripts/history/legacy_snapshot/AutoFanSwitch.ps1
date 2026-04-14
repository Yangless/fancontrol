# FanControl 开机自动配置脚本
# 根据当前时间自动选择合适的风扇配置

$FanControlPath = "D:\Program Files (x86)\FanControl\FanControl.exe"
$GameConfig = "Game.json"
$QuietConfig = "Quiet_mode.json"

# 获取当前时间（24小时制）
$CurrentHour = (Get-Date).Hour
$CurrentMinute = (Get-Date).Minute
$CurrentTime = $CurrentHour * 60 + $CurrentMinute

# 定义静音时间段（分钟数）
# 12:30-14:30 = 750-870
# 22:00-08:00 = 1320-480 (跨午夜)
$QuietStart1 = 12 * 60 + 30   # 750 (12:30)
$QuietEnd1 = 14 * 60 + 30     # 870 (14:30)
$QuietStart2 = 22 * 60        # 1320 (22:00)
$QuietEnd2 = 8 * 60           # 480 (08:00)

# 判断当前是否在静音时间段
$IsQuietTime = $false

if ($CurrentTime -ge $QuietStart1 -and $CurrentTime -le $QuietEnd1) {
    # 中午时段 12:30-14:30
    $IsQuietTime = $true
}
elseif ($CurrentTime -ge $QuietStart2) {
    # 晚上22:00之后
    $IsQuietTime = $true
}
elseif ($CurrentTime -le $QuietEnd2) {
    # 凌晨到早上08:00
    $IsQuietTime = $true
}

# 选择配置并切换
if ($IsQuietTime) {
    $Config = $QuietConfig
    Write-Host "当前时间: $(Get-Date -Format 'HH:mm') - 静音时段，使用 $QuietConfig"
} else {
    $Config = $GameConfig
    Write-Host "当前时间: $(Get-Date -Format 'HH:mm') - 游戏时段，使用 $GameConfig"
}

# 执行切换
Start-Process $FanControlPath -ArgumentList "-c $Config" -WindowStyle Hidden
