# FanControl 持续监控系统
# 功能：每5秒采集数据，每5分钟总结并保存到文件

param(
    [int]$IntervalSeconds = 5,      # 数据采集间隔（秒）
    [int]$SummaryMinutes = 5,       # 总结间隔（分钟）
    [string]$OutputDir = "C:\FanControl_Auto\monitor_data"
)

# ============ 基础配置 ============
$StatusFile = "C:\FanControl_Auto\state\current_status.json"
$LogFile = "C:\FanControl_Auto\logs\auto_switch.log"
$CacheFile = "D:\Program Files (x86)\FanControl\Configurations\CACHE"
$OverrideFlag = "C:\FanControl_Auto\state\override.flag"

New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

# ============ 数据采集 ============
$monitorData = @()
$startTime = Get-Date
$lastSummaryTime = $startTime
$cycleCount = 0

function Get-CurrentStatus {
    $status = @{
        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        ProcessRunning = $false
        ProcessId = $null
        ProcessStartTime = $null
        CurrentConfig = $null
        OverrideActive = $false
        OverrideMode = $null
        SwitchStatus = $null
        SwitchVerified = $false
        ExpectedConfig = $null
        ConfigMatch = $false
    }

    # 进程状态
    $process = Get-Process -Name FanControl -ErrorAction SilentlyContinue
    if ($process) {
        $status.ProcessRunning = $true
        $status.ProcessId = $process.Id
        $status.ProcessStartTime = $process.StartTime.ToString("yyyy-MM-dd HH:mm:ss")
    }

    # 配置状态
    if (Test-Path $CacheFile) {
        try {
            $cache = Get-Content $CacheFile | ConvertFrom-Json
            $status.CurrentConfig = $cache.CurrentConfigFileName
        } catch {
            $status.CurrentConfig = "Unknown"
        }
    }

    # Override 状态
    if (Test-Path $OverrideFlag) {
        $status.OverrideActive = $true
        $status.OverrideMode = Get-Content $OverrideFlag -ErrorAction SilentlyContinue
    }

    # 切换状态
    if (Test-Path $StatusFile) {
        try {
            $switchStatus = Get-Content $StatusFile | ConvertFrom-Json
            $status.SwitchStatus = $switchStatus.Status
            $status.SwitchVerified = $switchStatus.Verified
        } catch {
            $status.SwitchStatus = "Unknown"
        }
    }

    # 期望配置（基于时间段）
    $min = (Get-Date).Hour * 60 + (Get-Date).Minute
    if (($min -ge 760 -and $min -lt 840) -or ($min -ge 1260) -or ($min -lt 480)) {
        $status.ExpectedConfig = "Quiet_mode.json"
    } else {
        $status.ExpectedConfig = "Game.json"
    }

    # 配置匹配
    if ($status.CurrentConfig -and $status.ExpectedConfig) {
        $status.ConfigMatch = ($status.CurrentConfig -eq $status.ExpectedConfig)
    }

    return $status
}

function Write-Summary {
    param(
        [array]$Data,
        [datetime]$StartTime,
        [datetime]$EndTime
    )

    $duration = $EndTime - $StartTime
    $totalSamples = $Data.Count

    # 统计分析
    $runningSamples = ($Data | Where-Object { $_.ProcessRunning }).Count
    $uptimePercent = [math]::Round(($runningSamples / $totalSamples) * 100, 2)

    $configMatches = ($Data | Where-Object { $_.ConfigMatch }).Count
    $matchPercent = [math]::Round(($configMatches / $totalSamples) * 100, 2)

    $overrideActive = ($Data | Where-Object { $_.OverrideActive }).Count -gt 0

    $successCount = ($Data | Where-Object { $_.SwitchStatus -eq "SUCCESS" }).Count
    $failedCount = ($Data | Where-Object { $_.SwitchStatus -eq "FAILED" }).Count

    # 当前状态（取最后一个样本）
    $currentStatus = $Data[-1]

    # JSON 格式
    $summaryJson = @{
        SummaryPeriod = @{
            StartTime = $StartTime.ToString("yyyy-MM-dd HH:mm:ss")
            EndTime = $EndTime.ToString("yyyy-MM-dd HH:mm:ss")
            Duration = $duration.TotalMinutes.ToString("F2") + " minutes"
        }
        Statistics = @{
            TotalSamples = $totalSamples
            ProcessUptime = "$uptimePercent%"
            ConfigMatchRate = "$matchPercent%"
            OverrideActive = $overrideActive
            SuccessSwitches = $successCount
            FailedSwitches = $failedCount
        }
        CurrentState = @{
            Timestamp = $currentStatus.Timestamp
            ProcessRunning = $currentStatus.ProcessRunning
            ProcessId = $currentStatus.ProcessId
            CurrentConfig = $currentStatus.CurrentConfig
            ExpectedConfig = $currentStatus.ExpectedConfig
            ConfigMatch = $currentStatus.ConfigMatch
            OverrideActive = $currentStatus.OverrideActive
            SwitchStatus = $currentStatus.SwitchStatus
            SwitchVerified = $currentStatus.SwitchVerified
        }
        Samples = $Data
    }

    # Markdown 格式
    $summaryMd = @"
# FanControl 监控报告

**监控时段：** $($StartTime.ToString('yyyy-MM-dd HH:mm:ss')) - $($EndTime.ToString('yyyy-MM-dd HH:mm:ss'))
**持续时间：** $($duration.TotalMinutes.ToString('F2')) 分钟

---

## 📊 统计摘要

| 指标 | 数值 |
|------|------|
| 总采样数 | $totalSamples |
| 进程在线率 | $uptimePercent% |
| 配置匹配率 | $matchPercent% |
| Override 状态 | $(if ($overrideActive) { "激活" } else { "未激活" }) |
| 成功切换 | $successCount |
| 失败切换 | $failedCount |

---

## 📈 当前状态

**时间：** $($currentStatus.Timestamp)

| 项目 | 状态 |
|------|------|
| 进程状态 | $(if ($currentStatus.ProcessRunning) { "✅ 运行中 (PID: $($currentStatus.ProcessId))" } else { "❌ 未运行" }) |
| 当前配置 | $($currentStatus.CurrentConfig) |
| 期望配置 | $($currentStatus.ExpectedConfig) |
| 配置匹配 | $(if ($currentStatus.ConfigMatch) { "✅ 是" } else { "❌ 否" }) |
| Override | $(if ($currentStatus.OverrideActive) { "⚠️ 激活 ($($currentStatus.OverrideMode))" } else { "✅ 未激活" }) |
| 切换状态 | $($currentStatus.SwitchStatus) |
| 验证状态 | $(if ($currentStatus.SwitchVerified) { "✅ 已验证" } else { "❌ 未验证" }) |

---

## 📝 详细数据

| 时间 | 进程 | 配置 | 匹配 | Override | 状态 |
|------|------|------|------|----------|------|
"@

    foreach ($sample in $Data) {
        $processIcon = if ($sample.ProcessRunning) { "✅" } else { "❌" }
        $matchIcon = if ($sample.ConfigMatch) { "✅" } else { "❌" }
        $overrideIcon = if ($sample.OverrideActive) { "⚠️" } else { "✅" }
        $statusIcon = if ($sample.SwitchStatus -eq "SUCCESS") { "✅" } else { "❌" }

        $summaryMd += "`n| $($sample.Timestamp) | $processIcon | $($sample.CurrentConfig) | $matchIcon | $overrideIcon | $statusIcon |"
    }

    $summaryMd += @"

---

**报告生成时间：** $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
**监控持续运行中...**
"@

    # 保存文件
    $timestamp = $EndTime.ToString("yyyyMMdd_HHmmss")
    $jsonFile = "$OutputDir\monitor_$timestamp.json"
    $mdFile = "$OutputDir\monitor_$timestamp.md"

    $summaryJson | ConvertTo-Json -Depth 10 | Out-File -FilePath $jsonFile -Encoding UTF8
    $summaryMd | Out-File -FilePath $mdFile -Encoding UTF8

    return @{
        JsonFile = $jsonFile
        MdFile = $mdFile
        Statistics = $summaryJson.Statistics
    }
}

