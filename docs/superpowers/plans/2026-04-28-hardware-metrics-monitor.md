# Hardware Metrics Monitor Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a reusable hardware metrics helper and extend monitor sampling so FanControl tuning can use CPU temperature, load, frequency, per-fan RPM, and total fan RPM alongside runtime state.

**Architecture:** Keep runtime state and hardware metrics as separate helpers. `hardware_metrics.ps1` owns sensor and fallback counter reads, while `monitor_simple.ps1` only merges data, prints summaries, and writes sample files. Tests should run without real hardware by feeding fixture snapshots through environment-controlled test hooks.

**Tech Stack:** PowerShell, Pester 5.x, LibreHardwareMonitorLib.dll, Windows performance counters, JSON sample files

---

## File Structure

- Create: `D:\Y\others\fancontrol\scripts\current\hardware_metrics.ps1`
  - Shared hardware sampling helper
  - Loads `LibreHardwareMonitorLib.dll`
  - Exposes `Get-FanControlHardwareMetrics`
- Modify: `D:\Y\others\fancontrol\scripts\current\monitor_simple.ps1`
  - Imports `hardware_metrics.ps1`
  - Merges runtime and hardware objects
  - Prints the expanded one-line summary
  - Writes nested `Runtime` and `Hardware` JSON payloads
- Modify: `D:\Y\others\fancontrol\tests\TestHelpers.ps1`
  - Copies `hardware_metrics.ps1` into sandboxes
  - Adds environment hooks for hardware fixtures and counter fallbacks
- Create: `D:\Y\others\fancontrol\tests\FanControl.HardwareMetrics.Tests.ps1`
  - Unit coverage for complete metrics, missing RPM, and fallback counter scenarios
- Modify: `D:\Y\others\fancontrol\tests\FanControl.Monitor.Tests.ps1`
  - Update monitor expectations to the new nested sample schema
  - Assert summary output includes temperature and total fan RPM

### Task 1: Build the hardware metrics helper under test

**Files:**
- Create: `D:\Y\others\fancontrol\scripts\current\hardware_metrics.ps1`
- Create: `D:\Y\others\fancontrol\tests\FanControl.HardwareMetrics.Tests.ps1`

- [ ] **Step 1: Write the failing hardware metrics tests**

Create `tests/FanControl.HardwareMetrics.Tests.ps1` with:

```powershell
Describe 'FanControl hardware metrics helper' {
    BeforeAll {
        . (Join-Path $PSScriptRoot '..\scripts\current\runtime_paths.ps1')
        . (Join-Path $PSScriptRoot '..\scripts\current\hardware_metrics.ps1')
    }

    BeforeEach {
        $env:FANCONTROL_TEST_HARDWARE_SNAPSHOT = $null
        $env:FANCONTROL_TEST_COUNTER_PROCESSOR_UTILITY = $null
        $env:FANCONTROL_TEST_COUNTER_PROCESSOR_FREQUENCY = $null
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
}
```

- [ ] **Step 2: Run the test file to confirm it fails**

Run:

```powershell
pwsh -NoProfile -Command "Import-Module Pester -MinimumVersion 5.0; Invoke-Pester .\tests\FanControl.HardwareMetrics.Tests.ps1 -Output Detailed"
```

Expected: FAIL because `hardware_metrics.ps1` does not exist yet.

- [ ] **Step 3: Write the minimal helper implementation**

Create `scripts/current/hardware_metrics.ps1` with:

