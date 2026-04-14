# FanControl 自动切换脚本 - 修复版
# 修复内容：
# 1. 添加配置文件存在性验证
# 2. 添加日志记录功能
# 3. 明确时间边界注释
# 4. 添加错误处理和通知

param([switch]$Force) # -Force 用于强制触发点

# ============ 基础路径配置 ============
$FanControlExe = "D:\Program Files (x86)\FanControl\FanControl.exe"
$ConfigDir = "D:\Program Files (x86)\FanControl\Configurations"
$StateDir = "C:\FanControl_Auto\state"
$LogDir = "C:\FanControl_Auto\logs"
$OverrideFlag = "$StateDir\override.flag"
$LogFile = "$LogDir\auto_switch.log"

# 配置文件路径（统一使用 Game.json）
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

# ============ 配置文件验证 ============
function Test-ConfigFiles {
    $errors = @()

    if (-not (Test-Path $FanControlExe)) {
        $errors += "FanControl.exe 不存在: $FanControlExe"
    }

    if (-not (Test-Path $QuietConfig)) {
        $errors += "安静配置文件不存在: $QuietConfig"
    }

    if (-not (Test-Path $GameConfig)) {
        $errors += "游戏配置文件不存在: $GameConfig"
    }

    if ($errors.Count -gt 0) {
        Write-Log "错误: 配置验证失败"
        $errors | ForEach-Object { Write-Log "  - $_" }

        # 显示系统通知
        [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") | Out-Null
        [System.Windows.Forms.MessageBox]::Show(
            "配置文件验证失败:`n" + ($errors -join "`n"),
            "FanControl 自动切换错误",
            "OK",
            "Error"
        ) | Out-Null

        exit 1
    }

    Write-Log "配置文件验证通过"
}

# ============ 时间段判断函数 ============
# 时间段定义（精确到分钟）：
# - Quiet 时段: 12:40(760min) - 14:00(840min)
# - Quiet 时段: 21:00(1260min) - 次日08:00(480min) [跨天]
# - Game 时段: 08:00(480min) - 12:40(760min)
# - Game 时段: 14:00(840min) - 21:00(1260min)
function Get-TargetConfig {
    $min = (Get-Date).Hour * 60 + (Get-Date).Minute

    # Quiet 时段判断（包含跨天逻辑）
    # 条件1: 12:40-14:00 (760 <= min < 840)
    # 条件2: 21:00-24:00 (min >= 1260)
    # 条件3: 00:00-08:00 (min < 480)
    if (($min -ge 760 -and $min -lt 840) -or ($min -ge 1260) -or ($min -lt 480)) {
        Write-Log "当前时间 $((Get-Date).ToString('HH:mm')) 处于安静时段"
        return $QuietConfig
    } else {
        Write-Log "当前时间 $((Get-Date).ToString('HH:mm')) 处于游戏时段"
        return $GameConfig
    }
}

# ============ 主逻辑开始 ============
Write-Log "========== 脚本启动 =========="
Write-Log "执行参数: Force=$Force"

# 验证配置文件
Test-ConfigFiles

# ============ 强制触发点处理 ============
# 强制触发点：12:40 和 21:00（进入 Quiet 时段的开始）
# 作用：强制清除 override.flag，恢复自动调度
$isForcePoint = (((Get-Date).Hour -eq 12 -and (Get-Date).Minute -eq 40) -or
                 ((Get-Date).Hour -eq 21 -and (Get-Date).Minute -eq 0))

if ($isForcePoint -or $Force) {
    Write-Log "检测到强制触发点，清除免打扰标志"
    Remove-Item $OverrideFlag -Force -ErrorAction SilentlyContinue

    Write-Log "强制切换到安静模式: $QuietConfig"
    & $FanControlExe -c $QuietConfig -tray

    Write-Log "========== 脚本结束（强制模式）=========="
    exit
}

# ============ 免打扰模式检查 ============
if (Test-Path $OverrideFlag) {
    $overrideMode = Get-Content $OverrideFlag -ErrorAction SilentlyContinue
    Write-Log "检测到免打扰标志，跳过自动切换（当前模式: $overrideMode）"
    Write-Log "========== 脚本结束（免打扰模式）=========="
    exit
}

# ============ 正常切换逻辑 ============
$targetConfig = Get-TargetConfig
$configName = Split-Path $targetConfig -Leaf

Write-Log "切换配置: $configName"
& $FanControlExe -c $targetConfig -tray

Write-Log "========== 脚本结束 =========="
