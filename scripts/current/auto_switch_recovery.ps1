function Test-ConfigSwitchVerificationPassed {
    param(
        $VerificationResult
    )

    if ($null -eq $VerificationResult) {
        return $false
    }

    if ($VerificationResult -is [bool]) {
        return $VerificationResult
    }

    if ($VerificationResult.PSObject.Properties['Verified']) {
        return [bool]$VerificationResult.Verified
    }

    return [bool]$VerificationResult
}

function Invoke-ConfigSwitchWithRetry {
    param(
        [scriptblock]$RunSwitchCommand,
        [scriptblock]$VerifySwitch,
        [bool]$ProcessWasRunning,
        [scriptblock]$OnRetry = {}
    )

    & $RunSwitchCommand
    $verificationResult = & $VerifySwitch
    $verified = Test-ConfigSwitchVerificationPassed -VerificationResult $verificationResult

    if (-not $verified -and -not $ProcessWasRunning) {
        & $OnRetry
        & $RunSwitchCommand
        $verificationResult = & $VerifySwitch
    }

    return $verificationResult
}