```powershell
$RuntimePathsHelper = Join-Path $PSScriptRoot "runtime_paths.ps1"
if (Test-Path $RuntimePathsHelper) {
    . $RuntimePathsHelper
} else {
    throw "Helper file not found: $RuntimePathsHelper"
}

function Get-TestHardwareSnapshot {
    if (-not $env:FANCONTROL_TEST_HARDWARE_SNAPSHOT) {
        return $null
    }

    return $env:FANCONTROL_TEST_HARDWARE_SNAPSHOT | ConvertFrom-Json -AsHashtable
}

function Get-FallbackCounterValue {
    param(
        [Parameter(Mandatory = $true)][string]$CounterPath,
        [Parameter(Mandatory = $true)][string]$EnvironmentName
    )

    if ($env:$EnvironmentName) {
        return [double]$env:$EnvironmentName
    }

    return (Get-Counter $CounterPath).CounterSamples[0].CookedValue
}

function Get-AverageValue {
    param($Values)

    if (-not $Values -or $Values.Count -eq 0) {
        return $null
    }

    return [math]::Round((($Values | Measure-Object -Average).Average), 1)
}

function Get-DataConfidence {
    param(
        $CpuPackage,
        $CoreAverage,
        $CpuLoadPercent,
        $EffectiveClockMHz,
        $CpuFanRpm,
        $SystemFan2Rpm,
        $SystemFan3Rpm,
        $SystemFan4Rpm,
        [bool]$UsedFallbackCounters
    )

    if ($null -eq $CpuPackage) {
        return 'Low'
    }

    $missingRpm = @($CpuFanRpm, $SystemFan2Rpm, $SystemFan3Rpm, $SystemFan4Rpm) | Where-Object { $null -eq $_ }
    if ($UsedFallbackCounters -or $missingRpm.Count -gt 0 -or $null -eq $CpuLoadPercent -or $null -eq $EffectiveClockMHz) {
        return 'Medium'
    }

    return 'High'
}

function Get-FanControlHardwareMetrics {
    $snapshot = Get-TestHardwareSnapshot
    $usedFallbackCounters = $false

    $cpuPackage = $null
    $coreAverage = $null
    $minDistanceToTjMax = $null
    $cpuLoadPercent = $null
    $effectiveClockMHz = $null
    $cpuFanRpm = $null
    $systemFan2Rpm = $null
    $systemFan3Rpm = $null
    $systemFan4Rpm = $null

    if ($snapshot) {
        $cpuPackage = $snapshot.Temperatures['CPU Package']
        $coreAverage = $snapshot.Temperatures['Core Average']
        $distanceValues = @($snapshot.Temperatures.GetEnumerator() | Where-Object { $_.Key -like '*Distance to TjMax*' } | ForEach-Object { [double]$_.Value })
        if ($distanceValues.Count -gt 0) {
            $minDistanceToTjMax = ($distanceValues | Measure-Object -Minimum).Minimum
        }

        $cpuLoadPercent = $snapshot.Loads['CPU Total']
        $clockValues = @($snapshot.Clocks.Values | ForEach-Object { [double]$_ })
        if ($clockValues.Count -gt 0) {
            $effectiveClockMHz = Get-AverageValue -Values $clockValues
        }

        $cpuFanRpm = $snapshot.Fans['CPU Fan']
        $systemFan2Rpm = $snapshot.Fans['System Fan #2']
        $systemFan3Rpm = $snapshot.Fans['System Fan #3']
        $systemFan4Rpm = $snapshot.Fans['System Fan #4']
    } else {
        throw 'Real LibreHardwareMonitor implementation is added in Task 2.'
    }

    if ($null -eq $cpuLoadPercent) {
        $cpuLoadPercent = [math]::Round((Get-FallbackCounterValue -CounterPath '\Processor Information(_Total)\% Processor Utility' -EnvironmentName 'FANCONTROL_TEST_COUNTER_PROCESSOR_UTILITY'), 1)
        $usedFallbackCounters = $true
    }

    if ($null -eq $effectiveClockMHz) {
        $effectiveClockMHz = [int][math]::Round((Get-FallbackCounterValue -CounterPath '\Processor Information(_Total)\Processor Frequency' -EnvironmentName 'FANCONTROL_TEST_COUNTER_PROCESSOR_FREQUENCY'), 0)
        $usedFallbackCounters = $true
    }

    $totalFanRpm = @($cpuFanRpm, $systemFan2Rpm, $systemFan3Rpm, $systemFan4Rpm) |
        Where-Object { $null -ne $_ } |
        Measure-Object -Sum |
        Select-Object -ExpandProperty Sum

    [PSCustomObject]@{
        CpuPackage = $cpuPackage
        CoreAverage = $coreAverage
        MinDistanceToTjMax = $minDistanceToTjMax
        CpuLoadPercent = $cpuLoadPercent
        EffectiveClockMHz = $effectiveClockMHz
        CpuFanRpm = $cpuFanRpm
        SystemFan2Rpm = $systemFan2Rpm
        SystemFan3Rpm = $systemFan3Rpm
        SystemFan4Rpm = $systemFan4Rpm
        TotalFanRpm = $totalFanRpm
        DataConfidence = Get-DataConfidence `
            -CpuPackage $cpuPackage `
            -CoreAverage $coreAverage `
            -CpuLoadPercent $cpuLoadPercent `
            -EffectiveClockMHz $effectiveClockMHz `
            -CpuFanRpm $cpuFanRpm `
            -SystemFan2Rpm $systemFan2Rpm `
            -SystemFan3Rpm $systemFan3Rpm `
            -SystemFan4Rpm $systemFan4Rpm `
            -UsedFallbackCounters:$usedFallbackCounters
    }
}
```

- [ ] **Step 4: Run the new test file to verify it passes**

Run:

```powershell
pwsh -NoProfile -Command "Import-Module Pester -MinimumVersion 5.0; Invoke-Pester .\tests\FanControl.HardwareMetrics.Tests.ps1 -Output Detailed"
```

Expected: PASS with 4 passing tests.

- [ ] **Step 5: Commit the helper skeleton**

Run:

```bash
git add scripts/current/hardware_metrics.ps1 tests/FanControl.HardwareMetrics.Tests.ps1
git commit -m "feat: add hardware metrics helper skeleton"
```

Expected: one commit for the testable helper contract and fixture-based implementation.

### Task 2: Replace the fixture-only implementation with real LibreHardwareMonitor reads

**Files:**
- Modify: `D:\Y\others\fancontrol\scripts\current\hardware_metrics.ps1`

- [ ] **Step 1: Extend the tests with a real-snapshot shape expectation**

Append this test to `tests/FanControl.HardwareMetrics.Tests.ps1`:

```powershell
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
```

- [ ] **Step 2: Run the test to confirm the fixture-shape case fails**

Run:

```powershell
pwsh -NoProfile -Command "Import-Module Pester -MinimumVersion 5.0; Invoke-Pester .\tests\FanControl.HardwareMetrics.Tests.ps1 -Output Detailed"
```

Expected: FAIL because the helper only understands the grouped fixture shape from Task 1.

- [ ] **Step 3: Implement real sensor traversal with the same normalized output**

Update `scripts/current/hardware_metrics.ps1` by replacing the fixture loader and real-data branch with:

```powershell
function Get-LibreHardwareMonitorSensors {
    if ($env:FANCONTROL_TEST_HARDWARE_SNAPSHOT) {
        $fixture = $env:FANCONTROL_TEST_HARDWARE_SNAPSHOT | ConvertFrom-Json -AsHashtable
        if ($fixture.ContainsKey('Sensors')) {
            return @($fixture.Sensors)
        }

        $result = @()
        foreach ($name in $fixture.Temperatures.Keys) {
            $result += [PSCustomObject]@{ SensorType = 'Temperature'; Name = $name; Value = [double]$fixture.Temperatures[$name] }
        }
        foreach ($name in $fixture.Loads.Keys) {
            $result += [PSCustomObject]@{ SensorType = 'Load'; Name = $name; Value = [double]$fixture.Loads[$name] }
        }
        foreach ($name in $fixture.Clocks.Keys) {
            $result += [PSCustomObject]@{ SensorType = 'Clock'; Name = $name; Value = [double]$fixture.Clocks[$name] }
        }
        foreach ($name in $fixture.Fans.Keys) {
            $result += [PSCustomObject]@{ SensorType = 'Fan'; Name = $name; Value = [double]$fixture.Fans[$name] }
        }
        return $result
    }

    $paths = Get-FanControlPaths
    $libraryPath = Join-Path (Split-Path $paths.FanControlExe -Parent) 'LibreHardwareMonitorLib.dll'
    Add-Type -Path $libraryPath

    $computer = [LibreHardwareMonitor.Hardware.Computer]::new()
    $computer.IsCpuEnabled = $true
    $computer.IsMotherboardEnabled = $true
    $computer.Open()

    $sensors = @()
    foreach ($hardware in $computer.Hardware) {
        $hardware.Update()
        foreach ($subHardware in $hardware.SubHardware) {
            $subHardware.Update()
        }

        foreach ($sensor in $hardware.Sensors) {
            if ($null -ne $sensor.Value) {
                $sensors += [PSCustomObject]@{
                    SensorType = [string]$sensor.SensorType
                    Name = [string]$sensor.Name
                    Value = [double]$sensor.Value
                }
            }
        }

        foreach ($subHardware in $hardware.SubHardware) {
            foreach ($sensor in $subHardware.Sensors) {
                if ($null -ne $sensor.Value) {
                    $sensors += [PSCustomObject]@{
                        SensorType = [string]$sensor.SensorType
                        Name = [string]$sensor.Name
                        Value = [double]$sensor.Value
                    }
                }
            }
        }
    }

    return $sensors
}

