# Simple monitor script for testing
param(
    [int]$IntervalSeconds = 10,
    [int]$SummaryMinutes = 1,
    [string]$OutputDir = "C:\FanControl_Auto\monitor_data"
)

$StatusFile = "C:\FanControl_Auto\state\current_status.json"
$CacheFile = "D:\Program Files (x86)\FanControl\Configurations\CACHE"

New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

$monitorData = @()
$lastSummaryTime = Get-Date

function Get-Status {
    $status = @{
        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        ProcessRunning = (Get-Process -Name FanControl -ErrorAction SilentlyContinue) -ne $null
        CurrentConfig = $null
        ExpectedConfig = $null
        ConfigMatch = $false
    }

    if (Test-Path $CacheFile) {
        $cache = Get-Content $CacheFile | ConvertFrom-Json
        $status.CurrentConfig = $cache.CurrentConfigFileName
    }

    $min = (Get-Date).Hour * 60 + (Get-Date).Minute
    $status.ExpectedConfig = if (($min -ge 760 -and $min -lt 840) -or ($min -ge 1260) -or ($min -lt 480)) { "Quiet_mode.json" } else { "Game.json" }

    if ($status.CurrentConfig) {
        $status.ConfigMatch = ($status.CurrentConfig -eq $status.ExpectedConfig)
    }

    return $status
}

Write-Host "Monitoring started... (Ctrl+C to stop)"

try {
    while ($true) {
        $status = Get-Status
        $monitorData += $status

        Write-Host "`r[$($status.Timestamp)] Process:$(if($status.ProcessRunning){'OK'}else{'X'}) Config:$($status.CurrentConfig) Match:$(if($status.ConfigMatch){'OK'}else{'X'}) Samples:$($monitorData.Count)" -NoNewline

        if (((Get-Date) - $lastSummaryTime).TotalMinutes -ge $SummaryMinutes) {
            Write-Host "`nSaving summary..."

            $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
            $monitorData | ConvertTo-Json | Out-File "$OutputDir\monitor_$timestamp.json"

            Write-Host "Saved: monitor_$timestamp.json"
            $monitorData = @()
            $lastSummaryTime = Get-Date
        }

        Start-Sleep -Seconds $IntervalSeconds
    }
} catch {
    if ($monitorData.Count -gt 0) {
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $monitorData | ConvertTo-Json | Out-File "$OutputDir\monitor_$timestamp.json"
        Write-Host "`nFinal summary saved"
    }
}
