param(
    [ValidateSet('Snapshot', 'Watch', 'Sample')][string]$Mode = 'Sample',
    [int]$IntervalSeconds = 10,
    [int]$SummaryMinutes = 1,
    [int]$MaxSamples = 0,
    [string]$OutputDir = ''
)

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
if (-not $OutputDir) {
    $OutputDir = $Paths.MonitorDir
}

New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null

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

function Write-StateSummary {
    param([Parameter(Mandatory = $true)]$State)

    $processText = if ($State.ProcessRunning) { 'OK' } else { 'X' }
    $configText = if ($State.EffectiveConfig) { $State.EffectiveConfig } else { 'N/A' }
    $desiredText = if ($State.DesiredConfig) { $State.DesiredConfig } else { 'N/A' }
    $confidenceText = if ($State.StateConfidence) { $State.StateConfidence } else { 'Unknown' }
    $verificationText = if ($State.VerificationConfidence) { $State.VerificationConfidence } else { 'Unknown' }

    Write-Host ("[{0}] Process:{1} Desired:{2} Effective:{3} Verify:{4} Confidence:{5}" -f `
        $State.Timestamp,
        $processText,
        $desiredText,
        $configText,
        $verificationText,
        $confidenceText)
}

function Invoke-SnapshotMode {
    $state = Get-FanControlRuntimeState
    $path = Write-MonitorJson -Prefix 'snapshot' -Payload $state
    Write-StateSummary -State $state
    Write-Host "Saved: $(Split-Path $path -Leaf)"
}

function Invoke-SampleMode {
    $samples = @()
    $startedAt = Get-Date
    $lastFlushAt = $startedAt

    try {
        while ($true) {
            $state = Get-FanControlRuntimeState
            $samples += $state
            Write-StateSummary -State $state

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
        $state = Get-FanControlRuntimeState
        $sampleCount++
        Write-StateSummary -State $state

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