function Get-SensorValue {
    param(
        [Parameter(Mandatory = $true)]$Sensors,
        [Parameter(Mandatory = $true)][string]$SensorType,
        [Parameter(Mandatory = $true)][string]$Name
    )

    $match = $Sensors | Where-Object { $_.SensorType -eq $SensorType -and $_.Name -eq $Name } | Select-Object -First 1
    if ($match) { return [double]$match.Value }
    return $null
}

function Get-SensorValuesByPattern {
    param(
        [Parameter(Mandatory = $true)]$Sensors,
        [Parameter(Mandatory = $true)][string]$SensorType,
        [Parameter(Mandatory = $true)][string]$NamePattern
    )

    return @($Sensors | Where-Object { $_.SensorType -eq $SensorType -and $_.Name -like $NamePattern } | ForEach-Object { [double]$_.Value })
}
```

Then update `Get-FanControlHardwareMetrics` so the top of the function becomes:

```powershell
    $sensors = Get-LibreHardwareMonitorSensors
    $usedFallbackCounters = $false

    $cpuPackage = Get-SensorValue -Sensors $sensors -SensorType 'Temperature' -Name 'CPU Package'
    $coreAverage = Get-SensorValue -Sensors $sensors -SensorType 'Temperature' -Name 'Core Average'

    $distanceValues = Get-SensorValuesByPattern -Sensors $sensors -SensorType 'Temperature' -NamePattern '*Distance to TjMax*'
    if ($distanceValues.Count -gt 0) {
        $minDistanceToTjMax = ($distanceValues | Measure-Object -Minimum).Minimum
    }

    $cpuLoadPercent = Get-SensorValue -Sensors $sensors -SensorType 'Load' -Name 'CPU Total'
    $clockValues = Get-SensorValuesByPattern -Sensors $sensors -SensorType 'Clock' -NamePattern 'CPU Core #*'
    if ($clockValues.Count -gt 0) {
        $effectiveClockMHz = [int][math]::Round((($clockValues | Measure-Object -Average).Average), 0)
    }

    $cpuFanRpm = Get-SensorValue -Sensors $sensors -SensorType 'Fan' -Name 'CPU Fan'
    $systemFan2Rpm = Get-SensorValue -Sensors $sensors -SensorType 'Fan' -Name 'System Fan #2'
    $systemFan3Rpm = Get-SensorValue -Sensors $sensors -SensorType 'Fan' -Name 'System Fan #3'
    $systemFan4Rpm = Get-SensorValue -Sensors $sensors -SensorType 'Fan' -Name 'System Fan #4'
