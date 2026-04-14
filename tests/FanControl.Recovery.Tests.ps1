$repoRoot = Split-Path -Parent $PSScriptRoot
$helperPath = Join-Path $repoRoot 'scripts\current\auto_switch_recovery.ps1'

. $helperPath

Describe 'Cold-start recovery helper' {
    It 'retries once after an initial verification failure on cold start' {
        $script:runCalls = 0
        $script:verifyCalls = 0

        $result = Invoke-ConfigSwitchWithRetry `
            -ProcessWasRunning:$false `
            -RunSwitchCommand { $script:runCalls++ } `
            -VerifySwitch {
                $script:verifyCalls++
                return ($script:verifyCalls -ge 2)
            }

        $result | Should Be $true
        $script:runCalls | Should Be 2
        $script:verifyCalls | Should Be 2
    }

    It 'does not retry after a failed verification when the process was already running' {
        $script:runCalls = 0
        $script:verifyCalls = 0

        $result = Invoke-ConfigSwitchWithRetry `
            -ProcessWasRunning:$true `
            -RunSwitchCommand { $script:runCalls++ } `
            -VerifySwitch {
                $script:verifyCalls++
                return $false
            }

        $result | Should Be $false
        $script:runCalls | Should Be 1
        $script:verifyCalls | Should Be 1
    }
}
