param([switch]$Force)

$RuntimePathsHelper = Join-Path $PSScriptRoot "runtime_paths.ps1"
$HelperFile = Join-Path $PSScriptRoot "auto_switch_recovery.ps1"
$ConfigSwitchCoreHelper = Join-Path $PSScriptRoot "config_switch_core.ps1"
$TimePolicyHelper = Join-Path $PSScriptRoot "time_policy.ps1"
$VolumeHelperFile = Join-Path $PSScriptRoot "volume_helper.ps1"

if (Test-Path $RuntimePathsHelper) {
    . $RuntimePathsHelper
} else {
    throw "Helper file not found: $RuntimePathsHelper"
}

$Paths = Get-FanControlPaths
$StateDir = $Paths.StateDir
$LogDir = $Paths.LogDir
$OverrideFlag = $Paths.OverrideFlag
$LogFile = Join-Path $LogDir 'auto_switch.log'
$QuietConfig = $Paths.QuietConfig
$GameConfig = $Paths.GameConfig

New-Item -ItemType Directory -Force -Path $StateDir | Out-Null
New-Item -ItemType Directory -Force -Path $LogDir | Out-Null

if (Test-Path $HelperFile) {
    . $HelperFile
} else {
    throw "Helper file not found: $HelperFile"
}

if (Test-Path $TimePolicyHelper) {
    . $TimePolicyHelper
} else {
    throw "Helper file not found: $TimePolicyHelper"
}

if (Test-Path $VolumeHelperFile) {
    . $VolumeHelperFile
} else {
    throw "Helper file not found: $VolumeHelperFile"
}

if (Test-Path $ConfigSwitchCoreHelper) {
    . $ConfigSwitchCoreHelper
} else {
    throw "Helper file not found: $ConfigSwitchCoreHelper"
}

function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy/MM/dd HH:mm:ss"
    $logEntry = "[$timestamp] $Message"
    Add-Content -Path $LogFile -Value $logEntry -ErrorAction SilentlyContinue
}

function Get-TargetConfig {
    $currentDate = Get-Date
    $window = Get-TimePolicyWindow -Minute (Get-MinuteOfDay -Date $currentDate)
    $configName = $window.Config

    if ($configName -eq "Quiet_mode.json") {
        Write-Log "Current time $($currentDate.ToString('HH:mm')) matched policy $($window.Label) -> Quiet"
        return $QuietConfig
    }

    Write-Log "Current time $($currentDate.ToString('HH:mm')) matched policy $($window.Label) -> Game"
    return $GameConfig
}

function Show-Notification {
    param(
        [string]$Title,
        [string]$Message,
        [string]$Type = "Info"
    )

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

Write-Log "=========================================="
Write-Log "Script started (Enhanced v3.0)"
Write-Log "Parameter: Force=$Force"
Write-Log "=========================================="

try {
    Test-FanControlConfigFiles `
        -RequiredConfigs @($QuietConfig, $GameConfig) `
        -Paths $Paths `
        -LogAction { param($Message) Write-Log $Message }
    Write-Log "Config validation passed"
} catch {
    $errorMessage = $_.Exception.Message
    Write-Log "ERROR: Config validation failed"
    Write-FanControlStatus `
        -TargetConfig 'N/A' `
        -Status 'ERROR' `
        -Message $errorMessage `
        -Verified $false `
        -CommandIssued:$false `
        -VerificationConfidence 'Low' `
        -Paths $Paths

    [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") | Out-Null
    [System.Windows.Forms.MessageBox]::Show(
        "Config validation failed:`n$errorMessage",
        "FanControl Auto Switch Error",
        "OK",
        "Error"
    ) | Out-Null

    exit 1
}

$currentMinute = Get-MinuteOfDay
$isForcePoint = Test-IsForcePointMinute -Minute $currentMinute
$isQuietExitPoint = Test-IsQuietExitPointMinute -Minute $currentMinute
$processWasRunning = Get-FanControlProcessRunning

if ($isForcePoint -or $Force) {
    Write-Log "Force trigger detected, clearing override flag"
    Remove-Item $OverrideFlag -Force -ErrorAction SilentlyContinue
    Enter-QuietVolumeMode

    $result = Invoke-FanControlConfigSwitch `
        -TargetConfigPath $QuietConfig `
        -ProcessWasRunning:$processWasRunning `
        -UseTray `
        -StatusPrefix 'Force switch' `
        -Paths $Paths `
        -LogAction { param($Message) Write-Log $Message }

    $configName = $result.TargetConfigName

    if ($result.Verified) {
        Show-Notification -Title "FanControl Auto Switch" -Message "Successfully switched to $configName" -Type "Info"
    } else {
        Show-Notification -Title "FanControl Switch Warning" -Message "Switch to $configName may have failed" -Type "Warning"
    }

    Write-Log "Script ended (Force mode) - Status: $($result.Status)"
    exit
}

if (Test-Path $OverrideFlag) {
    $overrideMode = Get-Content $OverrideFlag -ErrorAction SilentlyContinue
    Write-Log "Override flag detected, skipping auto switch (current mode: $overrideMode)"

    Write-FanControlStatus `
        -TargetConfig "Override: $overrideMode" `
        -Status "SKIPPED" `
        -Message "Override mode active" `
        -Verified $false `
        -CommandIssued:$false `
        -Paths $Paths

    Write-Log "Script ended (Override mode)"
    exit
}

$targetConfig = Get-TargetConfig
$configName = Split-Path $targetConfig -Leaf

if ($isQuietExitPoint -and $configName -eq 'Game.json') {
    Write-Log "Quiet exit trigger detected, restoring saved volume if present"
    [void](Restore-QuietVolumeIfNeeded)
}

Write-Log "Attempting to switch config: $configName"

$result = Invoke-FanControlConfigSwitch `
    -TargetConfigPath $targetConfig `
    -ProcessWasRunning:$processWasRunning `
    -UseTray `
    -StatusPrefix 'Switch' `
    -Paths $Paths `
    -LogAction { param($Message) Write-Log $Message }

if ($result.Verified) {
    Show-Notification -Title "FanControl Auto Switch" -Message "Successfully switched to $configName" -Type "Info"
} else {
    Show-Notification -Title "FanControl Switch Warning" -Message "Switch to $configName may have failed" -Type "Warning"
}

Write-Log "Script ended - Status: $($result.Status)"
Write-Log "=========================================="
