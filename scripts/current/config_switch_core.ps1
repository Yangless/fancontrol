$RuntimePathsHelper = Join-Path $PSScriptRoot "runtime_paths.ps1"
$RuntimeStateHelper = Join-Path $PSScriptRoot "runtime_state.ps1"
$RecoveryHelper = Join-Path $PSScriptRoot "auto_switch_recovery.ps1"

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

if (Test-Path $RecoveryHelper) {
    . $RecoveryHelper
} else {
    throw "Helper file not found: $RecoveryHelper"
}

function Invoke-ConfigSwitchLog {
    param(
        [scriptblock]$LogAction,
        [string]$Message
    )

    if ($LogAction) {
        & $LogAction $Message
    }
}

function Resolve-FanControlConfigPath {
    param(
        [Parameter(Mandatory = $true)][string]$ConfigName,
        $Paths = (Get-FanControlPaths)
    )

    switch ($ConfigName) {
        'Game.json' { return $Paths.GameConfig }
        'Quiet_mode.json' { return $Paths.QuietConfig }
        default { return (Join-Path $Paths.ConfigDir $ConfigName) }
    }
}

function Get-FanControlProcessRunning {
    if ($env:FANCONTROL_TEST_PROCESS_RUNNING) {
        return [System.Convert]::ToBoolean($env:FANCONTROL_TEST_PROCESS_RUNNING)
    }

    return (Get-Process -Name FanControl -ErrorAction SilentlyContinue) -ne $null
}

function Get-FanControlCacheObservation {
    param(
        $Paths = (Get-FanControlPaths),
        [datetime]$Now = (Get-Date)
    )

    $observation = [ordered]@{
        CacheReadable = $false
        ObservedConfig = $null
        ObservedAt = $null
        ObservedAtDateTime = $null
        CacheAgeSeconds = $null
    }

    if (-not (Test-Path $Paths.CacheFile)) {
        return [PSCustomObject]$observation
    }

    try {
        $cacheItem = Get-Item -Path $Paths.CacheFile
        $cache = Get-Content -Path $Paths.CacheFile -Raw | ConvertFrom-Json

        $observation.CacheReadable = $true
        $observation.ObservedConfig = $cache.CurrentConfigFileName
        $observation.ObservedAtDateTime = $cacheItem.LastWriteTime
        $observation.ObservedAt = $cacheItem.LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss')
        $observation.CacheAgeSeconds = [int][Math]::Max(0, [Math]::Round(($Now - $cacheItem.LastWriteTime).TotalSeconds))
    } catch {
        $observation.CacheReadable = $false
    }

    return [PSCustomObject]$observation
}

function Get-FanControlVerificationConfidence {
    param(
        [Parameter(Mandatory = $true)][string]$TargetConfig,
        [Parameter(Mandatory = $true)]$Observation,
        [Nullable[datetime]]$CommandStartedAt = $null
    )

    if (-not $Observation.CacheReadable -or -not $Observation.ObservedConfig) {
        return 'Low'
    }

    if ($Observation.ObservedConfig -ne $TargetConfig) {
        return 'Low'
    }

    if ($CommandStartedAt -and $Observation.ObservedAtDateTime -and $Observation.ObservedAtDateTime -gt $CommandStartedAt) {
        return 'High'
    }

    return 'Medium'
}

