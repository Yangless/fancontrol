# FanControl 自动切换脚本 - 增强版（带验证和监控）
# 新增功能：
# 1. 切换后验证配置是否生效
# 2. 生成状态报告文件
# 3. 详细的成功/失败通知

param([switch]$Force)

# ============ 基础路径配置 ============
$FanControlExe = "D:\Program Files (x86)\FanControl\FanControl.exe"
$ConfigDir = "D:\Program Files (x86)\FanControl\Configurations"
$StateDir = "C:\FanControl_Auto\state"
$LogDir = "C:\FanControl_Auto\logs"
$OverrideFlag = "$StateDir\override.flag"
$StatusFile = "$StateDir\current_status.json"
$LogFile = "$LogDir\auto_switch.log"

# 配置文件路径
$QuietConfig = "$ConfigDir\Quiet_mode.json"
$GameConfig = "$ConfigDir\Game.json"
$CacheFile = "$ConfigDir\CACHE"

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

# ============ 状态文件更新函数 ============
function Update-StatusFile {
    param(
        [string]$TargetConfig,
        [string]$Status,
        [string]$Message,
        [bool]$Verified = $false
    )

    $statusData = @{
        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        TargetConfig = $TargetConfig
        ActualConfig = $null
        Status = $Status
        Message = $Message
        Verified = $Verified
        ProcessRunning = $false
        ProcessId = $null
    }

    # 检查进程状态
    $process = Get-Process -Name FanControl -ErrorAction SilentlyContinue
    if ($process) {
        $statusData.ProcessRunning = $true
        $statusData.ProcessId = $process.Id
    }

    # 检查实际配置
    if (Test-Path $CacheFile) {
        try {
            $cache = Get-Content $CacheFile | ConvertFrom-Json
            $statusData.ActualConfig = $cache.CurrentConfigFileName
        } catch {
            $statusData.ActualConfig = "Unknown"
        }
    }

    # 保存状态文件
    $statusData | ConvertTo-Json -Depth 3 | Set-Content $StatusFile -ErrorAction SilentlyContinue
}

