# FanControl 手动切换脚本 - 修复版
# 修复内容：
# 1. 添加配置文件验证
# 2. 添加日志记录
# 3. 添加状态显示
# 4. 添加帮助信息

param(
    [string]$Mode = "",
    [switch]$Help
)

# ============ 基础路径配置 ============
$FanControlExe = "D:\Program Files (x86)\FanControl\FanControl.exe"
$ConfigDir = "D:\Program Files (x86)\FanControl\Configurations"
$StateDir = "C:\FanControl_Auto\state"
$LogDir = "C:\FanControl_Auto\logs"
$OverrideFlag = "$StateDir\override.flag"
$LogFile = "$LogDir\switch.log"

# 配置文件路径
$QuietConfig = "$ConfigDir\Quiet_mode.json"
$GameConfig = "$ConfigDir\Game.json"

# ============ 初始化 ============
New-Item -ItemType Directory -Force -Path $StateDir | Out-Null
New-Item -ItemType Directory -Force -Path $LogDir | Out-Null

# ============ 日志函数 ============
function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy/MM/dd HH:mm:ss"
    $logEntry = "[$timestamp] $Message"
    Add-Content -Path $LogFile -Value $logEntry -ErrorAction SilentlyContinue
}

# ============ 显示帮助信息 ============
if ($Help -or $Mode -eq "") {
    Write-Host @"
====================================
  FanControl 手动切换工具
====================================

使用方法:
  .\switch.ps1 -Mode <模式>

可用模式:
  game   - 切换到游戏模式（开启免打扰）
  quiet  - 切换到安静模式（开启免打扰）
  auto   - 恢复自动调度（清除免打扰）

当前状态:
  免打扰标志: $(if (Test-Path $OverrideFlag) { "已启用 ($((Get-Content $OverrideFlag)))" } else { "未启用" })

示例:
  .\switch.ps1 -Mode game
  .\switch.ps1 -Mode auto

====================================
"@
    exit
}

$Mode = $Mode.ToLower().Trim()
Write-Log "========== 手动切换启动 =========="
Write-Log "请求模式: $Mode"

# ============ 恢复自动调度 ============
if ($Mode -eq "auto") {
    Write-Log "清除免打扰标志，恢复自动调度"

    if (Test-Path $OverrideFlag) {
        $previousMode = Get-Content $OverrideFlag
        Remove-Item $OverrideFlag -Force -ErrorAction SilentlyContinue
        Write-Log "已清除免打扰标志（原模式: $previousMode）"
    } else {
        Write-Log "未检测到免打扰标志"
    }

    # 立即校准当前状态
    Write-Log "调用自动切换脚本进行校准"
    & "C:\FanControl_Auto\auto_switch.ps1" -Force

    Write-Log "========== 手动切换结束 =========="
    exit
}

# ============ 验证模式参数 ============
if ($Mode -notin @("game", "quiet")) {
    Write-Log "错误: 无效的模式 '$Mode'"
    Write-Host "错误: 无效的模式。请使用 'game'、'quiet' 或 'auto'" -ForegroundColor Red
    exit 1
}

# ============ 验证配置文件 ============
$targetConfig = if ($Mode -eq "game") { $GameConfig } else { $QuietConfig }
$configName = Split-Path $targetConfig -Leaf

if (-not (Test-Path $targetConfig)) {
    Write-Log "错误: 配置文件不存在 - $targetConfig"
    Write-Host "错误: 配置文件不存在 - $configName" -ForegroundColor Red
    exit 1
}

# ============ 执行切换 ============
Write-Log "切换到 $Mode 模式: $configName"

# 发送 IPC 消息给运行中的 FanControl 切换配置
& $FanControlExe -c $targetConfig

# 写入免打扰标志
$Mode | Set-Content $OverrideFlag
Write-Log "已写入免打扰标志: $Mode"

Write-Host "已切换到 $mode 模式 ($configName) 并开启免打扰" -ForegroundColor Green
Write-Host "提示: 使用 '.\switch.ps1 -Mode auto' 可恢复自动调度" -ForegroundColor Yellow

Write-Log "========== 手动切换结束 =========="