function Write-FanControlStatus {
    param(
        [Parameter(Mandatory = $true)][string]$TargetConfig,
        [Parameter(Mandatory = $true)][string]$Status,
        [Parameter(Mandatory = $true)][string]$Message,
        [bool]$Verified = $false,
        [bool]$CommandIssued = $false,
        [Nullable[datetime]]$CommandStartedAt = $null,
        [string]$ObservedConfig,
        [string]$ObservedAt,
        [string]$VerificationConfidence,
        $Paths = (Get-FanControlPaths)
    )

    $now = Get-Date
    $observation = Get-FanControlCacheObservation -Paths $Paths -Now $now

    if (-not $PSBoundParameters.ContainsKey('ObservedConfig')) {
        $ObservedConfig = $observation.ObservedConfig
    }

    if (-not $PSBoundParameters.ContainsKey('ObservedAt')) {
        $ObservedAt = $observation.ObservedAt
    }

    if (-not $PSBoundParameters.ContainsKey('VerificationConfidence')) {
        $VerificationConfidence = Get-FanControlVerificationConfidence `
            -TargetConfig $TargetConfig `
            -Observation $observation `
            -CommandStartedAt $CommandStartedAt
    }

    $statusData = @{
        Timestamp = $now.ToString('yyyy-MM-dd HH:mm:ss')
        TargetConfig = $TargetConfig
        ActualConfig = $ObservedConfig
        ObservedConfig = $ObservedConfig
        ObservedAt = $ObservedAt
        Status = $Status
        Message = $Message
        Verified = $Verified
        CommandIssued = $CommandIssued
        CommandIssuedAt = if ($CommandStartedAt) { $CommandStartedAt.ToString('yyyy-MM-dd HH:mm:ss') } else { $null }
        VerificationConfidence = $VerificationConfidence
        ProcessRunning = (Get-FanControlProcessRunning)
        ProcessId = $null
    }

    $process = Get-Process -Name FanControl -ErrorAction SilentlyContinue
    if ($process) {
        $statusData.ProcessId = $process.Id
    }

    if (-not $statusData.ActualConfig -and (Test-Path $Paths.CacheFile)) {
        try {
            $cache = Get-Content -Path $Paths.CacheFile -Raw | ConvertFrom-Json
            $statusData.ActualConfig = $cache.CurrentConfigFileName
            if (-not $statusData.ObservedConfig) {
                $statusData.ObservedConfig = $cache.CurrentConfigFileName
            }
        } catch {
            $statusData.ActualConfig = 'Unknown'
        }
    }

    $statusData | ConvertTo-Json -Depth 4 | Set-Content -Path $Paths.StatusFile -Encoding UTF8 -ErrorAction SilentlyContinue
}

function Test-FanControlConfigFiles {
    param(
        [string[]]$RequiredConfigs = @(),
        $Paths = (Get-FanControlPaths),
        [scriptblock]$LogAction
    )

    $errors = @()

    if (-not (Test-Path $Paths.FanControlExe)) {
        $errors += "FanControl.exe not found: $($Paths.FanControlExe)"
    }

    foreach ($configPath in $RequiredConfigs) {
        if (-not (Test-Path $configPath)) {
            $errors += "Config file not found: $configPath"
        }
    }

    if ($errors.Count -gt 0) {
        foreach ($errorMessage in $errors) {
            Invoke-ConfigSwitchLog -LogAction $LogAction -Message $errorMessage
        }

        throw ($errors -join '; ')
    }
}

function Test-FanControlConfigSwitch {
    param(
        [Parameter(Mandatory = $true)][string]$TargetConfigPath,
        $Paths = (Get-FanControlPaths),
        [int]$MaxWaitSeconds = 10,
        [Nullable[datetime]]$CommandStartedAt = $null,
        [scriptblock]$LogAction
    )

    if ($env:FANCONTROL_TEST_MAX_WAIT_SECONDS) {
        $MaxWaitSeconds = [int]$env:FANCONTROL_TEST_MAX_WAIT_SECONDS
    }

    $configName = Split-Path $TargetConfigPath -Leaf
    $waited = 0

    Invoke-ConfigSwitchLog -LogAction $LogAction -Message "Verifying config switch to: $configName"

    while ($waited -lt $MaxWaitSeconds) {
        Start-Sleep -Seconds 1
        $waited++

        $observation = Get-FanControlCacheObservation -Paths $Paths
        if ($observation.CacheReadable) {
            if ($observation.ObservedConfig -eq $configName) {
                $confidence = Get-FanControlVerificationConfidence `
                    -TargetConfig $configName `
                    -Observation $observation `
                    -CommandStartedAt $CommandStartedAt

                Invoke-ConfigSwitchLog -LogAction $LogAction -Message "SUCCESS: Config verified after ${waited}s - Actual: $($observation.ObservedConfig) - Confidence: $confidence"
                return [PSCustomObject]@{
                    Verified = $true
                    ObservedConfig = $observation.ObservedConfig
                    ObservedAt = $observation.ObservedAt
                    CacheReadable = $observation.CacheReadable
                    VerificationConfidence = $confidence
                    WaitedSeconds = $waited
                }
            }

            Invoke-ConfigSwitchLog -LogAction $LogAction -Message "Waiting... (${waited}s) - Target: $configName, Actual: $($observation.ObservedConfig)"
        } else {
            Invoke-ConfigSwitchLog -LogAction $LogAction -Message "Warning: Cannot read CACHE file (${waited}s)"
        }
    }

    $finalObservation = Get-FanControlCacheObservation -Paths $Paths
    return [PSCustomObject]@{
        Verified = $false
        ObservedConfig = $finalObservation.ObservedConfig
        ObservedAt = $finalObservation.ObservedAt
        CacheReadable = $finalObservation.CacheReadable
        VerificationConfidence = 'Low'
        WaitedSeconds = $waited
    }
}

