function Invoke-ConfigSwitchWithRetry {
    param(
        [scriptblock]$RunSwitchCommand,
        [scriptblock]$VerifySwitch,
        [bool]$ProcessWasRunning,
        [scriptblock]$OnRetry = {}
    )

    & $RunSwitchCommand
    $verified = & $VerifySwitch

    if (-not $verified -and -not $ProcessWasRunning) {
        & $OnRetry
        & $RunSwitchCommand
        $verified = & $VerifySwitch
    }

    return $verified
}
