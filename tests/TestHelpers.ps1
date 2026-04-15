function New-FanControlTestSandbox {
    $root = Join-Path $env:TEMP ("fancontrol-test-" + [guid]::NewGuid().ToString("N"))
    $runtimeDir = Join-Path $root 'runtime'
    $configDir = Join-Path $root 'config'
    $stateDir = Join-Path $runtimeDir 'state'
    $logDir = Join-Path $runtimeDir 'logs'
    $monitorDir = Join-Path $runtimeDir 'monitor_data'
    $stubPath = Join-Path $root 'FanControlStub.ps1'
    $behaviorFile = Join-Path $root 'stub_behavior.json'
    $callLog = Join-Path $root 'stub_calls.log'
    $autoSwitchCallLog = Join-Path $root 'auto_switch_calls.log'
    $volumeFile = Join-Path $root 'test_volume.txt'
    $volumeCallLog = Join-Path $root 'volume_calls.log'

    New-Item -ItemType Directory -Force -Path $runtimeDir, $configDir, $stateDir, $logDir, $monitorDir | Out-Null

    Set-Content (Join-Path $configDir 'Game.json') '{}' -Encoding UTF8
    Set-Content (Join-Path $configDir 'Quiet_mode.json') '{}' -Encoding UTF8
    Set-Content -Path $volumeFile -Value '50' -Encoding ASCII

    $stubContent = @'
param(
    [string]$c,
    [switch]$tray
)

$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$behaviorFile = Join-Path $root 'stub_behavior.json'
$callLog = Join-Path $root 'stub_calls.log'
$behavior = Get-Content $behaviorFile | ConvertFrom-Json
$behavior.CallCount = [int]$behavior.CallCount + 1
$configName = if ($c) { Split-Path $c -Leaf } else { 'NONE' }
Add-Content -Path $callLog -Value "$($behavior.CallCount)|$configName|Tray=$([bool]$tray)"

function Write-CacheFile {
    param(
        [string]$Path,
        [string]$ConfigName,
        [string]$ConfigDir
    )

    @{
        CurrentConfigFileName = $ConfigName
        CustomConfigFolder = $ConfigDir
    } | ConvertTo-Json | Set-Content -Path $Path -Encoding UTF8
}

switch ($behavior.Mode) {
    'ImmediateSuccess' {
        Write-CacheFile -Path $behavior.CacheFile -ConfigName $configName -ConfigDir $behavior.ConfigDir
    }
    'SucceedOnSecondCall' {
        if ($behavior.CallCount -ge 2) {
            Write-CacheFile -Path $behavior.CacheFile -ConfigName $configName -ConfigDir $behavior.ConfigDir
        }
    }
    'InvalidCacheThenSuccess' {
        if ($behavior.CallCount -eq 1) {
            Set-Content -Path $behavior.CacheFile -Value '{invalid json' -Encoding UTF8
        } else {
            Write-CacheFile -Path $behavior.CacheFile -ConfigName $configName -ConfigDir $behavior.ConfigDir
        }
    }
    'NoCacheUpdate' {
    }
    default {
        throw "Unknown stub mode: $($behavior.Mode)"
    }
}

$behavior | ConvertTo-Json | Set-Content -Path $behaviorFile -Encoding UTF8
'@
    Set-Content -Path $stubPath -Value $stubContent -Encoding UTF8

    $sandbox = [PSCustomObject]@{
        Root = $root
        RuntimeDir = $runtimeDir
        ConfigDir = $configDir
        StateDir = $stateDir
        LogDir = $logDir
        MonitorDir = $monitorDir
        CacheFile = Join-Path $configDir 'CACHE'
        StubPath = $stubPath
        BehaviorFile = $behaviorFile
        CallLog = $callLog
        AutoSwitchCallLog = $autoSwitchCallLog
        VolumeFile = $volumeFile
        VolumeCallLog = $volumeCallLog
        SavedVolumeFile = Join-Path $stateDir 'quiet_saved_volume.json'
    }

    Set-FanControlStubBehavior -Sandbox $sandbox -Mode 'ImmediateSuccess' -InitialConfig 'Quiet_mode.json'
    Set-SandboxVolumeState -Sandbox $sandbox -CurrentVolume 50
    Copy-FanControlRuntimeScriptsToSandbox -Sandbox $sandbox

    return $sandbox
}