function Invoke-FanControlConfigSwitch {
    param(
        [Parameter(Mandatory = $true)][string]$TargetConfigPath,
        [bool]$ProcessWasRunning,
        [switch]$UseTray,
        [string]$StatusPrefix = 'Switch',
        $Paths = (Get-FanControlPaths),
        [scriptblock]$LogAction
    )

    Test-FanControlConfigFiles -RequiredConfigs @($TargetConfigPath) -Paths $Paths -LogAction $LogAction

    $configName = Split-Path $TargetConfigPath -Leaf
    $commandStartedAt = Get-Date
    Invoke-ConfigSwitchLog -LogAction $LogAction -Message "Attempting to switch config: $configName"

    $verification = Invoke-ConfigSwitchWithRetry `
        -ProcessWasRunning:$ProcessWasRunning `
        -RunSwitchCommand {
            if ($UseTray) {
                & $Paths.FanControlExe -c $TargetConfigPath -tray
            } else {
                & $Paths.FanControlExe -c $TargetConfigPath
            }
        } `
        -VerifySwitch {
            Test-FanControlConfigSwitch `
                -TargetConfigPath $TargetConfigPath `
                -Paths $Paths `
                -CommandStartedAt $commandStartedAt `
                -LogAction $LogAction
        } `
        -OnRetry {
            Invoke-ConfigSwitchLog -LogAction $LogAction -Message "Cold start detected and initial verification failed, retrying config switch through running FanControl process"
        }

    $verified = Test-ConfigSwitchVerificationPassed -VerificationResult $verification
    $status = if ($verified) { 'SUCCESS' } else { 'FAILED' }
    $message = "$StatusPrefix to $configName - " + $(if ($verified) { 'Verified' } else { 'Not verified' })

    Write-FanControlStatus `
        -TargetConfig $configName `
        -Status $status `
        -Message $message `
        -Verified $verified `
        -CommandIssued:$true `
        -CommandStartedAt $commandStartedAt `
        -ObservedConfig $verification.ObservedConfig `
        -ObservedAt $verification.ObservedAt `
        -VerificationConfidence $verification.VerificationConfidence `
        -Paths $Paths

    return [PSCustomObject]@{
        TargetConfigPath = $TargetConfigPath
        TargetConfigName = $configName
        Verified = $verified
        Status = $status
        Message = $message
        ObservedConfig = $verification.ObservedConfig
        ObservedAt = $verification.ObservedAt
        VerificationConfidence = $verification.VerificationConfidence
    }
}

function Invoke-AutoCalibrationSwitch {
    param(
        [bool]$ProcessWasRunning,
        [switch]$UseTray,
        $Paths = (Get-FanControlPaths),
        [scriptblock]$LogAction
    )

    $state = Get-FanControlRuntimeState
    if (-not $state.DesiredConfig) {
        throw 'Unable to resolve desired config for auto calibration.'
    }

    $targetConfigPath = Resolve-FanControlConfigPath -ConfigName $state.DesiredConfig -Paths $Paths

    return Invoke-FanControlConfigSwitch `
        -TargetConfigPath $targetConfigPath `
        -ProcessWasRunning:$ProcessWasRunning `
        -UseTray:$UseTray `
        -StatusPrefix 'Auto calibration' `
        -Paths $Paths `
        -LogAction $LogAction
}
