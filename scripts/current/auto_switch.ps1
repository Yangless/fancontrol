param([switch]$Force)

$FanControlExe = "D:\Program Files (x86)\FanControl\FanControl.exe"
$ConfigDir = "D:\Program Files (x86)\FanControl\Configurations"
$StateDir = "C:\FanControl_Auto\state"
$LogDir = "C:\FanControl_Auto\logs"
$OverrideFlag = "$StateDir\override.flag"
$StatusFile = "$StateDir\current_status.json"
$LogFile = "$LogDir\auto_switch.log"

$QuietConfig = "$ConfigDir\Quiet_mode.json"
$GameConfig = "$ConfigDir\Game.json"
$CacheFile = "$ConfigDir\CACHE"
$HelperFile = Join-Path $PSScriptRoot "auto_switch_recovery.ps1"
$TimePolicyHelper = Join-Path $PSScriptRoot "time_policy.ps1"

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

function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy/MM/dd HH:mm:ss"
    $logEntry = "[$timestamp] $Message"
    Add-Content -Path $LogFile -Value $logEntry -ErrorAction SilentlyContinue
}

function Update-StatusFile {
    param(
        [string]$TargetConfig,
        [string]$Status,
        [string]$Message,
        [bool]$Verified = $false
    )

    $statusData = @{
        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        TargetConfig = $TargetConfig
        ActualConfig = $null
        Status = $Status
        Message = $Message
        Verified = $Verified
        ProcessRunning = $false
        ProcessId = $null
    }

    $process = Get-Process -Name FanControl -ErrorAction SilentlyContinue
    if ($process) {
        $statusData.ProcessRunning = $true
        $statusData.ProcessId = $process.Id
    }

    if (Test-Path $CacheFile) {
        try {
            $cache = Get-Content $CacheFile | ConvertFrom-Json
            $statusData.ActualConfig = $cache.CurrentConfigFileName
        } catch {
            $statusData.ActualConfig = "Unknown"
        }
    }

    $statusData | ConvertTo-Json -Depth 3 | Set-Content $StatusFile -ErrorAction SilentlyContinue
}

