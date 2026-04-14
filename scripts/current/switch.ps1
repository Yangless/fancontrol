param(
    [string]$Mode = "",
    [switch]$Help
)

$FanControlExe = "D:\Program Files (x86)\FanControl\FanControl.exe"
$ConfigDir = "D:\Program Files (x86)\FanControl\Configurations"
$StateDir = "C:\FanControl_Auto\state"
$LogDir = "C:\FanControl_Auto\logs"
$OverrideFlag = "$StateDir\override.flag"
$LogFile = "$LogDir\switch.log"

$QuietConfig = "$ConfigDir\Quiet_mode.json"
$GameConfig = "$ConfigDir\Game.json"

New-Item -ItemType Directory -Force -Path $StateDir | Out-Null
New-Item -ItemType Directory -Force -Path $LogDir | Out-Null

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

if ($Mode -eq "auto") {
    Write-Log "Clearing override flag, restoring auto scheduling"

    if (Test-Path $OverrideFlag) {
        $previousMode = Get-Content $OverrideFlag
        Remove-Item $OverrideFlag -Force -ErrorAction SilentlyContinue
        Write-Log "Override flag cleared (was: $previousMode)"
    } else {
        Write-Log "No override flag detected"
    }

    Write-Log "Calling auto switch script for time-based calibration"
    & "C:\FanControl_Auto\auto_switch.ps1"

    Write-Log "========== Manual switch ended =========="
    exit
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

& $FanControlExe -c $targetConfig

$Mode | Set-Content $OverrideFlag
Write-Log "Override flag set: $Mode"

Write-Host "Switched to $Mode mode ($configName) with override enabled" -ForegroundColor Green
Write-Host "Tip: Use '.\switch.ps1 -Mode auto' to restore auto scheduling" -ForegroundColor Yellow

Write-Log "========== Manual switch ended =========="
