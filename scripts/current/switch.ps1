param(
    [string]$Mode = "",
    [switch]$Help
)

$RuntimePathsHelper = Join-Path $PSScriptRoot "runtime_paths.ps1"
$ConfigSwitchCoreHelper = Join-Path $PSScriptRoot "config_switch_core.ps1"
$VolumeHelperFile = Join-Path $PSScriptRoot "volume_helper.ps1"

if (Test-Path $RuntimePathsHelper) {
    . $RuntimePathsHelper
} else {
    throw "Helper file not found: $RuntimePathsHelper"
}

$Paths = Get-FanControlPaths
$FanControlExe = $Paths.FanControlExe
$ConfigDir = $Paths.ConfigDir
$StateDir = $Paths.StateDir
$LogDir = $Paths.LogDir
$OverrideFlag = $Paths.OverrideFlag
$LogFile = Join-Path $LogDir 'switch.log'
$QuietConfig = $Paths.QuietConfig
$GameConfig = $Paths.GameConfig

New-Item -ItemType Directory -Force -Path $StateDir | Out-Null
New-Item -ItemType Directory -Force -Path $LogDir | Out-Null

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

if ($Help -or $Mode -eq "") {
    Write-Host "===================================="
    Write-Host "  FanControl Manual Switch Tool"
    Write-Host "===================================="
    Write-Host ""
    Write-Host "Usage:"
    Write-Host "  .\switch.ps1 -Mode <mode>"
    Write-Host ""
    Write-Host "Available modes:"
    Write-Host "  game  - Switch to Game mode (enable override)"
    Write-Host "  quiet - Switch to Quiet mode (enable override)"
    Write-Host "  auto  - Restore auto scheduling (clear override)"
    Write-Host ""
    Write-Host "Current status:"
    $status = if (Test-Path $OverrideFlag) { "Enabled ($((Get-Content $OverrideFlag)))" } else { "Disabled" }
    Write-Host "  Override: $status"
    Write-Host ""
    exit
}

$Mode = $Mode.ToLower().Trim()
Write-Log "========== Manual switch started =========="
Write-Log "Requested mode: $Mode"

$processWasRunning = Get-FanControlProcessRunning

if ($Mode -eq "auto") {
    Write-Log "Clearing override flag, restoring auto scheduling"

    if (Test-Path $OverrideFlag) {
        $previousMode = Get-Content $OverrideFlag
        Remove-Item $OverrideFlag -Force -ErrorAction SilentlyContinue
        Write-Log "Override flag cleared (was: $previousMode)"
    } else {
        Write-Log "No override flag detected"
    }

    Write-Log "Running shared auto calibration"
    $result = Invoke-AutoCalibrationSwitch `
        -ProcessWasRunning:$processWasRunning `
        -Paths $Paths `
        -LogAction { param($Message) Write-Log $Message }

    Write-Log "========== Manual switch ended =========="
    if (-not $result.Verified) {
        exit 1
    }

    exit 0
}

if ($Mode -notin @("game", "quiet")) {
    Write-Log "ERROR: Invalid mode '$Mode'"
    Write-Host "ERROR: Invalid mode. Use 'game', 'quiet', or 'auto'" -ForegroundColor Red
    exit 1
}

$targetConfig = if ($Mode -eq "game") { $GameConfig } else { $QuietConfig }
$configName = Split-Path $targetConfig -Leaf

if (-not (Test-Path $targetConfig)) {
    Write-Log "ERROR: Config file not found - $targetConfig"
    Write-Host "ERROR: Config file not found - $configName" -ForegroundColor Red
    exit 1
}

Write-Log "Switching to $Mode mode: $configName"

if ($Mode -eq 'quiet') {
    Enter-QuietVolumeMode
}

$result = Invoke-FanControlConfigSwitch `
    -TargetConfigPath $targetConfig `
    -ProcessWasRunning:$processWasRunning `
    -Paths $Paths `
    -LogAction { param($Message) Write-Log $Message } `
    -StatusPrefix 'Manual switch'

if (-not $result.Verified) {
    Write-Host "ERROR: Failed to verify switch to $Mode mode ($configName)" -ForegroundColor Red
    Write-Log "ERROR: Verification failed for $Mode mode"
    Write-Log "========== Manual switch ended =========="
    exit 1
}

$Mode | Set-Content -Path $OverrideFlag -Encoding UTF8
Write-Log "Override flag set: $Mode"

Write-Host "Switched to $Mode mode ($configName) with override enabled" -ForegroundColor Green
Write-Host "Tip: Use '.\switch.ps1 -Mode auto' to restore auto scheduling" -ForegroundColor Yellow

Write-Log "========== Manual switch ended =========="
exit 0
