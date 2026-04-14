# FanControl 状态查看工具
# 用途：快速查看当前配置状态、验证结果和进程信息

param([switch]$Watch) # 持续监控模式

$StatusFile = "C:\FanControl_Auto\state\current_status.json"
$LogFile = "C:\FanControl_Auto\logs\auto_switch.log"
$SwitchLog = "C:\FanControl_Auto\logs\switch.log"
$CacheFile = "D:\Program Files (x86)\FanControl\Configurations\CACHE"
$OverrideFlag = "C:\FanControl_Auto\state\override.flag"
$TimePolicyHelper = Join-Path $PSScriptRoot "time_policy.ps1"

if (Test-Path $TimePolicyHelper) {
    . $TimePolicyHelper
} else {
    throw "Helper file not found: $TimePolicyHelper"
}

function Get-StatusReport {
    Write-Host ""
    Write-Host "======================================" -ForegroundColor Cyan
    Write-Host "  FanControl Status Report" -ForegroundColor Cyan
    Write-Host "======================================" -ForegroundColor Cyan
    Write-Host ""

    # 1. 进程状态
    Write-Host "[Process Status]" -ForegroundColor Yellow
    $process = Get-Process -Name FanControl -ErrorAction SilentlyContinue
    if ($process) {
        Write-Host "  Status      : Running" -ForegroundColor Green
        Write-Host "  PID         : $($process.Id)" -ForegroundColor White
        Write-Host "  Started     : $($process.StartTime)" -ForegroundColor White
    } else {
        Write-Host "  Status      : Not Running" -ForegroundColor Red
    }
    Write-Host ""

    # 2. 配置文件状态
    Write-Host "[Configuration]" -ForegroundColor Yellow
    if (Test-Path $CacheFile) {
        try {
            $cache = Get-Content $CacheFile | ConvertFrom-Json
            Write-Host "  Current     : $($cache.CurrentConfigFileName)" -ForegroundColor Green
            Write-Host "  Config Dir  : $($cache.CustomConfigFolder)" -ForegroundColor White
        } catch {
            Write-Host "  Current     : Unable to read CACHE" -ForegroundColor Red
        }
    } else {
        Write-Host "  Current     : CACHE file not found" -ForegroundColor Red
    }
    Write-Host ""

    # 3. Override 状态
    Write-Host "[Override Status]" -ForegroundColor Yellow
    if (Test-Path $OverrideFlag) {
        $overrideMode = Get-Content $OverrideFlag -ErrorAction SilentlyContinue
        Write-Host "  Status      : Active" -ForegroundColor Yellow
        Write-Host "  Mode        : $overrideMode" -ForegroundColor White
    } else {
        Write-Host "  Status      : Inactive (Auto mode)" -ForegroundColor Green
    }
    Write-Host ""

    # 4. 最后一次切换状态
    Write-Host "[Last Switch Status]" -ForegroundColor Yellow
    if (Test-Path $StatusFile) {
        try {
            $status = Get-Content $StatusFile | ConvertFrom-Json
            Write-Host "  Timestamp   : $($status.Timestamp)" -ForegroundColor White
            Write-Host "  Target      : $($status.TargetConfig)" -ForegroundColor White
            Write-Host "  Actual      : $($status.ActualConfig)" -ForegroundColor White
            Write-Host "  Status      : $($status.Status)" -ForegroundColor $(if ($status.Status -eq "SUCCESS") { "Green" } else { "Red" })
            Write-Host "  Verified    : $($status.Verified)" -ForegroundColor $(if ($status.Verified) { "Green" } else { "Yellow" })

            # 显示验证结果详情
            if ($status.TargetConfig -eq $status.ActualConfig -and $status.ActualConfig -ne $null) {
                Write-Host "  Result      : Configuration matched!" -ForegroundColor Green
            } elseif ($status.ActualConfig -ne $null) {
                Write-Host "  Result      : MISMATCH! Target: $($status.TargetConfig), Actual: $($status.ActualConfig)" -ForegroundColor Red
            }
        } catch {
            Write-Host "  Status file corrupted" -ForegroundColor Red
        }
    } else {
        Write-Host "  No status file found" -ForegroundColor Yellow
    }
    Write-Host ""

    # 5. 最近日志（最后 5 条）
    Write-Host "[Recent Logs]" -ForegroundColor Yellow
    if (Test-Path $LogFile) {
        $logs = Get-Content $LogFile -Tail 5
        $logs | ForEach-Object { Write-Host "  $_" -ForegroundColor Gray }
    } else {
        Write-Host "  No log file found" -ForegroundColor Yellow
    }
    Write-Host ""

    # 6. 时间判断
    Write-Host "[Current Time Period]" -ForegroundColor Yellow
    $currentConfig = Get-ConfigNameForMinute -Minute (Get-MinuteOfDay)
    Write-Host "  Current Time: $(Get-Date -Format 'HH:mm:ss')" -ForegroundColor White
    Write-Host "  Should Be    : $currentConfig" -ForegroundColor White

    # 对比实际配置
    if (Test-Path $CacheFile) {
        $cache = Get-Content $CacheFile | ConvertFrom-Json
        if ($cache.CurrentConfigFileName -eq $currentConfig) {
            Write-Host "  Match       : YES" -ForegroundColor Green
        } else {
            Write-Host "  Match       : NO (Expected: $currentConfig, Actual: $($cache.CurrentConfigFileName))" -ForegroundColor Red
        }
    }
    Write-Host ""

    Write-Host "======================================" -ForegroundColor Cyan
}

# 主逻辑
if ($Watch) {
    # 持续监控模式（每 5 秒刷新一次）
    while ($true) {
        Clear-Host
        Get-StatusReport
        Write-Host "Monitoring... (Press Ctrl+C to exit)" -ForegroundColor Gray
        Start-Sleep -Seconds 5
    }
} else {
    # 单次显示
    Get-StatusReport
}
