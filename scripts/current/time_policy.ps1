$script:FanControlSchedule = @(
    [PSCustomObject]@{
        Start = 0
        End = 480
        Config = 'Quiet_mode.json'
        Force = $false
        Label = 'NightQuiet'
    },
    [PSCustomObject]@{
        Start = 480
        End = 760
        Config = 'Game.json'
        Force = $false
        Label = 'MorningGame'
    },
    [PSCustomObject]@{
        Start = 760
        End = 840
        Config = 'Quiet_mode.json'
        Force = $true
        Label = 'LunchQuiet'
    },
    [PSCustomObject]@{
        Start = 840
        End = 1260
        Config = 'Game.json'
        Force = $false
        Label = 'AfternoonGame'
    },
    [PSCustomObject]@{
        Start = 1260
        End = 1440
        Config = 'Quiet_mode.json'
        Force = $true
        Label = 'EveningQuiet'
    }
)

function Get-MinuteOfDay {
    param(
        [datetime]$Date = (Get-Date)
    )

    if ($env:FANCONTROL_TEST_MINUTE) {
        return [int]$env:FANCONTROL_TEST_MINUTE
    }

    return ($Date.Hour * 60 + $Date.Minute)
}

function Get-TimePolicyWindow {
    param(
        [int]$Minute
    )

    $normalizedMinute = (($Minute % 1440) + 1440) % 1440
    $window = $script:FanControlSchedule | Where-Object {
        $normalizedMinute -ge $_.Start -and $normalizedMinute -lt $_.End
    } | Select-Object -First 1

    if (-not $window) {
        throw "No time policy window defined for minute $normalizedMinute."
    }

    return $window
}

function Get-ConfigNameForMinute {
    param(
        [int]$Minute
    )

    return (Get-TimePolicyWindow -Minute $Minute).Config
}

function Test-IsForcePointMinute {
    param(
        [int]$Minute
    )

    $normalizedMinute = (($Minute % 1440) + 1440) % 1440
    return @($script:FanControlSchedule | Where-Object { $_.Force -and $_.Start -eq $normalizedMinute }).Count -gt 0
}

function Test-IsQuietExitPointMinute {
    param(
        [int]$Minute
    )

    $normalizedMinute = (($Minute % 1440) + 1440) % 1440

    for ($index = 0; $index -lt $script:FanControlSchedule.Count; $index++) {
        $currentWindow = $script:FanControlSchedule[$index]
        if ($currentWindow.Start -ne $normalizedMinute) {
            continue
        }

        $previousIndex = if ($index -eq 0) {
            $script:FanControlSchedule.Count - 1
        } else {
            $index - 1
        }

        $previousWindow = $script:FanControlSchedule[$previousIndex]
        return ($previousWindow.Config -eq 'Quiet_mode.json' -and $currentWindow.Config -eq 'Game.json')
    }

    return $false
}
