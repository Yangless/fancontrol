Describe 'FanControl runtime paths' {
    BeforeAll {
        $repoRoot = Split-Path -Parent $PSScriptRoot
        $helperPath = Join-Path $repoRoot 'scripts\current\runtime_paths.ps1'

        if (Test-Path $helperPath) {
            . $helperPath
        }
    }

    It 'has a shared runtime path helper' {
        (Test-Path $helperPath) | Should -BeTrue
        (Get-Command Get-FanControlPaths -ErrorAction SilentlyContinue) | Should -Not -BeNullOrEmpty
    }

    It 'returns the default runtime paths' {
        $previousRuntimeRoot = $env:FANCONTROL_RUNTIME_ROOT
        $previousConfigDir = $env:FANCONTROL_CONFIG_DIR
        $previousExe = $env:FANCONTROL_EXE

        try {
            Remove-Item Env:FANCONTROL_RUNTIME_ROOT -ErrorAction SilentlyContinue
            Remove-Item Env:FANCONTROL_CONFIG_DIR -ErrorAction SilentlyContinue
            Remove-Item Env:FANCONTROL_EXE -ErrorAction SilentlyContinue

            $paths = Get-FanControlPaths
            $paths.RuntimeRoot | Should -Be 'C:\FanControl_Auto'
            $paths.ConfigDir | Should -Be 'D:\Program Files (x86)\FanControl\Configurations'
            $paths.FanControlExe | Should -Be 'D:\Program Files (x86)\FanControl\FanControl.exe'
            $paths.StateDir | Should -Be 'C:\FanControl_Auto\state'
            $paths.LogDir | Should -Be 'C:\FanControl_Auto\logs'
            $paths.MonitorDir | Should -Be 'C:\FanControl_Auto\monitor_data'
            $paths.StatusFile | Should -Be 'C:\FanControl_Auto\state\current_status.json'
            $paths.OverrideFlag | Should -Be 'C:\FanControl_Auto\state\override.flag'
            $paths.CacheFile | Should -Be 'D:\Program Files (x86)\FanControl\Configurations\CACHE'
        } finally {
            [Environment]::SetEnvironmentVariable('FANCONTROL_RUNTIME_ROOT', $previousRuntimeRoot, 'Process')
            [Environment]::SetEnvironmentVariable('FANCONTROL_CONFIG_DIR', $previousConfigDir, 'Process')
            [Environment]::SetEnvironmentVariable('FANCONTROL_EXE', $previousExe, 'Process')
        }
    }

    It 'supports environment overrides' {
        $previousRuntimeRoot = $env:FANCONTROL_RUNTIME_ROOT
        $previousConfigDir = $env:FANCONTROL_CONFIG_DIR
        $previousExe = $env:FANCONTROL_EXE

        try {
            $env:FANCONTROL_RUNTIME_ROOT = 'D:\Temp\FanControlSandbox'
            $env:FANCONTROL_CONFIG_DIR = 'D:\Temp\FanControlSandbox\Config'
            $env:FANCONTROL_EXE = 'D:\Temp\FanControlSandbox\FanControl.exe'

            $paths = Get-FanControlPaths
            $paths.RuntimeRoot | Should -Be 'D:\Temp\FanControlSandbox'
            $paths.ConfigDir | Should -Be 'D:\Temp\FanControlSandbox\Config'
            $paths.FanControlExe | Should -Be 'D:\Temp\FanControlSandbox\FanControl.exe'
            $paths.StateDir | Should -Be 'D:\Temp\FanControlSandbox\state'
            $paths.LogDir | Should -Be 'D:\Temp\FanControlSandbox\logs'
            $paths.MonitorDir | Should -Be 'D:\Temp\FanControlSandbox\monitor_data'
            $paths.StatusFile | Should -Be 'D:\Temp\FanControlSandbox\state\current_status.json'
            $paths.OverrideFlag | Should -Be 'D:\Temp\FanControlSandbox\state\override.flag'
            $paths.QuietConfig | Should -Be 'D:\Temp\FanControlSandbox\Config\Quiet_mode.json'
            $paths.GameConfig | Should -Be 'D:\Temp\FanControlSandbox\Config\Game.json'
            $paths.CacheFile | Should -Be 'D:\Temp\FanControlSandbox\Config\CACHE'
            $paths.RuntimeAutoSwitch | Should -Be 'D:\Temp\FanControlSandbox\auto_switch.ps1'
        } finally {
            [Environment]::SetEnvironmentVariable('FANCONTROL_RUNTIME_ROOT', $previousRuntimeRoot, 'Process')
            [Environment]::SetEnvironmentVariable('FANCONTROL_CONFIG_DIR', $previousConfigDir, 'Process')
            [Environment]::SetEnvironmentVariable('FANCONTROL_EXE', $previousExe, 'Process')
        }
    }

    It 'is imported by the active runtime scripts' {
        $repoRoot = Split-Path -Parent $PSScriptRoot
        $activeScripts = @(
            'auto_switch.ps1',
            'switch.ps1',
            'check_status.ps1',
            'monitor_simple.ps1'
        )

        foreach ($scriptName in $activeScripts) {
            $scriptPath = Join-Path $repoRoot "scripts\current\$scriptName"
            $content = Get-Content -Path $scriptPath -Raw
            $content | Should -Match 'runtime_paths\.ps1'
        }
    }
}
