Describe 'config_switch_core.ps1 behavior' {
    BeforeAll {
        . (Join-Path $PSScriptRoot 'TestHelpers.ps1')
        $repoRoot = Split-Path -Parent $PSScriptRoot
        $script:SwitchCorePath = Join-Path $repoRoot 'scripts\current\config_switch_core.ps1'
    }

    function script:Invoke-SwitchCoreInSandbox {
        param(
            [Parameter(Mandatory = $true)]$Sandbox,
            [Parameter(Mandatory = $true)][string]$Expression,
            [hashtable]$Environment = @{}
        )

        $scriptPath = Join-Path $Sandbox.Root 'invoke-switch-core.ps1'
        $scriptContent = @"
. '$($Sandbox.RuntimeDir)\runtime_paths.ps1'
. '$($Sandbox.RuntimeDir)\time_policy.ps1'
. '$($Sandbox.RuntimeDir)\runtime_state.ps1'
. '$($Sandbox.RuntimeDir)\auto_switch_recovery.ps1'
. '$($Sandbox.RuntimeDir)\config_switch_core.ps1'
$Expression
"@
        Set-Content -Path $scriptPath -Value $scriptContent -Encoding UTF8

        return Invoke-PowerShellScript `
            -ScriptPath $scriptPath `
            -Environment (Get-SandboxEnvironment -Sandbox $Sandbox -Values $Environment)
    }

    It 'has a shared switch core helper' {
        (Test-Path $SwitchCorePath) | Should -BeTrue
    }

    It 'auto calibration chooses the same daytime target as auto_switch' {
        $sandbox = New-FanControlTestSandbox
        try {
            $result = Invoke-SwitchCoreInSandbox `
                -Sandbox $sandbox `
                -Expression @'
$result = Invoke-AutoCalibrationSwitch -ProcessWasRunning:$false
$result.TargetConfigName | Write-Output
'@ `
                -Environment @{
                    FANCONTROL_TEST_MINUTE = '480'
                    FANCONTROL_TEST_PROCESS_RUNNING = 'False'
                }

            $result.ExitCode | Should -Be 0
            ($result.Output -join "`n") | Should -Match 'Game\.json'
        } finally {
            Remove-FanControlTestSandbox -Sandbox $sandbox
        }
    }
}