```

- [ ] **Step 4: Run the hardware metrics tests again**

Run:

```powershell
pwsh -NoProfile -Command "Import-Module Pester -MinimumVersion 5.0; Invoke-Pester .\tests\FanControl.HardwareMetrics.Tests.ps1 -Output Detailed"
```

Expected: PASS with 5 passing tests.

- [ ] **Step 5: Commit the real sensor implementation**

Run:

```bash
git add scripts/current/hardware_metrics.ps1 tests/FanControl.HardwareMetrics.Tests.ps1
git commit -m "feat: read hardware metrics from libre hardware monitor"
```

Expected: one commit for the real sensor implementation with fallback-safe tests.

### Task 3: Integrate hardware metrics into monitor sampling output

**Files:**
- Modify: `D:\Y\others\fancontrol\scripts\current\monitor_simple.ps1`
- Modify: `D:\Y\others\fancontrol\tests\TestHelpers.ps1`
- Modify: `D:\Y\others\fancontrol\tests\FanControl.Monitor.Tests.ps1`

- [ ] **Step 1: Write the failing monitor tests for nested runtime and hardware output**

Update `tests/FanControl.Monitor.Tests.ps1`:

```powershell
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
            $snapshot = Get-Content -Path $files[0].FullName -Raw | ConvertFrom-Json

            $snapshot.Runtime.DesiredConfig | Should -Be 'Game.json'
            $snapshot.Runtime.EffectiveConfig | Should -Be 'Game.json'
            $snapshot.Hardware.CpuPackage | Should -Be 57.5
            $snapshot.Hardware.TotalFanRpm | Should -Be 610
            ($result.Output -join "`n") | Should -Match 'CPU:57.5C'
        } finally {
            Remove-FanControlTestSandbox -Sandbox $sandbox
        }
    }
