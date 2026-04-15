function Get-FanControlPaths {
    $runtimeRoot = if ($env:FANCONTROL_RUNTIME_ROOT) {
        $env:FANCONTROL_RUNTIME_ROOT
    } else {
        'C:\FanControl_Auto'
    }

    $configDir = if ($env:FANCONTROL_CONFIG_DIR) {
        $env:FANCONTROL_CONFIG_DIR
    } else {
        'D:\Program Files (x86)\FanControl\Configurations'
    }

    $fanControlExe = if ($env:FANCONTROL_EXE) {
        $env:FANCONTROL_EXE
    } else {
        'D:\Program Files (x86)\FanControl\FanControl.exe'
    }

    $stateDir = Join-Path $runtimeRoot 'state'
    $logDir = Join-Path $runtimeRoot 'logs'

    return [PSCustomObject]@{
        RuntimeRoot = $runtimeRoot
        ConfigDir = $configDir
        FanControlExe = $fanControlExe
        StateDir = $stateDir
        LogDir = $logDir
        MonitorDir = Join-Path $runtimeRoot 'monitor_data'
        StatusFile = Join-Path $stateDir 'current_status.json'
        OverrideFlag = Join-Path $stateDir 'override.flag'
        QuietConfig = Join-Path $configDir 'Quiet_mode.json'
        GameConfig = Join-Path $configDir 'Game.json'
        CacheFile = Join-Path $configDir 'CACHE'
        RuntimeAutoSwitch = Join-Path $runtimeRoot 'auto_switch.ps1'
    }
}
