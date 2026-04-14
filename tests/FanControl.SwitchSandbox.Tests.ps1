Describe 'switch.ps1 sandbox scenarios' {
    BeforeAll {
        . (Join-Path $PSScriptRoot 'TestHelpers.ps1')
    }

    It 'shows help when no mode is provided' {
        $sandbox = New-FanControlTestSandbox
        try {
            Set-SandboxAutoSwitchStub -Sandbox $sandbox
            $result = Invoke-PowerShellScript `
                -ScriptPath (Join-Path $sandbox.RuntimeDir 'switch.ps1') `
                -Environment (Get-SandboxEnvironment -Sandbox $sandbox)

            $result.ExitCode | Should -Be 0
            (($result.Output -join "`n") -match 'FanControl Manual Switch Tool') | Should -BeTrue
        } finally {
            Remove-FanControlTestSandbox -Sandbox $sandbox
        }
    }

    It 'rejects invalid modes' {
        $sandbox = New-FanControlTestSandbox
        try {
            Set-SandboxAutoSwitchStub -Sandbox $sandbox
            $result = Invoke-PowerShellScript `
                -ScriptPath (Join-Path $sandbox.RuntimeDir 'switch.ps1') `
                -Arguments @('-Mode', 'badmode') `
                -Environment (Get-SandboxEnvironment -Sandbox $sandbox)

            $result.ExitCode | Should -Be 1
            (($result.Output -join "`n") -match 'Invalid mode') | Should -BeTrue
        } finally {
            Remove-FanControlTestSandbox -Sandbox $sandbox
        }
    }

    It 'switches to game mode and writes the override flag' {
        $sandbox = New-FanControlTestSandbox
        try {
            $result = Invoke-PowerShellScript `
                -ScriptPath (Join-Path $sandbox.RuntimeDir 'switch.ps1') `
                -Arguments @('-Mode', 'game') `
                -Environment (Get-SandboxEnvironment -Sandbox $sandbox)
            $overridePath = Join-Path $sandbox.StateDir 'override.flag'

            $result.ExitCode | Should -Be 0
            (Get-Content $overridePath) | Should -Be 'game'
            (Get-StubCallConfigs -Sandbox $sandbox) | Should -Be @('Game.json')
        } finally {
            Remove-FanControlTestSandbox -Sandbox $sandbox
        }
    }

    It 'switches to quiet mode and writes the override flag' {
        $sandbox = New-FanControlTestSandbox
        try {
            Set-SandboxVolumeState -Sandbox $sandbox -CurrentVolume 55
            $result = Invoke-PowerShellScript `
                -ScriptPath (Join-Path $sandbox.RuntimeDir 'switch.ps1') `
                -Arguments @('-Mode', 'quiet') `
                -Environment (Get-SandboxEnvironment -Sandbox $sandbox)
            $overridePath = Join-Path $sandbox.StateDir 'override.flag'

            $result.ExitCode | Should -Be 0
            (Get-Content $overridePath) | Should -Be 'quiet'
            (Get-StubCallConfigs -Sandbox $sandbox) | Should -Be @('Quiet_mode.json')
            (Get-SandboxCurrentVolume -Sandbox $sandbox) | Should -Be 0
            (Get-SandboxSavedVolume -Sandbox $sandbox) | Should -Be 55
        } finally {
            Remove-FanControlTestSandbox -Sandbox $sandbox
        }
    }

    It 'restores auto mode without passing -Force to auto_switch.ps1' {
        $sandbox = New-FanControlTestSandbox
        try {
            Set-SandboxAutoSwitchStub -Sandbox $sandbox
            Set-Content (Join-Path $sandbox.StateDir 'override.flag') 'game' -Encoding UTF8

            $result = Invoke-PowerShellScript `
                -ScriptPath (Join-Path $sandbox.RuntimeDir 'switch.ps1') `
                -Arguments @('-Mode', 'auto') `
                -Environment (Get-SandboxEnvironment -Sandbox $sandbox)

            $result.ExitCode | Should -Be 0
            (Test-Path (Join-Path $sandbox.StateDir 'override.flag')) | Should -BeFalse
            (Get-AutoSwitchStubCalls -Sandbox $sandbox) | Should -Be @('Force=False')
        } finally {
            Remove-FanControlTestSandbox -Sandbox $sandbox
        }
    }
}
