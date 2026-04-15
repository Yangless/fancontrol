# FanControl 状态查看工具
# 用途：快速查看统一运行时状态和最近切换结果

param([switch]$Watch)

$RuntimePathsHelper = Join-Path $PSScriptRoot "runtime_paths.ps1"
$RuntimeStateHelper = Join-Path $PSScriptRoot "runtime_state.ps1"

if (Test-Path $RuntimePathsHelper) {
    . $RuntimePathsHelper
} else {
    throw "Helper file not found: $RuntimePathsHelper"
}

if (Test-Path $RuntimeStateHelper) {
    . $RuntimeStateHelper
} else {
    throw "Helper file not found: $RuntimeStateHelper"
}

$Paths = Get-FanControlPaths
$LogFile = Join-Path $Paths.LogDir 'auto_switch.log'

function Write-StateLine {
    param(
        [string]$Label,
        [object]$Value,
        [string]$Color = 'White'
    )

    $text = if ($null -eq $Value) {
        'N/A'
    } elseif ($Value -is [string] -and $Value -eq '') {
        'N/A'
    } else {
        [string]$Value
    }

    Write-Host ("  {0,-18}: {1}" -f $Label, $text) -ForegroundColor $Color
}

function Get-StatusReport {
    $state = Get-FanControlRuntimeState

    Write-Host ""
    Write-Host "======================================" -ForegroundColor Cyan
    Write-Host "  FanControl Status Report" -ForegroundColor Cyan
    Write-Host "======================================" -ForegroundColor Cyan
    Write-Host ""

    Write-Host "[Unified Runtime State]" -ForegroundColor Yellow
    Write-StateLine -Label 'Timestamp' -Value $state.Timestamp
    Write-StateLine -Label 'DesiredConfig' -Value $state.DesiredConfig
    Write-StateLine -Label 'EffectiveConfig' -Value $state.EffectiveConfig
    Write-StateLine -Label 'OverrideActive' -Value $state.OverrideActive -Color $(if ($state.OverrideActive) { 'Yellow' } else { 'Green' })
    Write-StateLine -Label 'OverrideMode' -Value $state.OverrideMode
    Write-StateLine -Label 'ProcessRunning' -Value $state.ProcessRunning -Color $(if ($state.ProcessRunning) { 'Green' } else { 'Red' })
    Write-StateLine -Label 'VerificationStatus' -Value $state.VerificationStatus -Color $(if ($state.VerificationStatus -eq 'SUCCESS') { 'Green' } elseif ($state.VerificationStatus -eq 'Unknown') { 'Yellow' } else { 'Red' })
    Write-StateLine -Label 'VerificationConfidence' -Value $state.VerificationConfidence -Color $(if ($state.VerificationConfidence -eq 'High') { 'Green' } elseif ($state.VerificationConfidence -eq 'Medium') { 'Yellow' } elseif ($state.VerificationConfidence -eq 'Unknown') { 'Yellow' } else { 'Red' })
    Write-StateLine -Label 'CommandIssued' -Value $state.CommandIssued
    Write-StateLine -Label 'ObservedConfig' -Value $state.ObservedConfig
    Write-StateLine -Label 'ObservedAt' -Value $state.ObservedAt
    Write-StateLine -Label 'StateConfidence' -Value $state.StateConfidence -Color $(if ($state.StateConfidence -eq 'High') { 'Green' } elseif ($state.StateConfidence -eq 'Medium') { 'Yellow' } else { 'Red' })
    Write-StateLine -Label 'CacheReadable' -Value $state.CacheReadable -Color $(if ($state.CacheReadable) { 'Green' } else { 'Red' })
    Write-StateLine -Label 'StatusReadable' -Value $state.StatusReadable -Color $(if ($state.StatusReadable) { 'Green' } else { 'Red' })
    Write-StateLine -Label 'CacheAgeSeconds' -Value $state.CacheAgeSeconds
    Write-StateLine -Label 'StatusAgeSeconds' -Value $state.StatusAgeSeconds
    Write-Host ""

    Write-Host "[Last Status File]" -ForegroundColor Yellow
    if ($state.LastStatus) {
        Write-StateLine -Label 'LastStatus' -Value $state.LastStatus.Status
        Write-StateLine -Label 'LastTarget' -Value $state.LastStatus.TargetConfig
        Write-StateLine -Label 'LastActual' -Value $state.LastStatus.ActualConfig
        Write-StateLine -Label 'LastMessage' -Value $state.LastStatus.Message
    } else {
        Write-Host "  No readable status file" -ForegroundColor Yellow
    }
    Write-Host ""

    Write-Host "[Recent Logs]" -ForegroundColor Yellow
    if (Test-Path $LogFile) {
        Get-Content $LogFile -Tail 5 | ForEach-Object {
            Write-Host "  $_" -ForegroundColor Gray
        }
    } else {
        Write-Host "  No log file found" -ForegroundColor Yellow
    }
    Write-Host ""

    Write-Host "======================================" -ForegroundColor Cyan
}

if ($Watch) {
    while ($true) {
        Clear-Host
        Get-StatusReport
        Write-Host "Monitoring... (Press Ctrl+C to exit)" -ForegroundColor Gray
        Start-Sleep -Seconds 5
    }
} else {
    Get-StatusReport
}
