Describe 'check_status.ps1 behavior' {
    BeforeAll {
        . (Join-Path $PSScriptRoot 'TestHelpers.ps1')
    }

    It 'prints the unified runtime state fields' {
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
                ObservedConfig = 'Game.json'
                VerificationConfidence = 'High'
            } | ConvertTo-Json | Set-Content -Path (Join-Path $sandbox.StateDir 'current_status.json') -Encoding UTF8

            $result = Invoke-PowerShellScript `
                -ScriptPath (Join-Path $sandbox.RuntimeDir 'check_status.ps1') `
                -Environment (Get-SandboxEnvironment -Sandbox $sandbox -Values @{
                    FANCONTROL_TEST_PROCESS_RUNNING = 'True'
                    FANCONTROL_TEST_MINUTE = 540
                })

            $output = $result.Output -join "`n"

            $result.ExitCode | Should -Be 0
            $output | Should -Match 'DesiredConfig\s*: Game\.json'
            $output | Should -Match 'EffectiveConfig\s*: Game\.json'
            $output | Should -Match 'VerificationStatus\s*: SUCCESS'
            $output | Should -Match 'VerificationConfidence\s*: High'
            $output | Should -Match 'ObservedConfig\s*: Game\.json'
            $output | Should -Match 'StateConfidence\s*: High'
        } finally {
            Remove-FanControlTestSandbox -Sandbox $sandbox
        }
    }

    It 'survives an invalid CACHE file and degrades to unknown verification' {
        $sandbox = New-FanControlTestSandbox
        try {
            Set-Content -Path $sandbox.CacheFile -Value '{invalid json' -Encoding UTF8

            $result = Invoke-PowerShellScript `
                -ScriptPath (Join-Path $sandbox.RuntimeDir 'check_status.ps1') `
                -Environment (Get-SandboxEnvironment -Sandbox $sandbox -Values @{
                    FANCONTROL_TEST_PROCESS_RUNNING = 'False'
                    FANCONTROL_TEST_MINUTE = 540
                })

            $output = $result.Output -join "`n"

            $result.ExitCode | Should -Be 0
            $output | Should -Match 'CacheReadable\s*: False'
            $output | Should -Match 'VerificationStatus\s*: Unknown'
            $output | Should -Match 'StateConfidence\s*: Low'
        } finally {
            Remove-FanControlTestSandbox -Sandbox $sandbox
        }
    }
}
