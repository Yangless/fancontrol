Describe 'monitor_simple.ps1 behavior' {
    BeforeAll {
        . (Join-Path $PSScriptRoot 'TestHelpers.ps1')
    }

    function script:Get-MonitorJsonFiles {
        param(
            [Parameter(Mandatory = $true)]$Sandbox
        )

        return @(Get-ChildItem -Path $Sandbox.MonitorDir -Filter '*.json' -File -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime)
    }

    It 'writes exactly one snapshot record in Snapshot mode' {
        $sandbox = New-FanControlTestSandbox
        try {
            @{
                CurrentConfigFileName = 'Game.json'
                CustomConfigFolder = $sandbox.ConfigDir
            } | ConvertTo-Json | Set-Content -Path $sandbox.CacheFile -Encoding UTF8

            $result = Invoke-PowerShellScript `
                -ScriptPath (Join-Path $sandbox.RuntimeDir 'monitor_simple.ps1') `
                -Arguments @('-Mode', 'Snapshot', '-OutputDir', $sandbox.MonitorDir) `
                -Environment (Get-SandboxEnvironment -Sandbox $sandbox -Values @{
                    FANCONTROL_TEST_PROCESS_RUNNING = 'True'
                    FANCONTROL_TEST_MINUTE = 540
                })

            $files = Get-MonitorJsonFiles -Sandbox $sandbox
            $files.Count | Should -Be 1

            $snapshot = Get-Content -Path $files[0].FullName -Raw | ConvertFrom-Json
            $result.ExitCode | Should -Be 0
            $snapshot.DesiredConfig | Should -Be 'Game.json'
            $snapshot.EffectiveConfig | Should -Be 'Game.json'
            $snapshot.ProcessRunning | Should -BeTrue
        } finally {
            Remove-FanControlTestSandbox -Sandbox $sandbox
        }
    }

    It 'stops after MaxSamples in Sample mode and writes the collected samples' {
        $sandbox = New-FanControlTestSandbox
        try {
            @{
                CurrentConfigFileName = 'Game.json'
                CustomConfigFolder = $sandbox.ConfigDir
            } | ConvertTo-Json | Set-Content -Path $sandbox.CacheFile -Encoding UTF8

            $result = Invoke-PowerShellScript `
                -ScriptPath (Join-Path $sandbox.RuntimeDir 'monitor_simple.ps1') `
                -Arguments @('-Mode', 'Sample', '-IntervalSeconds', '1', '-MaxSamples', '2', '-OutputDir', $sandbox.MonitorDir) `
                -Environment (Get-SandboxEnvironment -Sandbox $sandbox -Values @{
                    FANCONTROL_TEST_PROCESS_RUNNING = 'True'
                    FANCONTROL_TEST_MINUTE = 540
                })

            $files = Get-MonitorJsonFiles -Sandbox $sandbox
            $files.Count | Should -Be 1

            $summary = Get-Content -Path $files[0].FullName -Raw | ConvertFrom-Json
            $result.ExitCode | Should -Be 0
            $summary.Mode | Should -Be 'Sample'
            $summary.SampleCount | Should -Be 2
            @($summary.Samples).Count | Should -Be 2
        } finally {
            Remove-FanControlTestSandbox -Sandbox $sandbox
        }
    }

    It 'does not crash on invalid CACHE and still emits unified state output' {
        $sandbox = New-FanControlTestSandbox
        try {
            Set-Content -Path $sandbox.CacheFile -Value '{invalid json' -Encoding UTF8

            $result = Invoke-PowerShellScript `
                -ScriptPath (Join-Path $sandbox.RuntimeDir 'monitor_simple.ps1') `
                -Arguments @('-Mode', 'Snapshot', '-OutputDir', $sandbox.MonitorDir) `
                -Environment (Get-SandboxEnvironment -Sandbox $sandbox -Values @{
                    FANCONTROL_TEST_PROCESS_RUNNING = 'False'
                    FANCONTROL_TEST_MINUTE = 540
                })

            $files = Get-MonitorJsonFiles -Sandbox $sandbox
            $files.Count | Should -Be 1

            $snapshot = Get-Content -Path $files[0].FullName -Raw | ConvertFrom-Json
            $result.ExitCode | Should -Be 0
            $snapshot.CacheReadable | Should -BeFalse
            $snapshot.VerificationStatus | Should -Be 'Unknown'
            $snapshot.StateConfidence | Should -Be 'Low'
        } finally {
            Remove-FanControlTestSandbox -Sandbox $sandbox
        }
    }
}
