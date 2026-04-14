Describe 'auto_switch.ps1 sandbox scenarios' {
    BeforeAll {
        . (Join-Path $PSScriptRoot 'TestHelpers.ps1')
    }

    It 'switches to Game during normal daytime operation' {
        $sandbox = New-FanControlTestSandbox
        try {
            Set-FanControlStubBehavior -Sandbox $sandbox -Mode 'ImmediateSuccess' -InitialConfig 'Quiet_mode.json'
            $result = Invoke-PowerShellScript `
                -ScriptPath (Join-Path $sandbox.RuntimeDir 'auto_switch.ps1') `
                -Environment @{ FANCONTROL_TEST_MINUTE = '480'; FANCONTROL_TEST_PROCESS_RUNNING = 'false' }
            $status = Get-SandboxStatus -Sandbox $sandbox
            $calls = Get-StubCallConfigs -Sandbox $sandbox

            $result.ExitCode | Should -Be 0
            $calls.Count | Should -Be 1
            $calls[0] | Should -Be 'Game.json'
            $status.Status | Should -Be 'SUCCESS'
            $status.Verified | Should -BeTrue
            $status.TargetConfig | Should -Be 'Game.json'
            $status.ActualConfig | Should -Be 'Game.json'
        } finally {
            Remove-FanControlTestSandbox -Sandbox $sandbox
        }
    }

    It 'skips switching when override is active outside force points' {
        $sandbox = New-FanControlTestSandbox
        try {
            Set-Content (Join-Path $sandbox.StateDir 'override.flag') 'quiet' -Encoding UTF8
            $result = Invoke-PowerShellScript `
                -ScriptPath (Join-Path $sandbox.RuntimeDir 'auto_switch.ps1') `
                -Environment @{ FANCONTROL_TEST_MINUTE = '480'; FANCONTROL_TEST_PROCESS_RUNNING = 'false' }
            $status = Get-SandboxStatus -Sandbox $sandbox
            $calls = Get-StubCallConfigs -Sandbox $sandbox

            $result.ExitCode | Should -Be 0
            $calls.Count | Should -Be 0
            $status.Status | Should -Be 'SKIPPED'
            $status.TargetConfig | Should -Be 'Override: quiet'
        } finally {
            Remove-FanControlTestSandbox -Sandbox $sandbox
        }
    }

    It 'clears override and forces Quiet at the exact force point' {
        $sandbox = New-FanControlTestSandbox
        try {
            Set-Content (Join-Path $sandbox.StateDir 'override.flag') 'game' -Encoding UTF8
            Set-FanControlStubBehavior -Sandbox $sandbox -Mode 'ImmediateSuccess' -InitialConfig 'Game.json'
            $result = Invoke-PowerShellScript `
                -ScriptPath (Join-Path $sandbox.RuntimeDir 'auto_switch.ps1') `
                -Environment @{ FANCONTROL_TEST_MINUTE = '760'; FANCONTROL_TEST_PROCESS_RUNNING = 'false' }
            $status = Get-SandboxStatus -Sandbox $sandbox
            $calls = Get-StubCallConfigs -Sandbox $sandbox

            $result.ExitCode | Should -Be 0
            (Test-Path (Join-Path $sandbox.StateDir 'override.flag')) | Should -BeFalse
            $calls.Count | Should -Be 1
            $calls[0] | Should -Be 'Quiet_mode.json'
            $status.Status | Should -Be 'SUCCESS'
            $status.TargetConfig | Should -Be 'Quiet_mode.json'
        } finally {
            Remove-FanControlTestSandbox -Sandbox $sandbox
        }
    }

    It 'retries once on a cold-start verification failure and then succeeds' {
        $sandbox = New-FanControlTestSandbox
        try {
            Set-FanControlStubBehavior -Sandbox $sandbox -Mode 'SucceedOnSecondCall' -InitialConfig 'Quiet_mode.json'
            $result = Invoke-PowerShellScript `
                -ScriptPath (Join-Path $sandbox.RuntimeDir 'auto_switch.ps1') `
                -Environment @{ FANCONTROL_TEST_MINUTE = '480'; FANCONTROL_TEST_PROCESS_RUNNING = 'false' }
            $status = Get-SandboxStatus -Sandbox $sandbox
            $calls = Get-StubCallConfigs -Sandbox $sandbox

            $result.ExitCode | Should -Be 0
            $calls.Count | Should -Be 2
            $calls[0] | Should -Be 'Game.json'
            $calls[1] | Should -Be 'Game.json'
            $status.Status | Should -Be 'SUCCESS'
            $status.Verified | Should -BeTrue
        } finally {
            Remove-FanControlTestSandbox -Sandbox $sandbox
        }
    }

    It 'does not retry after a failed verification when FanControl was already running' {
        $sandbox = New-FanControlTestSandbox
        try {
            Set-FanControlStubBehavior -Sandbox $sandbox -Mode 'NoCacheUpdate' -InitialConfig 'Quiet_mode.json'
            $result = Invoke-PowerShellScript `
                -ScriptPath (Join-Path $sandbox.RuntimeDir 'auto_switch.ps1') `
                -Environment @{ FANCONTROL_TEST_MINUTE = '480'; FANCONTROL_TEST_PROCESS_RUNNING = 'true' }
            $status = Get-SandboxStatus -Sandbox $sandbox
            $calls = Get-StubCallConfigs -Sandbox $sandbox

            $result.ExitCode | Should -Be 0
            $calls.Count | Should -Be 1
            $status.Status | Should -Be 'FAILED'
            $status.Verified | Should -BeFalse
            $status.TargetConfig | Should -Be 'Game.json'
        } finally {
            Remove-FanControlTestSandbox -Sandbox $sandbox
        }
    }

    It 'recovers from an invalid CACHE file during cold start' {
        $sandbox = New-FanControlTestSandbox
        try {
            Set-FanControlStubBehavior -Sandbox $sandbox -Mode 'InvalidCacheThenSuccess' -InitialConfig 'Quiet_mode.json'
            $result = Invoke-PowerShellScript `
                -ScriptPath (Join-Path $sandbox.RuntimeDir 'auto_switch.ps1') `
                -Environment @{ FANCONTROL_TEST_MINUTE = '480'; FANCONTROL_TEST_PROCESS_RUNNING = 'false' }
            $status = Get-SandboxStatus -Sandbox $sandbox
            $calls = Get-StubCallConfigs -Sandbox $sandbox

            $result.ExitCode | Should -Be 0
            $calls.Count | Should -Be 2
            $status.Status | Should -Be 'SUCCESS'
            $status.Verified | Should -BeTrue
            $status.ActualConfig | Should -Be 'Game.json'
        } finally {
            Remove-FanControlTestSandbox -Sandbox $sandbox
        }
    }
}
