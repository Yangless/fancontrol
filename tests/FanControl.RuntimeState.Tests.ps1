Describe 'FanControl runtime state' {
    BeforeAll {
        . (Join-Path $PSScriptRoot 'TestHelpers.ps1')

        $repoRoot = Split-Path -Parent $PSScriptRoot
        $script:RuntimePathsHelperPath = Join-Path $repoRoot 'scripts\current\runtime_paths.ps1'
        $script:TimePolicyHelperPath = Join-Path $repoRoot 'scripts\current\time_policy.ps1'
        $script:RuntimeStateHelperPath = Join-Path $repoRoot 'scripts\current\runtime_state.ps1'
    }

    function script:Invoke-RuntimeStateInSandbox {
        param(
            [Parameter(Mandatory = $true)]$Sandbox,
            [Parameter(Mandatory = $true)][datetime]$Now,
            [bool]$ProcessRunning = $false
        )

        $previousRuntimeRoot = $env:FANCONTROL_RUNTIME_ROOT
        $previousConfigDir = $env:FANCONTROL_CONFIG_DIR
        $previousExe = $env:FANCONTROL_EXE
        $previousProcess = $env:FANCONTROL_TEST_PROCESS_RUNNING

        try {
            $env:FANCONTROL_RUNTIME_ROOT = $Sandbox.RuntimeDir
            $env:FANCONTROL_CONFIG_DIR = $Sandbox.ConfigDir
            $env:FANCONTROL_EXE = $Sandbox.StubPath
            $env:FANCONTROL_TEST_PROCESS_RUNNING = [string]$ProcessRunning

            if (Test-Path $RuntimePathsHelperPath) {
                . $RuntimePathsHelperPath
            }

            if (Test-Path $TimePolicyHelperPath) {
                . $TimePolicyHelperPath
            }

            if (Test-Path $RuntimeStateHelperPath) {
                . $RuntimeStateHelperPath
            }

            return Get-FanControlRuntimeState -Now $Now
        } finally {
            [Environment]::SetEnvironmentVariable('FANCONTROL_RUNTIME_ROOT', $previousRuntimeRoot, 'Process')
            [Environment]::SetEnvironmentVariable('FANCONTROL_CONFIG_DIR', $previousConfigDir, 'Process')
            [Environment]::SetEnvironmentVariable('FANCONTROL_EXE', $previousExe, 'Process')
            [Environment]::SetEnvironmentVariable('FANCONTROL_TEST_PROCESS_RUNNING', $previousProcess, 'Process')
        }
    }

    It 'has a shared runtime state helper' {
        (Test-Path $RuntimeStateHelperPath) | Should -BeTrue
    }

    It 'prefers the override target when CACHE still shows the previous config' {
        $sandbox = New-FanControlTestSandbox
        try {
            Set-Content (Join-Path $sandbox.StateDir 'override.flag') 'quiet' -Encoding UTF8
            @{
                CurrentConfigFileName = 'Game.json'
                CustomConfigFolder = $sandbox.ConfigDir
            } | ConvertTo-Json | Set-Content -Path $sandbox.CacheFile -Encoding UTF8

            $state = Invoke-RuntimeStateInSandbox `
                -Sandbox $sandbox `
                -Now ([datetime]'2026-04-14T09:00:00') `
                -ProcessRunning:$true

            $state.DesiredConfig | Should -Be 'Quiet_mode.json'
            $state.EffectiveConfig | Should -Be 'Game.json'
            $state.OverrideActive | Should -BeTrue
            $state.StateConfidence | Should -Be 'Low'
        } finally {
            Remove-FanControlTestSandbox -Sandbox $sandbox
        }
    }

    It 'downgrades confidence when the status file says SUCCESS but the process is not running' {
        $sandbox = New-FanControlTestSandbox
        try {
            @{
                CurrentConfigFileName = 'Game.json'
                CustomConfigFolder = $sandbox.ConfigDir
            } | ConvertTo-Json | Set-Content -Path $sandbox.CacheFile -Encoding UTF8

            @{
                Timestamp = '2026-04-14 09:00:00'
                Status = 'SUCCESS'
                TargetConfig = 'Game.json'
                ActualConfig = 'Game.json'
            } | ConvertTo-Json | Set-Content -Path (Join-Path $sandbox.StateDir 'current_status.json') -Encoding UTF8

            $state = Invoke-RuntimeStateInSandbox `
                -Sandbox $sandbox `
                -Now ([datetime]'2026-04-14T09:01:00') `
                -ProcessRunning:$false

            $state.DesiredConfig | Should -Be 'Game.json'
            $state.EffectiveConfig | Should -Be 'Game.json'
            $state.VerificationStatus | Should -Be 'SUCCESS'
            $state.ProcessRunning | Should -BeFalse
            $state.StateConfidence | Should -Be 'Medium'
        } finally {
            Remove-FanControlTestSandbox -Sandbox $sandbox
        }
    }

    It 'falls back to unknown verification when CACHE is missing and status is unreadable' {
        $sandbox = New-FanControlTestSandbox
        try {
            Remove-Item -Path $sandbox.CacheFile -Force -ErrorAction SilentlyContinue
            Set-Content -Path (Join-Path $sandbox.StateDir 'current_status.json') -Value '{invalid json' -Encoding UTF8

            $state = Invoke-RuntimeStateInSandbox `
                -Sandbox $sandbox `
                -Now ([datetime]'2026-04-14T09:00:00') `
                -ProcessRunning:$false

            $state.DesiredConfig | Should -Be 'Game.json'
            $state.EffectiveConfig | Should -Be $null
            $state.CacheReadable | Should -BeFalse
            $state.StatusReadable | Should -BeFalse
            $state.VerificationStatus | Should -Be 'Unknown'
            $state.StateConfidence | Should -Be 'Low'
        } finally {
            Remove-FanControlTestSandbox -Sandbox $sandbox
        }
    }

    It 'ignores stale status data when CACHE is fresh and aligned' {
        $sandbox = New-FanControlTestSandbox
        try {
            @{
                CurrentConfigFileName = 'Quiet_mode.json'
                CustomConfigFolder = $sandbox.ConfigDir
            } | ConvertTo-Json | Set-Content -Path $sandbox.CacheFile -Encoding UTF8

            $statusPath = Join-Path $sandbox.StateDir 'current_status.json'
            @{
                Timestamp = '2026-04-14 21:30:00'
                Status = 'FAILED'
                TargetConfig = 'Quiet_mode.json'
                ActualConfig = 'Game.json'
            } | ConvertTo-Json | Set-Content -Path $statusPath -Encoding UTF8
            (Get-Item $statusPath).LastWriteTime = [datetime]'2026-04-14T21:30:00'
            (Get-Item $sandbox.CacheFile).LastWriteTime = [datetime]'2026-04-14T22:00:00'

            $state = Invoke-RuntimeStateInSandbox `
                -Sandbox $sandbox `
                -Now ([datetime]'2026-04-14T22:00:30') `
                -ProcessRunning:$true

            $state.DesiredConfig | Should -Be 'Quiet_mode.json'
            $state.EffectiveConfig | Should -Be 'Quiet_mode.json'
            $state.VerificationStatus | Should -Be 'Unknown'
            $state.CacheReadable | Should -BeTrue
            $state.ProcessRunning | Should -BeTrue
            $state.StateConfidence | Should -Be 'High'
        } finally {
            Remove-FanControlTestSandbox -Sandbox $sandbox
        }
    }
}
