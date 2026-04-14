function Get-MinuteOfDay {
    param(
        [datetime]$Date = (Get-Date)
    )

    return ($Date.Hour * 60 + $Date.Minute)
}

function Get-ConfigNameForMinute {
    param(
        [int]$Minute
    )

    if (($Minute -ge 760 -and $Minute -lt 840) -or ($Minute -ge 1260) -or ($Minute -lt 480)) {
        return "Quiet_mode.json"
    }

    return "Game.json"
}

function Test-IsForcePointMinute {
    param(
        [int]$Minute
    )

    return ($Minute -eq 760 -or $Minute -eq 1260)
}

function Test-IsQuietExitPointMinute {
    param(
        [int]$Minute
    )

    return ($Minute -eq 480 -or $Minute -eq 840)
}