function Set-FanControlStubBehavior {
    param(
        [Parameter(Mandatory = $true)]$Sandbox,
        [Parameter(Mandatory = $true)][string]$Mode,
        [string]$InitialConfig = 'Quiet_mode.json'
    )

    @{
        Mode = $Mode
        CallCount = 0
        CacheFile = $Sandbox.CacheFile
        ConfigDir = $Sandbox.ConfigDir
    } | ConvertTo-Json | Set-Content -Path $Sandbox.BehaviorFile -Encoding UTF8

    @{
        CurrentConfigFileName = $InitialConfig
        CustomConfigFolder = $Sandbox.ConfigDir
    } | ConvertTo-Json | Set-Content -Path $Sandbox.CacheFile -Encoding UTF8

    if (Test-Path $Sandbox.CallLog) {
        Clear-Content -Path $Sandbox.CallLog
    }

    if (Test-Path $Sandbox.AutoSwitchCallLog) {
        Clear-Content -Path $Sandbox.AutoSwitchCallLog
    }
}

function Set-SandboxVolumeState {
    param(
        [Parameter(Mandatory = $true)]$Sandbox,
        [Parameter(Mandatory = $true)][int]$CurrentVolume,
        [Nullable[int]]$SavedVolume = $null
    )

    Set-Content -Path $Sandbox.VolumeFile -Value ([string]$CurrentVolume) -Encoding ASCII

    if ($null -eq $SavedVolume) {
        Remove-Item -Path $Sandbox.SavedVolumeFile -Force -ErrorAction SilentlyContinue
    } else {
        @{
            Volume = [int]$SavedVolume
        } | ConvertTo-Json | Set-Content -Path $Sandbox.SavedVolumeFile -Encoding UTF8
    }

    if (Test-Path $Sandbox.VolumeCallLog) {
        Clear-Content -Path $Sandbox.VolumeCallLog
    }
}

function Copy-FanControlRuntimeScriptsToSandbox {
    param(
        [Parameter(Mandatory = $true)]$Sandbox
    )

    $repoRoot = Split-Path -Parent $PSScriptRoot
    $sourceFiles = @(
        'auto_switch.ps1',
        'auto_switch_recovery.ps1',
        'config_switch_core.ps1',
        'runtime_paths.ps1',
        'runtime_state.ps1',
        'time_policy.ps1',
        'switch.ps1',
        'check_status.ps1',
        'monitor_simple.ps1'
    )
    $optionalSourceFiles = @('volume_helper.ps1')

    foreach ($name in $sourceFiles + ($optionalSourceFiles | Where-Object {
        Test-Path (Join-Path $repoRoot "scripts\\current\\$_")
    })) {
        $sourcePath = Join-Path $repoRoot "scripts\\current\\$name"
        $targetPath = Join-Path $Sandbox.RuntimeDir $name
        $content = Get-Content -Path $sourcePath -Raw

        if ($name -eq 'time_policy.ps1') {
            $content = $content.Replace(
                '    return ($Date.Hour * 60 + $Date.Minute)',
                "    if (`$env:FANCONTROL_TEST_MINUTE) { return [int]`$env:FANCONTROL_TEST_MINUTE }`r`n`r`n    return (`$Date.Hour * 60 + `$Date.Minute)"
            )
        }

        if ($name -eq 'auto_switch.ps1') {
            $content = $content.Replace(
                '$processWasRunning = (Get-Process -Name FanControl -ErrorAction SilentlyContinue) -ne $null',
                '$processWasRunning = if ($env:FANCONTROL_TEST_PROCESS_RUNNING) { [System.Convert]::ToBoolean($env:FANCONTROL_TEST_PROCESS_RUNNING) } else { (Get-Process -Name FanControl -ErrorAction SilentlyContinue) -ne $null }'
            )
            $content = $content.Replace('[int]$MaxWaitSeconds = 10', '[int]$MaxWaitSeconds = 2')
            $content = [regex]::Replace(
                $content,
                '(?ms)^function Show-Notification \{.*?^}',
                "function Show-Notification {`r`n    param(`r`n        [string]`$Title,`r`n        [string]`$Message,`r`n        [string]`$Type = 'Info'`r`n    )`r`n`r`n    Write-Host `"NOTIFY: `$Title | `$Message | `$Type`"`r`n}"
            )
        }

        Set-Content -Path $targetPath -Value $content -Encoding UTF8
    }
}

