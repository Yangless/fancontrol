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

            $hardwareFixture = @'
{
  "Temperatures": {
    "CPU Package": 57.5,
    "Core Average": 53.0,
    "P-Core #1 Distance to TjMax": 43
  },
  "Loads": {
    "CPU Total": 24.0
  },
  "Clocks": {
    "CPU Core #1": 4700.0
  },
  "Fans": {
    "CPU Fan": 610.0,
    "System Fan #2": 0.0,
    "System Fan #3": 0.0,
    "System Fan #4": 0.0
  }
}
'@

            $result = Invoke-PowerShellScript `
                -ScriptPath (Join-Path $sandbox.RuntimeDir 'monitor_simple.ps1') `
                -Arguments @('-Mode', 'Snapshot', '-OutputDir', $sandbox.MonitorDir) `
                -Environment (Get-SandboxEnvironment -Sandbox $sandbox -Values @{
                    FANCONTROL_TEST_PROCESS_RUNNING = 'True'
                    FANCONTROL_TEST_MINUTE = 540
                    FANCONTROL_TEST_HARDWARE_SNAPSHOT = $hardwareFixture
                })

            $files = Get-MonitorJsonFiles -Sandbox $sandbox
            $files.Count | Should -Be 1

            $snapshot = Get-Content -Path $files[0].FullName -Raw | ConvertFrom-Json
            $result.ExitCode | Should -Be 0
            $snapshot.Runtime.DesiredConfig | Should -Be 'Game.json'
            $snapshot.Runtime.EffectiveConfig | Should -Be 'Game.json'
            $snapshot.Hardware.CpuPackage | Should -Be 57.5
            $snapshot.Hardware.TotalFanRpm | Should -Be 610
            ($result.Output -join "`n") | Should -Match 'CPU:57.5C.*Total:610'
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

            $hardwareFixture = @'
{
  "Temperatures": {
    "CPU Package": 58.0,
    "Core Average": 54.0,
    "P-Core #1 Distance to TjMax": 42
  },
  "Loads": {
    "CPU Total": 26.0
  },
  "Clocks": {
    "CPU Core #1": 4680.0
  },
  "Fans": {
    "CPU Fan": 620.0,
    "System Fan #2": 310.0,
    "System Fan #3": 0.0,
    "System Fan #4": 0.0
  }
}
'@

            $result = Invoke-PowerShellScript `
                -ScriptPath (Join-Path $sandbox.RuntimeDir 'monitor_simple.ps1') `
                -Arguments @('-Mode', 'Sample', '-IntervalSeconds', '1', '-MaxSamples', '2', '-OutputDir', $sandbox.MonitorDir) `
                -Environment (Get-SandboxEnvironment -Sandbox $sandbox -Values @{
                    FANCONTROL_TEST_PROCESS_RUNNING = 'True'
                    FANCONTROL_TEST_MINUTE = 540
                    FANCONTROL_TEST_HARDWARE_SNAPSHOT = $hardwareFixture
                })

            $files = Get-MonitorJsonFiles -Sandbox $sandbox
            $files.Count | Should -Be 1

            $summary = Get-Content -Path $files[0].FullName -Raw | ConvertFrom-Json
            $result.ExitCode | Should -Be 0
            $summary.Mode | Should -Be 'Sample'
            $summary.SampleCount | Should -Be 2
            @($summary.Samples).Count | Should -Be 2
            $summary.Samples[0].Runtime.DesiredConfig | Should -Be 'Game.json'
            $summary.Samples[0].Hardware.TotalFanRpm | Should -BeGreaterThan 0
        } finally {
            Remove-FanControlTestSandbox -Sandbox $sandbox
        }
    }

    It 'does not crash on invalid CACHE and still emits unified state output' {
        $sandbox = New-FanControlTestSandbox
        try {
            Set-Content -Path $sandbox.CacheFile -Value '{invalid json' -Encoding UTF8

            $hardwareFixture = @'
{
  "Temperatures": {
    "CPU Package": 55.0,
    "Core Average": 50.0,
    "P-Core #1 Distance to TjMax": 45
  },
  "Loads": {
    "CPU Total": 18.0
  },
  "Clocks": {
    "CPU Core #1": 4500.0
  },
  "Fans": {
    "CPU Fan": 500.0,
    "System Fan #2": 250.0,
    "System Fan #3": 0.0,
    "System Fan #4": 0.0
  }
}
'@

            $result = Invoke-PowerShellScript `
                -ScriptPath (Join-Path $sandbox.RuntimeDir 'monitor_simple.ps1') `
                -Arguments @('-Mode', 'Snapshot', '-OutputDir', $sandbox.MonitorDir) `
                -Environment (Get-SandboxEnvironment -Sandbox $sandbox -Values @{
                    FANCONTROL_TEST_PROCESS_RUNNING = 'False'
                    FANCONTROL_TEST_MINUTE = 540
                    FANCONTROL_TEST_HARDWARE_SNAPSHOT = $hardwareFixture
                })

            $files = Get-MonitorJsonFiles -Sandbox $sandbox
            $files.Count | Should -Be 1

            $snapshot = Get-Content -Path $files[0].FullName -Raw | ConvertFrom-Json
            $result.ExitCode | Should -Be 0
            $snapshot.Runtime.CacheReadable | Should -BeFalse
            $snapshot.Runtime.VerificationStatus | Should -Be 'Unknown'
            $snapshot.Runtime.StateConfidence | Should -Be 'Low'
            $snapshot.Hardware | Should -Not -BeNullOrEmpty
        } finally {
            Remove-FanControlTestSandbox -Sandbox $sandbox
        }
    }

    It 'formats decimal summaries with invariant separators under a non-English culture' {
        $sandbox = New-FanControlTestSandbox
        $wrapperPath = Join-Path $sandbox.Root 'invoke_monitor_with_culture.ps1'

        try {
            @{
                CurrentConfigFileName = 'Game.json'
                CustomConfigFolder = $sandbox.ConfigDir
            } | ConvertTo-Json | Set-Content -Path $sandbox.CacheFile -Encoding UTF8

            $hardwareFixture = @'
{
  "Temperatures": {
    "CPU Package": 57.5,
    "Core Average": 53.0,
    "P-Core #1 Distance to TjMax": 43
  },
  "Loads": {
    "CPU Total": 24.0
  },
  "Clocks": {
    "CPU Core #1": 4700.0
  },
  "Fans": {
    "CPU Fan": 610.0,
    "System Fan #2": 0.0,
    "System Fan #3": 0.0,
    "System Fan #4": 0.0
  }
}
'@

            @"
param(
    [string]`$ScriptPath,
    [string]`$OutputDir
)

[System.Threading.Thread]::CurrentThread.CurrentCulture = [System.Globalization.CultureInfo]::GetCultureInfo('fr-FR')
[System.Threading.Thread]::CurrentThread.CurrentUICulture = [System.Globalization.CultureInfo]::GetCultureInfo('fr-FR')

& `$ScriptPath -Mode Snapshot -OutputDir `$OutputDir
exit `$LASTEXITCODE
"@ | Set-Content -Path $wrapperPath -Encoding UTF8

            $environment = Get-SandboxEnvironment -Sandbox $sandbox -Values @{
                FANCONTROL_TEST_PROCESS_RUNNING = 'True'
                FANCONTROL_TEST_MINUTE = 540
                FANCONTROL_TEST_HARDWARE_SNAPSHOT = $hardwareFixture
            }
            $previousValues = @{}

            foreach ($key in $environment.Keys) {
                $previousValues[$key] = [Environment]::GetEnvironmentVariable($key, 'Process')
                [Environment]::SetEnvironmentVariable($key, [string]$environment[$key], 'Process')
            }

            try {
                $output = & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $wrapperPath -ScriptPath (Join-Path $sandbox.RuntimeDir 'monitor_simple.ps1') -OutputDir $sandbox.MonitorDir 2>&1
                $exitCode = $LASTEXITCODE
            } finally {
                foreach ($key in $environment.Keys) {
                    [Environment]::SetEnvironmentVariable($key, $previousValues[$key], 'Process')
                }
            }

            $exitCode | Should -Be 0
            $summaryOutput = $output -join "`n"
            $summaryOutput | Should -Match 'CPU:57.5C.*Total:610'
            $summaryOutput | Should -Not -Match 'CPU:57,5C'
        } finally {
            Remove-FanControlTestSandbox -Sandbox $sandbox
        }
    }
}