```

Replace the sample-mode and invalid-cache assertions with:

```powershell
            $summary.Mode | Should -Be 'Sample'
            $summary.SampleCount | Should -Be 2
            @($summary.Samples).Count | Should -Be 2
            $summary.Samples[0].Runtime.DesiredConfig | Should -Be 'Game.json'
            $summary.Samples[0].Hardware.TotalFanRpm | Should -BeGreaterThan 0
```

```powershell
            $snapshot.Runtime.CacheReadable | Should -BeFalse
            $snapshot.Runtime.VerificationStatus | Should -Be 'Unknown'
            $snapshot.Runtime.StateConfidence | Should -Be 'Low'
            $snapshot.Hardware | Should -Not -BeNullOrEmpty
```

- [ ] **Step 2: Run the monitor tests and confirm they fail**

Run:

```powershell
pwsh -NoProfile -Command "Import-Module Pester -MinimumVersion 5.0; Invoke-Pester .\tests\FanControl.Monitor.Tests.ps1 -Output Detailed"
```

Expected: FAIL because `monitor_simple.ps1` still writes the old flat runtime-only schema.

- [ ] **Step 3: Copy the new helper into sandbox runs**

Update `tests/TestHelpers.ps1` by adding the new helper to the copied source list:

```powershell
    $sourceFiles = @(
        'auto_switch.ps1',
        'auto_switch_recovery.ps1',
        'config_switch_core.ps1',
        'runtime_paths.ps1',
        'runtime_state.ps1',
        'time_policy.ps1',
        'switch.ps1',
        'check_status.ps1',
        'monitor_simple.ps1',
        'hardware_metrics.ps1'
    )
```

- [ ] **Step 4: Implement nested sampling and summary output**

Update the import section in `scripts/current/monitor_simple.ps1`:

```powershell
$RuntimePathsHelper = Join-Path $PSScriptRoot "runtime_paths.ps1"
$RuntimeStateHelper = Join-Path $PSScriptRoot "runtime_state.ps1"
$HardwareMetricsHelper = Join-Path $PSScriptRoot "hardware_metrics.ps1"

foreach ($helper in @($RuntimePathsHelper, $RuntimeStateHelper, $HardwareMetricsHelper)) {
    if (Test-Path $helper) {
        . $helper
    } else {
        throw "Helper file not found: $helper"
    }
}
```

Add these helper functions above `Write-StateSummary`:

```powershell
function New-MonitorSample {
    $runtimeState = Get-FanControlRuntimeState
    $hardwareMetrics = Get-FanControlHardwareMetrics

    return [PSCustomObject]@{
        Timestamp = $runtimeState.Timestamp
        Runtime = $runtimeState
        Hardware = $hardwareMetrics
    }
}

