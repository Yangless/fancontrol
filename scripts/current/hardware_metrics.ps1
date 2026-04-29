$RuntimePathsHelper = Join-Path $PSScriptRoot "runtime_paths.ps1"
if (Test-Path $RuntimePathsHelper) {
    . $RuntimePathsHelper
} else {
    throw "Helper file not found: $RuntimePathsHelper"
}

function Get-FallbackCounterValue {
    param(
        [Parameter(Mandatory = $true)][string]$CounterPath,
        [Parameter(Mandatory = $true)][string]$EnvironmentName
    )

    $environmentValue = [Environment]::GetEnvironmentVariable($EnvironmentName, 'Process')
    if ($environmentValue) {
        return [double]$environmentValue
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

function Get-RoundedClockMHz {
    param($Values)

    if (-not $Values -or $Values.Count -eq 0) {
        return $null
    }

    return [int][math]::Round((($Values | Measure-Object -Average).Average), 0)
}

function Get-SensorMatches {
    param(
        [Parameter(Mandatory = $true)]$Sensors,
        [Parameter(Mandatory = $true)][string]$SensorType,
        [string[]]$ExactNames = @(),
        [string[]]$NamePatterns = @()
    )

    return @(
        $Sensors |
            Where-Object {
                if ($_.SensorType -ne $SensorType) {
                    return $false
                }

                if ($ExactNames -contains $_.Name) {
                    return $true
                }

                foreach ($pattern in $NamePatterns) {
                    if ($_.Name -like $pattern) {
                        return $true
                    }
                }

                return $false
            }
    )
}

function Get-FirstSensorValue {
    param(
        [Parameter(Mandatory = $true)]$Sensors,
        [Parameter(Mandatory = $true)][string]$SensorType,
        [string[]]$ExactNames = @(),
        [string[]]$NamePatterns = @()
    )

    $match = Get-SensorMatches -Sensors $Sensors -SensorType $SensorType -ExactNames $ExactNames -NamePatterns $NamePatterns | Select-Object -First 1
    if ($match) {
        return [double]$match.Value
    }

    return $null
}

function Get-SensorNumericValues {
    param(
        [Parameter(Mandatory = $true)]$Sensors,
        [Parameter(Mandatory = $true)][string]$SensorType,
        [string[]]$ExactNames = @(),
        [string[]]$NamePatterns = @()
    )

    return @(Get-SensorMatches -Sensors $Sensors -SensorType $SensorType -ExactNames $ExactNames -NamePatterns $NamePatterns | ForEach-Object { [double]$_.Value })
}

function Get-FixturePropertyValue {
    param(
        [Parameter(Mandatory = $true)]$InputObject,
        [Parameter(Mandatory = $true)][string]$Name
    )

    if ($InputObject -is [System.Collections.IDictionary]) {
        if ($InputObject.Contains($Name)) {
            return $InputObject[$Name]
        }

        return $null
    }

    $property = $InputObject.PSObject.Properties[$Name]
    if ($property) {
        return $property.Value
    }

    return $null
}

function Get-FixtureNamedEntries {
    param($InputObject)

    if ($null -eq $InputObject) {
        return @()
    }

    if ($InputObject -is [System.Collections.IDictionary]) {
        return @($InputObject.GetEnumerator())
    }

    return @(
        $InputObject.PSObject.Properties |
            Where-Object { $_.MemberType -eq 'NoteProperty' } |
            ForEach-Object {
                [PSCustomObject]@{
                    Key = $_.Name
                    Value = $_.Value
                }
            }
    )
}

function Get-LibreHardwareMonitorSensors {
    if ($env:FANCONTROL_TEST_HARDWARE_SNAPSHOT) {
        $fixture = $env:FANCONTROL_TEST_HARDWARE_SNAPSHOT | ConvertFrom-Json
        $fixtureSensors = Get-FixturePropertyValue -InputObject $fixture -Name 'Sensors'
        if ($null -ne $fixtureSensors) {
            return @($fixtureSensors)
        }

        $temperatures = Get-FixturePropertyValue -InputObject $fixture -Name 'Temperatures'
        $loads = Get-FixturePropertyValue -InputObject $fixture -Name 'Loads'
        $clocks = Get-FixturePropertyValue -InputObject $fixture -Name 'Clocks'
        $fans = Get-FixturePropertyValue -InputObject $fixture -Name 'Fans'

        $sensors = @()
        foreach ($entry in Get-FixtureNamedEntries -InputObject $temperatures) {
            $sensors += [PSCustomObject]@{ SensorType = 'Temperature'; Name = $entry.Key; Value = [double]$entry.Value }
        }
        foreach ($entry in Get-FixtureNamedEntries -InputObject $loads) {
            $sensors += [PSCustomObject]@{ SensorType = 'Load'; Name = $entry.Key; Value = [double]$entry.Value }
        }
        foreach ($entry in Get-FixtureNamedEntries -InputObject $clocks) {
            $sensors += [PSCustomObject]@{ SensorType = 'Clock'; Name = $entry.Key; Value = [double]$entry.Value }
        }
        foreach ($entry in Get-FixtureNamedEntries -InputObject $fans) {
            $sensors += [PSCustomObject]@{ SensorType = 'Fan'; Name = $entry.Key; Value = [double]$entry.Value }
        }

        return $sensors
    }

    $paths = Get-FanControlPaths
    $libraryPath = Join-Path (Split-Path $paths.FanControlExe -Parent) 'LibreHardwareMonitorLib.dll'
    if (-not (Test-Path $libraryPath)) {
        throw "LibreHardwareMonitor library not found: $libraryPath"
    }

    if (-not ('LibreHardwareMonitor.Hardware.Computer' -as [type])) {
        try {
            Add-Type -Path $libraryPath -ErrorAction Stop
        } catch {
            throw "Failed to load LibreHardwareMonitor library from $libraryPath. $($_.Exception.Message)"
        }
    }

    if (-not ('LibreHardwareMonitor.Hardware.Computer' -as [type])) {
        throw "LibreHardwareMonitor library loaded but type LibreHardwareMonitor.Hardware.Computer is unavailable: $libraryPath"
    }

    $computer = [LibreHardwareMonitor.Hardware.Computer]::new()
    try {
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
    } finally {
        if ($null -ne $computer) {
            $computer.Close()
            if ($computer -is [System.IDisposable]) {
                $computer.Dispose()
            }
        }
    }
}

function Get-DataConfidence {
    param(
        $CpuPackage,
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

    $rpmValues = @($CpuFanRpm, $SystemFan2Rpm, $SystemFan3Rpm, $SystemFan4Rpm)
    $nonNullRpmCount = @($rpmValues | Where-Object { $null -ne $_ }).Count
    if ($UsedFallbackCounters -or $nonNullRpmCount -lt $rpmValues.Count -or $null -eq $CpuLoadPercent -or $null -eq $EffectiveClockMHz) {
        return 'Medium'
    }

    return 'High'
}

function Get-FanControlHardwareMetrics {
    $sensors = Get-LibreHardwareMonitorSensors
    $usedFallbackCounters = $false

    $cpuPackage = Get-FirstSensorValue -Sensors $sensors -SensorType 'Temperature' -ExactNames @('CPU Package') -NamePatterns @('CPU Package*')
    $coreAverage = Get-FirstSensorValue -Sensors $sensors -SensorType 'Temperature' -ExactNames @('Core Average') -NamePatterns @('Core Average*', '*Core Average*')

    $minDistanceToTjMax = $null
    $distanceValues = Get-SensorNumericValues -Sensors $sensors -SensorType 'Temperature' -NamePatterns @('*Distance to TjMax*')
    if ($distanceValues.Count -gt 0) {
        $minDistanceToTjMax = ($distanceValues | Measure-Object -Minimum).Minimum
    }

    $cpuLoadPercent = Get-FirstSensorValue -Sensors $sensors -SensorType 'Load' -ExactNames @('CPU Total') -NamePatterns @('CPU Total*', '*CPU Total*')
    $cpuTotalLoad = $cpuLoadPercent
    $cpuCoreLoads = Get-SensorNumericValues -Sensors $sensors -SensorType 'Load' -NamePatterns @('CPU Core #*', 'P-Core #*', 'E-Core #*')
    $cpuCoreMaxLoad = if ($cpuCoreLoads.Count -gt 0) {
        [math]::Round((($cpuCoreLoads | Measure-Object -Maximum).Maximum), 1)
    } else {
        $null
    }

    $clockValues = Get-SensorNumericValues -Sensors $sensors -SensorType 'Clock' -NamePatterns @('CPU Core #*')
    $cpuClockAverageMHz = Get-AverageValue -Values $clockValues
    $pCoreClockAverageMHz = Get-AverageValue -Values (Get-SensorNumericValues -Sensors $sensors -SensorType 'Clock' -NamePatterns @('P-Core #*'))
    $eCoreClockAverageMHz = Get-AverageValue -Values (Get-SensorNumericValues -Sensors $sensors -SensorType 'Clock' -NamePatterns @('E-Core #*'))
    $effectiveClockMHz = $null
    if ($clockValues.Count -gt 0) {
        $effectiveClockMHz = Get-RoundedClockMHz -Values $clockValues
    }

    $cpuPackagePowerW = Get-FirstSensorValue -Sensors $sensors -SensorType 'Power' -ExactNames @('CPU Package') -NamePatterns @('CPU Package*', 'Package*')
    $systemTemp = Get-FirstSensorValue -Sensors $sensors -SensorType 'Temperature' -ExactNames @('System') -NamePatterns @('System*')
    $vrmMosTemp = Get-FirstSensorValue -Sensors $sensors -SensorType 'Temperature' -ExactNames @('VRM MOS') -NamePatterns @('VRM MOS*')
    $pchTemp = Get-FirstSensorValue -Sensors $sensors -SensorType 'Temperature' -ExactNames @('PCH') -NamePatterns @('PCH*')
    $gpuTemp = Get-FirstSensorValue -Sensors $sensors -SensorType 'Temperature' -ExactNames @('GPU', 'GPU Core') -NamePatterns @('GPU Core*', 'GPU Temperature*', 'GPU*')
    $gpu3DUtil = Get-FirstSensorValue -Sensors $sensors -SensorType 'Load' -ExactNames @('GPU Core', 'GPU 3D') -NamePatterns @('GPU 3D*', 'GPU D3D 3D*', 'GPU D3D*', 'GPU Core*')

    $cpuFanRpm = Get-FirstSensorValue -Sensors $sensors -SensorType 'Fan' -ExactNames @('CPU Fan') -NamePatterns @('CPU Fan*')
    $systemFan2Rpm = Get-FirstSensorValue -Sensors $sensors -SensorType 'Fan' -ExactNames @('System Fan #2') -NamePatterns @('System Fan #2*')
    $systemFan3Rpm = Get-FirstSensorValue -Sensors $sensors -SensorType 'Fan' -ExactNames @('System Fan #3') -NamePatterns @('System Fan #3*')
    $systemFan4Rpm = Get-FirstSensorValue -Sensors $sensors -SensorType 'Fan' -ExactNames @('System Fan #4') -NamePatterns @('System Fan #4*')
    $gpuFan1Rpm = Get-FirstSensorValue -Sensors $sensors -SensorType 'Fan' -ExactNames @('GPU Fan 1', 'GPU Fan #1') -NamePatterns @('GPU Fan 1*', 'GPU Fan #1*', 'GPU #1*')
    $gpuFan2Rpm = Get-FirstSensorValue -Sensors $sensors -SensorType 'Fan' -ExactNames @('GPU Fan 2', 'GPU Fan #2') -NamePatterns @('GPU Fan 2*', 'GPU Fan #2*', 'GPU #2*')

    if ($null -eq $cpuLoadPercent) {
        $cpuLoadPercent = [math]::Round((Get-FallbackCounterValue -CounterPath '\Processor Information(_Total)\% Processor Utility' -EnvironmentName 'FANCONTROL_TEST_COUNTER_PROCESSOR_UTILITY'), 1)
        $cpuTotalLoad = $cpuLoadPercent
        $usedFallbackCounters = $true
    }

    if ($null -eq $effectiveClockMHz) {
        $effectiveClockMHz = [int][math]::Round((Get-FallbackCounterValue -CounterPath '\Processor Information(_Total)\Processor Frequency' -EnvironmentName 'FANCONTROL_TEST_COUNTER_PROCESSOR_FREQUENCY'), 0)
        if ($null -eq $cpuClockAverageMHz) {
            $cpuClockAverageMHz = [double]$effectiveClockMHz
        }
        $usedFallbackCounters = $true
    }

    $totalCaseFanRpm = @($systemFan2Rpm, $systemFan3Rpm, $systemFan4Rpm) |
        Where-Object { $null -ne $_ } |
        Measure-Object -Sum |
        Select-Object -ExpandProperty Sum

    $totalFanRpm = @($cpuFanRpm, $systemFan2Rpm, $systemFan3Rpm, $systemFan4Rpm) |
        Where-Object { $null -ne $_ } |
        Measure-Object -Sum |
        Select-Object -ExpandProperty Sum

    [PSCustomObject]@{
        CpuPackage = $cpuPackage
        CoreAverage = $coreAverage
        MinDistanceToTjMax = $minDistanceToTjMax
        CpuLoadPercent = $cpuLoadPercent
        CpuTotalLoad = $cpuTotalLoad
        CpuCoreMaxLoad = $cpuCoreMaxLoad
        EffectiveClockMHz = $effectiveClockMHz
        CpuClockAverageMHz = $cpuClockAverageMHz
        PCoreClockAverageMHz = $pCoreClockAverageMHz
        ECoreClockAverageMHz = $eCoreClockAverageMHz
        CpuPackagePowerW = $cpuPackagePowerW
        SystemTemp = $systemTemp
        VrmMosTemp = $vrmMosTemp
        PchTemp = $pchTemp
        GpuTemp = $gpuTemp
        Gpu3DUtil = $gpu3DUtil
        CpuFanRpm = $cpuFanRpm
        SystemFan2Rpm = $systemFan2Rpm
        SystemFan3Rpm = $systemFan3Rpm
        SystemFan4Rpm = $systemFan4Rpm
        GpuFan1Rpm = $gpuFan1Rpm
        GpuFan2Rpm = $gpuFan2Rpm
        TotalCaseFanRpm = $totalCaseFanRpm
        TotalFanRpm = $totalFanRpm
        TotalTrackedFanRpm = $totalFanRpm
        DataConfidence = Get-DataConfidence `
            -CpuPackage $cpuPackage `
            -CpuLoadPercent $cpuLoadPercent `
            -EffectiveClockMHz $effectiveClockMHz `
            -CpuFanRpm $cpuFanRpm `
            -SystemFan2Rpm $systemFan2Rpm `
            -SystemFan3Rpm $systemFan3Rpm `
            -SystemFan4Rpm $systemFan4Rpm `
            -UsedFallbackCounters:$usedFallbackCounters
    }
}