function Test-ConfigFiles {
    $errors = @()

    if (-not (Test-Path $FanControlExe)) {
        $errors += "FanControl.exe not found: $FanControlExe"
    }

    if (-not (Test-Path $QuietConfig)) {
        $errors += "Quiet config not found: $QuietConfig"
    }

    if (-not (Test-Path $GameConfig)) {
        $errors += "Game config not found: $GameConfig"
    }

    if ($errors.Count -gt 0) {
        Write-Log "ERROR: Config validation failed"
        $errors | ForEach-Object { Write-Log "  - $_" }

        Update-StatusFile -TargetConfig "N/A" -Status "ERROR" -Message ($errors -join "; ") -Verified $false

        [System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") | Out-Null
        [System.Windows.Forms.MessageBox]::Show(
            "Config validation failed:`n" + ($errors -join "`n"),
            "FanControl Auto Switch Error",
            "OK",
            "Error"
        ) | Out-Null

        exit 1
    }

    Write-Log "Config validation passed"
}

function Test-ConfigSwitch {
    param(
        [string]$TargetConfig,
        [int]$MaxWaitSeconds = 10
    )

    $configName = Split-Path $TargetConfig -Leaf
    Write-Log "Verifying config switch to: $configName"

    $waited = 0
    $verified = $false

    while ($waited -lt $MaxWaitSeconds) {
        Start-Sleep -Seconds 1
        $waited++

        if (Test-Path $CacheFile) {
            try {
                $cache = Get-Content $CacheFile | ConvertFrom-Json
                $actualConfig = $cache.CurrentConfigFileName

                if ($actualConfig -eq $configName) {
                    $verified = $true
                    Write-Log "SUCCESS: Config verified after ${waited}s - Actual: $actualConfig"
                    break
                } else {
                    Write-Log "Waiting... (${waited}s) - Target: $configName, Actual: $actualConfig"
                }
            } catch {
                Write-Log "Warning: Cannot read CACHE file (${waited}s)"
            }
        }
    }

    return $verified
}

function Get-TargetConfig {
    $currentDate = Get-Date
    $min = Get-MinuteOfDay -Date $currentDate
    $configName = Get-ConfigNameForMinute -Minute $min

    if ($configName -eq "Quiet_mode.json") {
        Write-Log "Current time $((Get-Date).ToString('HH:mm')) is in Quiet period"
        return $QuietConfig
    }

    Write-Log "Current time $((Get-Date).ToString('HH:mm')) is in Game period"
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

Test-ConfigFiles

$currentMinute = Get-MinuteOfDay
$isForcePoint = Test-IsForcePointMinute -Minute $currentMinute
$processWasRunning = (Get-Process -Name FanControl -ErrorAction SilentlyContinue) -ne $null

if ($isForcePoint -or $Force) {
    Write-Log "Force trigger detected, clearing override flag"
    Remove-Item $OverrideFlag -Force -ErrorAction SilentlyContinue

    $configName = Split-Path $QuietConfig -Leaf
    Write-Log "Force switch to Quiet mode: $configName"

    $verified = Invoke-ConfigSwitchWithRetry `
        -ProcessWasRunning:$processWasRunning `
        -RunSwitchCommand {
            & $FanControlExe -c $QuietConfig -tray
        } `
        -VerifySwitch {
            Test-ConfigSwitch -TargetConfig $QuietConfig
        } `
        -OnRetry {
            Write-Log "Cold start detected and initial verification failed, retrying Quiet config through running FanControl process"
        }

    $status = if ($verified) { "SUCCESS" } else { "FAILED" }
    $message = "Force switch to $configName - " + $(if ($verified) { "Verified" } else { "Not verified" })
    Update-StatusFile -TargetConfig $configName -Status $status -Message $message -Verified $verified

    if ($verified) {
        Show-Notification -Title "FanControl Auto Switch" -Message "Successfully switched to $configName" -Type "Info"
    } else {
        Show-Notification -Title "FanControl Switch Warning" -Message "Switch to $configName may have failed" -Type "Warning"
    }

    Write-Log "Script ended (Force mode) - Status: $status"
    exit
}

if (Test-Path $OverrideFlag) {
    $overrideMode = Get-Content $OverrideFlag -ErrorAction SilentlyContinue
    Write-Log "Override flag detected, skipping auto switch (current mode: $overrideMode)"

    Update-StatusFile -TargetConfig "Override: $overrideMode" -Status "SKIPPED" -Message "Override mode active" -Verified $false

    Write-Log "Script ended (Override mode)"
    exit
}

$targetConfig = Get-TargetConfig
$configName = Split-Path $targetConfig -Leaf

Write-Log "Attempting to switch config: $configName"

$verified = Invoke-ConfigSwitchWithRetry `
    -ProcessWasRunning:$processWasRunning `
    -RunSwitchCommand {
        & $FanControlExe -c $targetConfig -tray
    } `
    -VerifySwitch {
        Test-ConfigSwitch -TargetConfig $targetConfig
    } `
    -OnRetry {
        Write-Log "Cold start detected and initial verification failed, retrying config switch through running FanControl process"
    }

$status = if ($verified) { "SUCCESS" } else { "FAILED" }
$message = "Switch to $configName - " + $(if ($verified) { "Verified" } else { "Not verified" })
Update-StatusFile -TargetConfig $configName -Status $status -Message $message -Verified $verified

if ($verified) {
    Show-Notification -Title "FanControl Auto Switch" -Message "Successfully switched to $configName" -Type "Info"
} else {
    Show-Notification -Title "FanControl Switch Warning" -Message "Switch to $configName may have failed" -Type "Warning"
}

Write-Log "Script ended - Status: $status"
Write-Log "=========================================="