function Format-RpmValue {
    param($Value)
    if ($null -eq $Value) { return 'NA' }
    return [int][math]::Round($Value, 0)
}
```

Replace `Write-StateSummary` with:

```powershell
function Write-StateSummary {
    param([Parameter(Mandatory = $true)]$Sample)

    $runtime = $Sample.Runtime
    $hardware = $Sample.Hardware
    $configText = if ($runtime.EffectiveConfig) { $runtime.EffectiveConfig } else { 'N/A' }

    Write-Host ("[{0}] Config:{1} CPU:{2}C CoreAvg:{3}C Dist:{4}C Load:{5}% Clock:{6}MHz Fans:{7}/{8}/{9}/{10} Total:{11}" -f `
        $Sample.Timestamp,
        $configText,
        $hardware.CpuPackage,
        $hardware.CoreAverage,
        $hardware.MinDistanceToTjMax,
        $hardware.CpuLoadPercent,
        (Format-RpmValue -Value $hardware.EffectiveClockMHz),
        (Format-RpmValue -Value $hardware.CpuFanRpm),
        (Format-RpmValue -Value $hardware.SystemFan2Rpm),
        (Format-RpmValue -Value $hardware.SystemFan3Rpm),
        (Format-RpmValue -Value $hardware.SystemFan4Rpm),
        (Format-RpmValue -Value $hardware.TotalFanRpm))
}
```

Then update each mode to use `New-MonitorSample` instead of `Get-FanControlRuntimeState`. For example, `Invoke-SnapshotMode` becomes:

```powershell
function Invoke-SnapshotMode {
    $sample = New-MonitorSample
    $path = Write-MonitorJson -Prefix 'snapshot' -Payload $sample
    Write-StateSummary -Sample $sample
    Write-Host "Saved: $(Split-Path $path -Leaf)"
}
```

Apply the same pattern in `Invoke-SampleMode` and `Invoke-WatchMode`.

- [ ] **Step 5: Run the monitor tests and then the full suite**

Run:

```powershell
pwsh -NoProfile -Command "Import-Module Pester -MinimumVersion 5.0; Invoke-Pester .\tests\FanControl.Monitor.Tests.ps1 -Output Detailed"
pwsh -NoProfile -File .\tests\Invoke-FanControlTests.ps1
```

Expected:

```text
tests/FanControl.Monitor.Tests.ps1 -> PASS
Invoke-FanControlTests.ps1 -> all tests pass
```

- [ ] **Step 6: Commit the monitor integration**

Run:

```bash
git add scripts/current/monitor_simple.ps1 tests/TestHelpers.ps1 tests/FanControl.Monitor.Tests.ps1
git commit -m "feat: include hardware metrics in monitor samples"
```

Expected: one commit for nested runtime/hardware samples and updated monitor coverage.

### Task 4: Verify resilience and live-read readiness

**Files:**
- Modify: `D:\Y\others\fancontrol\scripts\current\hardware_metrics.ps1`
- Modify: `D:\Y\others\fancontrol\tests\FanControl.HardwareMetrics.Tests.ps1`

- [ ] **Step 1: Add failing tests for library-path and counter-fallback resilience**

Append to `tests/FanControl.HardwareMetrics.Tests.ps1`:

```powershell
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
```

- [ ] **Step 2: Run the hardware metrics tests to make sure the new case fails if resilience regressed**

Run:

```powershell
pwsh -NoProfile -Command "Import-Module Pester -MinimumVersion 5.0; Invoke-Pester .\tests\FanControl.HardwareMetrics.Tests.ps1 -Output Detailed"
```

Expected: PASS if Task 2 already handled it; otherwise FAIL and fix before moving on.

- [ ] **Step 3: Make the live library load failure explicit and operator-friendly**

Update the top of `Get-LibreHardwareMonitorSensors` in `scripts/current/hardware_metrics.ps1`:

```powershell
    $paths = Get-FanControlPaths
    $libraryPath = Join-Path (Split-Path $paths.FanControlExe -Parent) 'LibreHardwareMonitorLib.dll'
    if (-not (Test-Path $libraryPath)) {
        throw "LibreHardwareMonitor library not found: $libraryPath"
    }

    if (-not ('LibreHardwareMonitor.Hardware.Computer' -as [type])) {
        Add-Type -Path $libraryPath
    }
```

This avoids duplicate loads and gives a clear failure when FanControl was moved or installed elsewhere.

- [ ] **Step 4: Run the full suite and one live snapshot**

Run:

```powershell
pwsh -NoProfile -File .\tests\Invoke-FanControlTests.ps1
pwsh -NoProfile -File .\scripts\current\monitor_simple.ps1 -Mode Snapshot
```

Expected:

```text
Invoke-FanControlTests.ps1 -> all tests pass
monitor_simple.ps1 -> prints CPU/CoreAvg/Dist/Load/Clock/Fans/Total summary and saves one snapshot JSON file
```

- [ ] **Step 5: Commit the resilience pass**

Run:

```bash
git add scripts/current/hardware_metrics.ps1 tests/FanControl.HardwareMetrics.Tests.ps1
git commit -m "test: harden hardware metrics fallback behavior"
```

Expected: one commit for the final resilience polish and verification coverage.

## Self-review

- **Spec coverage:** Task 1 establishes the shared hardware metrics helper contract and required fields. Task 2 implements real LibreHardwareMonitor traversal with counter fallbacks. Task 3 integrates runtime and hardware data into `monitor_simple.ps1` with nested JSON and operator-facing summaries. Task 4 hardens fallback and library loading behavior and ends with repo-wide plus live verification.
- **Placeholder scan:** No `TODO`, `TBD`, or deferred implementation markers remain. Every code-changing step includes concrete file paths, code, commands, and expected outcomes.
- **Type consistency:** The plan consistently uses `Get-FanControlHardwareMetrics`, `Runtime`, `Hardware`, `CpuPackage`, `CoreAverage`, `MinDistanceToTjMax`, `CpuLoadPercent`, `EffectiveClockMHz`, `TotalFanRpm`, and `DataConfidence` across helper, monitor, and test tasks.