# ============ 主监控循环 ============
Write-Host "======================================" -ForegroundColor Cyan
Write-Host "  FanControl 持续监控系统" -ForegroundColor Cyan
Write-Host "======================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "配置:" -ForegroundColor Yellow
Write-Host "  数据采集间隔: $IntervalSeconds 秒" -ForegroundColor White
Write-Host "  总结间隔: $SummaryMinutes 分钟" -ForegroundColor White
Write-Host "  输出目录: $OutputDir" -ForegroundColor White
Write-Host ""
Write-Host "监控运行中... (按 Ctrl+C 停止)" -ForegroundColor Green
Write-Host ""

try {
    while ($true) {
        # 采集数据
        $currentStatus = Get-CurrentStatus
        $monitorData += $currentStatus
        $cycleCount++

        # 显示实时状态（单行）
        $statusIcon = if ($currentStatus.ProcessRunning) { "✅" } else { "❌" }
        $configIcon = if ($currentStatus.ConfigMatch) { "✅" } else { "❌" }
        $timeStr = Get-Date -Format "HH:mm:ss"

        Write-Host "`r[$timeStr] 进程:$statusIcon 配置:$($currentStatus.CurrentConfig) 匹配:$configIcon 样本数:$cycleCount" -NoNewline -ForegroundColor Cyan

        # 检查是否需要生成总结
        $elapsed = (Get-Date) - $lastSummaryTime
        if ($elapsed.TotalMinutes -ge $SummaryMinutes) {
            Write-Host "" -NoNewline
            Write-Host "`n正在生成 $SummaryMinutes 分钟总结..." -ForegroundColor Yellow

            # 生成总结
            $result = Write-Summary -Data $monitorData -StartTime $lastSummaryTime -EndTime (Get-Date)

            # 显示统计
            Write-Host "总结完成!" -ForegroundColor Green
            Write-Host "  JSON: $($result.JsonFile)" -ForegroundColor White
            Write-Host "  MD: $($result.MdFile)" -ForegroundColor White
            Write-Host "  进程在线率: $($result.Statistics.ProcessUptime)" -ForegroundColor White
            Write-Host "  配置匹配率: $($result.Statistics.ConfigMatchRate)" -ForegroundColor White
            Write-Host ""

            # 重置
            $monitorData = @()
            $lastSummaryTime = Get-Date
            $cycleCount = 0

            Write-Host "继续监控... (按 Ctrl+C 停止)" -ForegroundColor Green
        }

        Start-Sleep -Seconds $IntervalSeconds
    }
} catch [System.Management.Automation.PipelineStoppedException] {
    # Ctrl+C 中断
    Write-Host "`n`n监控已停止" -ForegroundColor Yellow

    if ($monitorData.Count -gt 0) {
        Write-Host "正在生成最终总结..." -ForegroundColor Yellow
        $result = Write-Summary -Data $monitorData -StartTime $lastSummaryTime -EndTime (Get-Date)
        Write-Host "最终总结已保存:" -ForegroundColor Green
        Write-Host "  JSON: $($result.JsonFile)" -ForegroundColor White
        Write-Host "  MD: $($result.MdFile)" -ForegroundColor White
    }

    Write-Host "`n感谢使用 FanControl 监控系统!" -ForegroundColor Cyan
}