function Set-SandboxAutoSwitchStub {
    param(
        [Parameter(Mandatory = $true)]$Sandbox
    )

    $stub = @"
param([switch]`$Force)
Add-Content -Path '$($Sandbox.AutoSwitchCallLog)' -Value `"Force=`$Force`"
"@

    Set-Content -Path (Join-Path $Sandbox.RuntimeDir 'auto_switch.ps1') -Value $stub -Encoding UTF8
}

function Invoke-PowerShellScript {
    param(
        [Parameter(Mandatory = $true)][string]$ScriptPath,
        [string[]]$Arguments = @(),
        [hashtable]$Environment = @{}
    )

    $argList = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $ScriptPath) + $Arguments
    $previousValues = @{}

    foreach ($key in $Environment.Keys) {
        $previousValues[$key] = [Environment]::GetEnvironmentVariable($key, 'Process')
        [Environment]::SetEnvironmentVariable($key, [string]$Environment[$key], 'Process')
    }

    try {
        $output = & powershell.exe @argList 2>&1
        $exitCode = $LASTEXITCODE
    } finally {
        foreach ($key in $Environment.Keys) {
            [Environment]::SetEnvironmentVariable($key, $previousValues[$key], 'Process')
        }
    }

    return [PSCustomObject]@{
        Output = @($output)
        ExitCode = $exitCode
    }
}

function Get-SandboxEnvironment {
    param(
        [Parameter(Mandatory = $true)]$Sandbox,
        [hashtable]$Values = @{}
    )

    $environment = @{
        FANCONTROL_RUNTIME_ROOT = $Sandbox.RuntimeDir
        FANCONTROL_CONFIG_DIR = $Sandbox.ConfigDir
        FANCONTROL_EXE = $Sandbox.StubPath
        FANCONTROL_TEST_MAX_WAIT_SECONDS = '2'
        FANCONTROL_TEST_VOLUME_FILE = $Sandbox.VolumeFile
        FANCONTROL_TEST_VOLUME_LOG = $Sandbox.VolumeCallLog
    }

    foreach ($key in $Values.Keys) {
        $environment[$key] = $Values[$key]
    }

    return $environment
}

function Get-StubCallConfigs {
    param(
        [Parameter(Mandatory = $true)]$Sandbox
    )

    if (-not (Test-Path $Sandbox.CallLog)) {
        return @()
    }

    return ,@(Get-Content $Sandbox.CallLog | ForEach-Object {
        ($_ -split '\|')[1]
    })
}

function Get-AutoSwitchStubCalls {
    param(
        [Parameter(Mandatory = $true)]$Sandbox
    )

    if (-not (Test-Path $Sandbox.AutoSwitchCallLog)) {
        return @()
    }

    return ,@(Get-Content $Sandbox.AutoSwitchCallLog)
}

function Get-SandboxCurrentVolume {
    param(
        [Parameter(Mandatory = $true)]$Sandbox
    )

    return [int](Get-Content -Path $Sandbox.VolumeFile -Raw)
}

function Get-SandboxSavedVolume {
    param(
        [Parameter(Mandatory = $true)]$Sandbox
    )

    if (-not (Test-Path $Sandbox.SavedVolumeFile)) {
        return $null
    }

    return [int]((Get-Content -Path $Sandbox.SavedVolumeFile -Raw | ConvertFrom-Json).Volume)
}

function Get-SandboxVolumeCalls {
    param(
        [Parameter(Mandatory = $true)]$Sandbox
    )

    if (-not (Test-Path $Sandbox.VolumeCallLog)) {
        return @()
    }

    return ,@(Get-Content -Path $Sandbox.VolumeCallLog)
}

function Get-SandboxStatus {
    param(
        [Parameter(Mandatory = $true)]$Sandbox
    )

    $statusFile = Join-Path $Sandbox.StateDir 'current_status.json'
    if (-not (Test-Path $statusFile)) {
        return $null
    }

    return Get-Content $statusFile | ConvertFrom-Json
}

function Remove-FanControlTestSandbox {
    param(
        [Parameter(Mandatory = $true)]$Sandbox
    )

    if (Test-Path $Sandbox.Root) {
        Remove-Item -LiteralPath $Sandbox.Root -Recurse -Force
    }
}
