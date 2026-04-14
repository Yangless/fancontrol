$repoRoot = Split-Path -Parent $PSScriptRoot
$autoSwitchPath = Join-Path $repoRoot 'scripts\current\auto_switch.ps1'
$checkStatusPath = Join-Path $repoRoot 'scripts\current\check_status.ps1'
$monitorPath = Join-Path $repoRoot 'scripts\current\monitor_simple.ps1'
$switchPath = Join-Path $repoRoot 'scripts\current\switch.ps1'

$autoSwitchContent = Get-Content $autoSwitchPath -Raw
$checkStatusContent = Get-Content $checkStatusPath -Raw
$monitorContent = Get-Content $monitorPath -Raw
$switchContent = Get-Content $switchPath -Raw

Describe 'Script consistency' {
    It 'loads the shared time policy helper in auto_switch.ps1' {
        $autoSwitchContent | Should Match 'time_policy\.ps1'
    }

    It 'loads the shared time policy helper in check_status.ps1' {
        $checkStatusContent | Should Match 'time_policy\.ps1'
    }

    It 'loads the shared time policy helper in monitor_simple.ps1' {
        $monitorContent | Should Match 'time_policy\.ps1'
    }

    It 'does not use -Force when restoring auto mode in switch.ps1' {
        $switchContent | Should Not Match 'auto_switch\.ps1" -Force'
    }
}
