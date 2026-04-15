$RuntimePathsHelper = Join-Path $PSScriptRoot "runtime_paths.ps1"
$TimePolicyHelper = Join-Path $PSScriptRoot "time_policy.ps1"

if (Test-Path $RuntimePathsHelper) {
    . $RuntimePathsHelper
} else {
    throw "Helper file not found: $RuntimePathsHelper"
}

if (Test-Path $TimePolicyHelper) {
    . $TimePolicyHelper
} else {
    throw "Helper file not found: $TimePolicyHelper"
}

function Get-OverrideTargetConfigName {
    param([string]$OverrideMode)

    $normalizedOverrideMode = if ($null -eq $OverrideMode) {
        ''
    } else {
        $OverrideMode.Trim().ToLowerInvariant()
    }

    switch ($normalizedOverrideMode) {
        'quiet' { return 'Quiet_mode.json' }
        'game' { return 'Game.json' }
        default { return $null }
    }
}

function Get-FanControlRuntimeState {
    param(
        [datetime]$Now = (Get-Date),
        [int]$StatusFreshSeconds = 300
    )

    $paths = Get-FanControlPaths
    $overrideMode = $null
    $overrideActive = Test-Path $paths.OverrideFlag

    if ($overrideActive) {
        $overrideMode = (Get-Content -Path $paths.OverrideFlag -Raw -ErrorAction SilentlyContinue).Trim()
    }

    $desiredConfig = Get-OverrideTargetConfigName -OverrideMode $overrideMode
    if (-not $desiredConfig) {
        $desiredConfig = Get-ConfigNameForMinute -Minute (Get-MinuteOfDay -Date $Now)
    }

    $processRunning = if ($env:FANCONTROL_TEST_PROCESS_RUNNING) {
        [System.Convert]::ToBoolean($env:FANCONTROL_TEST_PROCESS_RUNNING)
    } else {
        (Get-Process -Name FanControl -ErrorAction SilentlyContinue) -ne $null
    }

    $effectiveConfig = $null
    $cacheReadable = $false
    $cacheAgeSeconds = $null

    if (Test-Path $paths.CacheFile) {
        try {
            $cacheItem = Get-Item -Path $paths.CacheFile
            $cacheAgeSeconds = [int][Math]::Max(0, [Math]::Round(($Now - $cacheItem.LastWriteTime).TotalSeconds))
            $cache = Get-Content -Path $paths.CacheFile -Raw | ConvertFrom-Json
            $effectiveConfig = $cache.CurrentConfigFileName
            $cacheReadable = $true
        } catch {
            $cacheReadable = $false
            $effectiveConfig = $null
        }
    }

    $lastStatus = $null
    $statusReadable = $false
    $statusAgeSeconds = $null
    $verificationStatus = 'Unknown'
    $verificationConfidence = 'Unknown'
    $commandIssued = $false
    $observedConfig = $null
    $observedAt = $null

    if (Test-Path $paths.StatusFile) {
        try {
            $statusItem = Get-Item -Path $paths.StatusFile
            $statusAgeSeconds = [int][Math]::Max(0, [Math]::Round(($Now - $statusItem.LastWriteTime).TotalSeconds))
            $lastStatus = Get-Content -Path $paths.StatusFile -Raw | ConvertFrom-Json
            $statusReadable = $true

            if ($statusAgeSeconds -le $StatusFreshSeconds -and $lastStatus.Status) {
                $verificationStatus = [string]$lastStatus.Status
                if ($lastStatus.VerificationConfidence) {
                    $verificationConfidence = [string]$lastStatus.VerificationConfidence
                }
                if ($null -ne $lastStatus.CommandIssued) {
                    $commandIssued = [bool]$lastStatus.CommandIssued
                }
                if ($lastStatus.ObservedConfig) {
                    $observedConfig = [string]$lastStatus.ObservedConfig
                } elseif ($lastStatus.ActualConfig) {
                    $observedConfig = [string]$lastStatus.ActualConfig
                }
                if ($lastStatus.ObservedAt) {
                    $observedAt = [string]$lastStatus.ObservedAt
                }
            }
        } catch {
            $statusReadable = $false
            $lastStatus = $null
            $verificationStatus = 'Unknown'
        }
    }

    $desiredMatchesEffective = $cacheReadable -and $desiredConfig -and $effectiveConfig -and ($desiredConfig -eq $effectiveConfig)
    $hasConflict = $cacheReadable -and $desiredConfig -and $effectiveConfig -and ($desiredConfig -ne $effectiveConfig)

    $stateConfidence = if ($hasConflict) {
        'Low'
    } elseif ($processRunning -and $desiredMatchesEffective) {
        'High'
    } elseif ($desiredMatchesEffective -or ($verificationStatus -ne 'Unknown')) {
        'Medium'
    } else {
        'Low'
    }

    return [PSCustomObject]@{
        Timestamp = $Now.ToString('yyyy-MM-dd HH:mm:ss')
        DesiredConfig = $desiredConfig
        EffectiveConfig = $effectiveConfig
        OverrideActive = $overrideActive
        OverrideMode = $overrideMode
        ProcessRunning = $processRunning
        VerificationStatus = $verificationStatus
        VerificationConfidence = $verificationConfidence
        CommandIssued = $commandIssued
        ObservedConfig = $observedConfig
        ObservedAt = $observedAt
        StateConfidence = $stateConfidence
        CacheReadable = $cacheReadable
        StatusReadable = $statusReadable
        CacheAgeSeconds = $cacheAgeSeconds
        StatusAgeSeconds = $statusAgeSeconds
        LastStatus = $lastStatus
    }
}
