param(
    [ValidateSet('Snapshot', 'Watch', 'Sample')][string]$Mode = 'Sample',
    [int]$IntervalSeconds = 10,
    [int]$SummaryMinutes = 1,
    [int]$MaxSamples = 0,
    [string]$OutputDir = ''
)

$RuntimePathsHelper = Join-Path $PSScriptRoot "runtime_paths.ps1"
$RuntimeStateHelper = Join-Path $PSScriptRoot "runtime_state.ps1"
$HardwareMetricsHelper = Join-Path $PSScriptRoot "hardware_metrics.ps1"

foreach ($helper in @($RuntimePathsHelper, $RuntimeStateHelper, $HardwareMetricsHelper)) {
    if (Test-Path $helper) {
        . $helper
    } else {
        throw "Helper file not found: $helper"
    }
}

$Paths = Get-FanControlPaths
if (-not $OutputDir) {
    $OutputDir = $Paths.MonitorDir
}

New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
$InvariantCulture = [System.Globalization.CultureInfo]::InvariantCulture

function New-MonitorFilePath {
    param([string]$Prefix)

    $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    return Join-Path $OutputDir "$Prefix`_$timestamp.json"
}

function Write-MonitorJson {
    param(
        [Parameter(Mandatory = $true)][string]$Prefix,
        [Parameter(Mandatory = $true)]$Payload
    )

    $path = New-MonitorFilePath -Prefix $Prefix
    $Payload | ConvertTo-Json -Depth 6 | Set-Content -Path $path -Encoding UTF8
    return $path
}

function New-MonitorSample {
    $runtimeState = Get-FanControlRuntimeState
    $hardwareMetrics = Get-FanControlHardwareMetrics

    return [PSCustomObject]@{
        Timestamp = $runtimeState.Timestamp
        Runtime = $runtimeState
        Hardware = $hardwareMetrics
    }
}

function Format-SummaryValue {
    param($Value)

    if ($null -eq $Value) {
        return 'NA'
    }

    if ($Value -is [double] -or $Value -is [single] -or $Value -is [decimal]) {
        if ([math]::Abs($Value - [math]::Round($Value, 0)) -lt 0.05) {
            return ([int][math]::Round($Value, 0)).ToString($InvariantCulture)
        }

        return ([math]::Round($Value, 1)).ToString('0.0', $InvariantCulture)
    }

    if ($Value -is [System.IFormattable]) {
        return $Value.ToString($null, $InvariantCulture)
    }

    return $Value.ToString()
}

function Write-StateSummary {
    param([Parameter(Mandatory = $true)]$Sample)

    $runtime = $Sample.Runtime
    $hardware = $Sample.Hardware
    $processText = if ($runtime.ProcessRunning) { 'OK' } else { 'X' }
    $configText = if ($runtime.EffectiveConfig) { $runtime.EffectiveConfig } else { 'N/A' }
    $desiredText = if ($runtime.DesiredConfig) { $runtime.DesiredConfig } else { 'N/A' }
    $confidenceText = if ($runtime.StateConfidence) { $runtime.StateConfidence } else { 'Unknown' }
    $verificationText = if ($runtime.VerificationConfidence) { $runtime.VerificationConfidence } else { 'Unknown' }
    $fanValues = (@(
        (Format-SummaryValue -Value $hardware.CpuFanRpm),
        (Format-SummaryValue -Value $hardware.SystemFan2Rpm),
        (Format-SummaryValue -Value $hardware.SystemFan3Rpm),
        (Format-SummaryValue -Value $hardware.SystemFan4Rpm)
    ) -join '/')
    $summaryParts = @(
        ("[{0}]" -f $Sample.Timestamp),
        ("Process:{0}" -f $processText),
        ("Desired:{0}" -f $desiredText),
        ("Effective:{0}" -f $configText),
        ("Verify:{0}" -f $verificationText),
        ("Confidence:{0}" -f $confidenceText),
        ("CPU:{0}C" -f (Format-SummaryValue -Value $hardware.CpuPackage)),
        ("CoreAvg:{0}C" -f (Format-SummaryValue -Value $hardware.CoreAverage)),
        ("Dist:{0}C" -f (Format-SummaryValue -Value $hardware.MinDistanceToTjMax)),
        ("Load:{0}%" -f (Format-SummaryValue -Value $hardware.CpuLoadPercent)),
        ("Clock:{0}MHz" -f (Format-SummaryValue -Value $hardware.EffectiveClockMHz)),
        ("Fans:{0}" -f $fanValues),
        ("Total:{0}" -f (Format-SummaryValue -Value $hardware.TotalFanRpm))
    )

    Write-Host ($summaryParts -join ' ')
}

function Invoke-SnapshotMode {
    $sample = New-MonitorSample
    $path = Write-MonitorJson -Prefix 'snapshot' -Payload $sample
    Write-StateSummary -Sample $sample
    Write-Host "Saved: $(Split-Path $path -Leaf)"
}

function Invoke-SampleMode {
    $samples = @()
    $startedAt = Get-Date
    $lastFlushAt = $startedAt

    try {
        while ($true) {
            $sample = New-MonitorSample
            $samples += $sample
            Write-StateSummary -Sample $sample

            $reachedMaxSamples = ($MaxSamples -gt 0 -and $samples.Count -ge $MaxSamples)
            $reachedSummaryWindow = (((Get-Date) - $lastFlushAt).TotalMinutes -ge $SummaryMinutes)

            if ($reachedMaxSamples -or $reachedSummaryWindow) {
                $payload = [PSCustomObject]@{
                    Mode = 'Sample'
                    StartedAt = $startedAt.ToString('yyyy-MM-dd HH:mm:ss')
                    EndedAt = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
                    SampleCount = $samples.Count
                    Samples = $samples
                }

                $path = Write-MonitorJson -Prefix 'monitor' -Payload $payload
                Write-Host "Saved: $(Split-Path $path -Leaf)"

                if ($reachedMaxSamples) {
                    break
                }

                $samples = @()
                $lastFlushAt = Get-Date
            }

            Start-Sleep -Seconds $IntervalSeconds
        }
    } catch {
        if ($samples.Count -gt 0) {
            $payload = [PSCustomObject]@{
                Mode = 'Sample'
                StartedAt = $startedAt.ToString('yyyy-MM-dd HH:mm:ss')
                EndedAt = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
                SampleCount = $samples.Count
                Samples = $samples
            }

            $path = Write-MonitorJson -Prefix 'monitor' -Payload $payload
            Write-Host "Saved: $(Split-Path $path -Leaf)"
        }

        throw
    }
}

function Invoke-WatchMode {
    $sampleCount = 0

    while ($true) {
        $sample = New-MonitorSample
        $sampleCount++
        Write-StateSummary -Sample $sample

        if ($MaxSamples -gt 0 -and $sampleCount -ge $MaxSamples) {
            break
        }

        Start-Sleep -Seconds $IntervalSeconds
    }
}

switch ($Mode) {
    'Snapshot' { Invoke-SnapshotMode }
    'Watch' { Invoke-WatchMode }
    'Sample' { Invoke-SampleMode }
}