# ============ 配置验证函数 ============
function Test-ConfigFiles {
    $errors = @()

    if (-not (Test-Path $FanControlExe)) {
        $errors += "FanControl.exe not found: $FanControlExe"
    }

    if (-not (Test-Path $QuietConfig)) {
        $errors += "Quiet config not found: $QuietConfig"
    }

    if (-not (Test-Path $GameConfig)) {
        $errors += "Game config not found: $GameConfig"
    }

    if ($errors.Count -gt 0) {
        Write-Log "ERROR: Config validation failed"
        $errors | ForEach-Object { Write-Log "  - $_" }

        Update-StatusFile -TargetConfig "N/A" -Status "ERROR" -Message ($errors -join "; ") -Verified $false

        [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") | Out-Null
        [System.Windows.Forms.MessageBox]::Show(
            "Config validation failed:`n" + ($errors -join "`n"),
            "FanControl Auto Switch Error",
            "OK",
            "Error"
        ) | Out-Null

        exit 1
    }

    Write-Log "Config validation passed"
}

# ============ 配置切换验证函数 ============
function Test-ConfigSwitch {
    param(
        [string]$TargetConfig,
        [int]$MaxWaitSeconds = 10
    )

    $configName = Split-Path $TargetConfig -Leaf
    Write-Log "Verifying config switch to: $configName"

    # 等待配置生效
    $waited = 0
    $verified = $false

    while ($waited -lt $MaxWaitSeconds) {
        Start-Sleep -Seconds 1
        $waited++

        if (Test-Path $CacheFile) {
            try {
                $cache = Get-Content $CacheFile | ConvertFrom-Json
                $actualConfig = $cache.CurrentConfigFileName

                if ($actualConfig -eq $configName) {
                    $verified = $true
                    Write-Log "SUCCESS: Config verified after ${waited}s - Actual: $actualConfig"
                    break
                } else {
                    Write-Log "Waiting... (${waited}s) - Target: $configName, Actual: $actualConfig"
                }
            } catch {
                Write-Log "Warning: Cannot read CACHE file (${waited}s)"
            }
        }
    }

    return $verified
}

# ============ 时间段判断函数 ============
function Get-TargetConfig {
    $min = (Get-Date).Hour * 60 + (Get-Date).Minute

    if (($min -ge 760 -and $min -lt 840) -or ($min -ge 1260) -or ($min -lt 480)) {
        Write-Log "Current time $((Get-Date).ToString('HH:mm')) is in Quiet period"
        return $QuietConfig
    } else {
        Write-Log "Current time $((Get-Date).ToString('HH:mm')) is in Game period"
        return $GameConfig
    }
}

# ============ 显示通知函数 ============
function Show-Notification {
    param(
        [string]$Title,
        [string]$Message,
        [string]$Type = "Info"  # Info, Warning, Error
    )

    # 使用 BurntToast 模块（如果已安装）
    if (Get-Module -ListAvailable -Name BurntToast) {
        $icon = switch ($Type) {
            "Error" { "❌" }
            "Warning" { "⚠️" }
            default { "✅" }
        }
        New-BurntToastNotification -Text $Title, $Message -AppLogo $icon -ErrorAction SilentlyContinue
    } else {
        # 使用系统通知
        [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") | Out-Null
        $notify = New-Object System.Windows.Forms.NotifyIcon
        $notify.Icon = [System.Drawing.SystemIcons]::Information
        $notify.BalloonTipIcon = $Type
        $notify.BalloonTipTitle = $Title
        $notify.BalloonTipText = $Message
        $notify.Visible = $true
        $notify.ShowBalloonTip(5000)
        Start-Sleep -Seconds 5
        $notify.Dispose()
    }
}

# ============ 主逻辑开始 ============
Write-Log "=========================================="
Write-Log "Script started (Enhanced v3.0)"
Write-Log "Parameter: Force=$Force"
Write-Log "=========================================="

# 验证配置文件
Test-ConfigFiles

# ============ 强制触发点处理 ============
$isForcePoint = ((Get-Date).Hour -eq 12 -and (Get-Date).Minute -eq 40) -or ((Get-Date).Hour -eq 21 -and (Get-Date).Minute -eq 0)

if ($isForcePoint -or $Force) {
    Write-Log "Force trigger detected, clearing override flag"
    Remove-Item $OverrideFlag -Force -ErrorAction SilentlyContinue

    $configName = Split-Path $QuietConfig -Leaf
    Write-Log "Force switch to Quiet mode: $configName"

    # 执行切换
    & $FanControlExe -c $QuietConfig -tray

    # 验证切换
    $verified = Test-ConfigSwitch -TargetConfig $QuietConfig

    # 更新状态文件
    $status = if ($verified) { "SUCCESS" } else { "FAILED" }
    $message = "Force switch to $configName - " + $(if ($verified) { "Verified" } else { "Not verified" })
    Update-StatusFile -TargetConfig $configName -Status $status -Message $message -Verified $verified

    # 显示通知
    if ($verified) {
        Show-Notification -Title "FanControl Auto Switch" -Message "Successfully switched to $configName" -Type "Info"
    } else {
        Show-Notification -Title "FanControl Switch Warning" -Message "Switch to $configName may have failed" -Type "Warning"
    }

    Write-Log "Script ended (Force mode) - Status: $status"
    exit
}

# ============ 免打扰模式检查 ============
if (Test-Path $OverrideFlag) {
    $overrideMode = Get-Content $OverrideFlag -ErrorAction SilentlyContinue
    Write-Log "Override flag detected, skipping auto switch (current mode: $overrideMode)"

    Update-StatusFile -TargetConfig "Override: $overrideMode" -Status "SKIPPED" -Message "Override mode active" -Verified $false

    Write-Log "Script ended (Override mode)"
    exit
}

# ============ 正常切换逻辑 ============
$targetConfig = Get-TargetConfig
$configName = Split-Path $targetConfig -Leaf

Write-Log "Attempting to switch config: $configName"

# 执行切换
& $FanControlExe -c $targetConfig -tray

# 验证切换
$verified = Test-ConfigSwitch -TargetConfig $targetConfig

# 更新状态文件
$status = if ($verified) { "SUCCESS" } else { "FAILED" }
$message = "Switch to $configName - " + $(if ($verified) { "Verified" } else { "Not verified" })
Update-StatusFile -TargetConfig $configName -Status $status -Message $message -Verified $verified

# 显示通知
if ($verified) {
    Show-Notification -Title "FanControl Auto Switch" -Message "Successfully switched to $configName" -Type "Info"
} else {
    Show-Notification -Title "FanControl Switch Warning" -Message "Switch to $configName may have failed" -Type "Warning"
}

Write-Log "Script ended - Status: $status"
Write-Log "=========================================="
