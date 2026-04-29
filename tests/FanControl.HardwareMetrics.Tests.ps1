Describe 'FanControl hardware metrics helper' {
    BeforeAll {
        . (Join-Path $PSScriptRoot '..\scripts\current\runtime_paths.ps1')
        . (Join-Path $PSScriptRoot '..\scripts\current\hardware_metrics.ps1')

        $script:PreviousHardwareSnapshot = [Environment]::GetEnvironmentVariable('FANCONTROL_TEST_HARDWARE_SNAPSHOT', 'Process')
        $script:PreviousProcessorUtility = [Environment]::GetEnvironmentVariable('FANCONTROL_TEST_COUNTER_PROCESSOR_UTILITY', 'Process')
        $script:PreviousProcessorFrequency = [Environment]::GetEnvironmentVariable('FANCONTROL_TEST_COUNTER_PROCESSOR_FREQUENCY', 'Process')
        $script:PreviousFanControlExe = [Environment]::GetEnvironmentVariable('FANCONTROL_EXE', 'Process')
    }

    AfterAll {
        [Environment]::SetEnvironmentVariable('FANCONTROL_TEST_HARDWARE_SNAPSHOT', $script:PreviousHardwareSnapshot, 'Process')
        [Environment]::SetEnvironmentVariable('FANCONTROL_TEST_COUNTER_PROCESSOR_UTILITY', $script:PreviousProcessorUtility, 'Process')
        [Environment]::SetEnvironmentVariable('FANCONTROL_TEST_COUNTER_PROCESSOR_FREQUENCY', $script:PreviousProcessorFrequency, 'Process')
        [Environment]::SetEnvironmentVariable('FANCONTROL_EXE', $script:PreviousFanControlExe, 'Process')
    }

    BeforeEach {
        [Environment]::SetEnvironmentVariable('FANCONTROL_TEST_HARDWARE_SNAPSHOT', $null, 'Process')
        [Environment]::SetEnvironmentVariable('FANCONTROL_TEST_COUNTER_PROCESSOR_UTILITY', $null, 'Process')
        [Environment]::SetEnvironmentVariable('FANCONTROL_TEST_COUNTER_PROCESSOR_FREQUENCY', $null, 'Process')
        [Environment]::SetEnvironmentVariable('FANCONTROL_EXE', $null, 'Process')
    }

    It 'returns a complete metrics object from a fixture snapshot' {
        $fixture = @'
{
  "Temperatures": {
    "CPU Package": 58.2,
    "Core Average": 54.8,
    "P-Core #1 Distance to TjMax": 42,
    "P-Core #2 Distance to TjMax": 41
  },
  "Loads": {
    "CPU Total": 27.4
  },
  "Clocks": {
    "CPU Core #1": 4780,
    "CPU Core #2": 4760
  },
  "Fans": {
    "CPU Fan": 620,
    "System Fan #2": 310,
    "System Fan #3": 0,
    "System Fan #4": 0
  }
}
'@
        $env:FANCONTROL_TEST_HARDWARE_SNAPSHOT = $fixture

        $metrics = Get-FanControlHardwareMetrics

        $metrics.CpuPackage | Should -Be 58.2
        $metrics.CoreAverage | Should -Be 54.8
        $metrics.MinDistanceToTjMax | Should -Be 41
        $metrics.CpuLoadPercent | Should -Be 27.4
        $metrics.EffectiveClockMHz | Should -Be 4770
        $metrics.EffectiveClockMHz.GetType().Name | Should -Be 'Int32'
        $metrics.TotalFanRpm | Should -Be 930
        $metrics.DataConfidence | Should -Be 'High'
    }

    It 'keeps TotalFanRpm when one fan reading is missing' {
        $fixture = @'
{
  "Temperatures": {
    "CPU Package": 62.0,
    "Core Average": 55.0,
    "P-Core #1 Distance to TjMax": 38
  },
  "Loads": {
    "CPU Total": 31.0
  },
  "Clocks": {
    "CPU Core #1": 4700
  },
  "Fans": {
    "CPU Fan": 700,
    "System Fan #2": 350,
    "System Fan #4": 280
  }
}
'@
        $env:FANCONTROL_TEST_HARDWARE_SNAPSHOT = $fixture

        $metrics = Get-FanControlHardwareMetrics

        $metrics.SystemFan3Rpm | Should -BeNullOrEmpty
        $metrics.TotalFanRpm | Should -Be 1330
        $metrics.DataConfidence | Should -Be 'Medium'
    }

    It 'falls back to performance counters when snapshot has no load or clock values' {
        $fixture = @'
{
  "Temperatures": {
    "CPU Package": 66.5,
    "Core Average": 60.0,
    "P-Core #1 Distance to TjMax": 33
  },
  "Fans": {
    "CPU Fan": 900,
    "System Fan #2": 420,
    "System Fan #3": 350,
    "System Fan #4": 360
  }
}
'@
        $env:FANCONTROL_TEST_HARDWARE_SNAPSHOT = $fixture
        $env:FANCONTROL_TEST_COUNTER_PROCESSOR_UTILITY = '48.5'
        $env:FANCONTROL_TEST_COUNTER_PROCESSOR_FREQUENCY = '4520'

        $metrics = Get-FanControlHardwareMetrics

        $metrics.CpuLoadPercent | Should -Be 48.5
        $metrics.EffectiveClockMHz | Should -Be 4520
        $metrics.EffectiveClockMHz.GetType().Name | Should -Be 'Int32'
        $metrics.TotalFanRpm | Should -Be 2030
        $metrics.DataConfidence | Should -Be 'Medium'
    }

    It 'drops to low confidence when CPU Package is missing' {
        $fixture = @'
{
  "Temperatures": {
    "Core Average": 61.0,
    "P-Core #1 Distance to TjMax": 30
  },
  "Fans": {
    "CPU Fan": 950
  }
}
'@
        $env:FANCONTROL_TEST_HARDWARE_SNAPSHOT = $fixture

        $metrics = Get-FanControlHardwareMetrics

        $metrics.CpuPackage | Should -BeNullOrEmpty
        $metrics.DataConfidence | Should -Be 'Low'
    }

    It 'accepts a normalized sensor list fixture that matches the LibreHardwareMonitor traversal shape' {
        $fixture = @'
{
  "Sensors": [
    { "SensorType": "Temperature", "Name": "CPU Package", "Value": 64.0 },
    { "SensorType": "Temperature", "Name": "Core Average", "Value": 59.0 },
    { "SensorType": "Temperature", "Name": "P-Core #1 Distance to TjMax", "Value": 36.0 },
    { "SensorType": "Load", "Name": "CPU Total", "Value": 44.0 },
    { "SensorType": "Clock", "Name": "CPU Core #1", "Value": 4580.0 },
    { "SensorType": "Clock", "Name": "CPU Core #2", "Value": 4540.0 },
    { "SensorType": "Fan", "Name": "CPU Fan", "Value": 820.0 },
    { "SensorType": "Fan", "Name": "System Fan #2", "Value": 390.0 },
    { "SensorType": "Fan", "Name": "System Fan #3", "Value": 310.0 },
    { "SensorType": "Fan", "Name": "System Fan #4", "Value": 320.0 }
  ]
}
'@
        $env:FANCONTROL_TEST_HARDWARE_SNAPSHOT = $fixture

        $metrics = Get-FanControlHardwareMetrics

        $metrics.CpuPackage | Should -Be 64.0
        $metrics.CoreAverage | Should -Be 59.0
        $metrics.EffectiveClockMHz | Should -Be 4560
        $metrics.TotalFanRpm | Should -Be 1840
    }

    It 'matches known targets when sensor names include stable suffixes or prefixes' {
        $fixture = @'
{
  "Sensors": [
    { "SensorType": "Temperature", "Name": "CPU Package (Tctl/Tdie)", "Value": 63.0 },
    { "SensorType": "Temperature", "Name": "Core Average Temperature", "Value": 58.0 },
    { "SensorType": "Temperature", "Name": "P-Core #1 Distance to TjMax", "Value": 35.0 },
    { "SensorType": "Temperature", "Name": "System 1", "Value": 42.5 },
    { "SensorType": "Temperature", "Name": "VRM MOS", "Value": 49.0 },
    { "SensorType": "Temperature", "Name": "PCH", "Value": 55.0 },
    { "SensorType": "Temperature", "Name": "GPU Core", "Value": 71.0 },
    { "SensorType": "Load", "Name": "CPU Total Load", "Value": 42.0 },
    { "SensorType": "Load", "Name": "P-Core #1", "Value": 65.0 },
    { "SensorType": "Load", "Name": "E-Core #1", "Value": 37.0 },
    { "SensorType": "Load", "Name": "GPU D3D 3D", "Value": 87.0 },
    { "SensorType": "Clock", "Name": "CPU Core #1 Effective Clock", "Value": 4500.0 },
    { "SensorType": "Clock", "Name": "CPU Core #2 Effective Clock", "Value": 4460.0 },
    { "SensorType": "Clock", "Name": "P-Core #1 Effective Clock", "Value": 5075.4 },
    { "SensorType": "Clock", "Name": "E-Core #1 Effective Clock", "Value": 3794.1 },
    { "SensorType": "Power", "Name": "CPU Package Power", "Value": 98.4 },
    { "SensorType": "Fan", "Name": "CPU Fan 1", "Value": 810.0 },
    { "SensorType": "Fan", "Name": "System Fan #2 RPM", "Value": 380.0 },
    { "SensorType": "Fan", "Name": "System Fan #3 RPM", "Value": 300.0 },
    { "SensorType": "Fan", "Name": "System Fan #4 RPM", "Value": 290.0 },
    { "SensorType": "Fan", "Name": "GPU Fan 1", "Value": 2450.0 },
    { "SensorType": "Fan", "Name": "GPU Fan 2", "Value": 2440.0 }
  ]
}
'@
        $env:FANCONTROL_TEST_HARDWARE_SNAPSHOT = $fixture

        $metrics = Get-FanControlHardwareMetrics

        $metrics.CpuPackage | Should -Be 63.0
        $metrics.CoreAverage | Should -Be 58.0
        $metrics.CpuLoadPercent | Should -Be 42.0
        $metrics.CpuTotalLoad | Should -Be 42.0
        $metrics.CpuCoreMaxLoad | Should -Be 65.0
        $metrics.EffectiveClockMHz | Should -Be 4480
        $metrics.CpuClockAverageMHz | Should -Be 4480.0
        $metrics.PCoreClockAverageMHz | Should -Be 5075.4
        $metrics.ECoreClockAverageMHz | Should -Be 3794.1
        $metrics.CpuPackagePowerW | Should -Be 98.4
        $metrics.SystemTemp | Should -Be 42.5
        $metrics.VrmMosTemp | Should -Be 49.0
        $metrics.PchTemp | Should -Be 55.0
        $metrics.GpuTemp | Should -Be 71.0
        $metrics.Gpu3DUtil | Should -Be 87.0
        $metrics.CpuFanRpm | Should -Be 810.0
        $metrics.SystemFan2Rpm | Should -Be 380.0
        $metrics.SystemFan3Rpm | Should -Be 300.0
        $metrics.SystemFan4Rpm | Should -Be 290.0
        $metrics.GpuFan1Rpm | Should -Be 2450.0
        $metrics.GpuFan2Rpm | Should -Be 2440.0
        $metrics.TotalCaseFanRpm | Should -Be 970
        $metrics.TotalFanRpm | Should -Be 1780
        $metrics.TotalTrackedFanRpm | Should -Be 1780
    }

    It 'throws a clear error when the LibreHardwareMonitor library path is missing' {
        $env:FANCONTROL_EXE = 'D:\Missing\FanControl.exe'

        { Get-LibreHardwareMonitorSensors } | Should -Throw 'LibreHardwareMonitor library not found:*'
    }

    It 'throws a clear error when the library loads but the Computer type is still unavailable' {
        $tempRoot = Join-Path $env:TEMP ("fancontrol-lhm-missing-type-" + [guid]::NewGuid().ToString("N"))
        $tempExeDir = Join-Path $tempRoot 'FanControl'
        $null = New-Item -ItemType Directory -Path $tempExeDir -Force
        $libraryPath = Join-Path $tempExeDir 'LibreHardwareMonitorLib.dll'
        $null = New-Item -ItemType File -Path $libraryPath -Force
        $env:FANCONTROL_EXE = Join-Path $tempExeDir 'FanControl.exe'

        try {
            Mock Add-Type {}

            { Get-LibreHardwareMonitorSensors } | Should -Throw 'LibreHardwareMonitor library loaded but type LibreHardwareMonitor.Hardware.Computer is unavailable:*'
        } finally {
            Remove-Item -Path $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }

    It 'returns medium confidence when load and clock depend on fallback counters' {
        $fixture = @'
{
  "Sensors": [
    { "SensorType": "Temperature", "Name": "CPU Package", "Value": 61.0 },
    { "SensorType": "Temperature", "Name": "Core Average", "Value": 57.0 },
    { "SensorType": "Temperature", "Name": "P-Core #1 Distance to TjMax", "Value": 39.0 },
    { "SensorType": "Fan", "Name": "CPU Fan", "Value": 800.0 },
    { "SensorType": "Fan", "Name": "System Fan #2", "Value": 360.0 },
    { "SensorType": "Fan", "Name": "System Fan #3", "Value": 300.0 },
    { "SensorType": "Fan", "Name": "System Fan #4", "Value": 305.0 }
  ]
}
'@
        $env:FANCONTROL_TEST_HARDWARE_SNAPSHOT = $fixture
        $env:FANCONTROL_TEST_COUNTER_PROCESSOR_UTILITY = '52.0'
        $env:FANCONTROL_TEST_COUNTER_PROCESSOR_FREQUENCY = '4490'

        $metrics = Get-FanControlHardwareMetrics

        $metrics.CpuLoadPercent | Should -Be 52.0
        $metrics.EffectiveClockMHz | Should -Be 4490
        $metrics.DataConfidence | Should -Be 'Medium'
    }

    It 'accepts grouped fixture snapshots when invoked through Windows PowerShell' {
        $fixture = @'
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
        $tempScript = Join-Path $env:TEMP ("fancontrol-hardware-fixture-" + [guid]::NewGuid().ToString("N") + '.ps1')
        $outputPath = Join-Path $env:TEMP ("fancontrol-hardware-fixture-" + [guid]::NewGuid().ToString("N") + '.json')

        try {
            @"
. '$((Join-Path $PSScriptRoot '..\scripts\current\runtime_paths.ps1').Replace("'", "''"))'
. '$((Join-Path $PSScriptRoot '..\scripts\current\hardware_metrics.ps1').Replace("'", "''"))'
`$metrics = Get-FanControlHardwareMetrics
`$metrics | ConvertTo-Json -Depth 6 | Set-Content -Path '$($outputPath.Replace("'", "''"))' -Encoding UTF8
"@ | Set-Content -Path $tempScript -Encoding UTF8

            [Environment]::SetEnvironmentVariable('FANCONTROL_TEST_HARDWARE_SNAPSHOT', $fixture, 'Process')

            & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $tempScript
            $LASTEXITCODE | Should -Be 0

            $metrics = Get-Content -Path $outputPath -Raw | ConvertFrom-Json
            $metrics.CpuPackage | Should -Be 57.5
            $metrics.TotalFanRpm | Should -Be 610
        } finally {
            Remove-Item -Path $tempScript, $outputPath -Force -ErrorAction SilentlyContinue
        }
    }
}
