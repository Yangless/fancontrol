Describe 'FanControl time policy data model' {
    BeforeAll {
        $repoRoot = Split-Path -Parent $PSScriptRoot
        $helperPath = Join-Path $repoRoot 'scripts\current\time_policy.ps1'

        if (Test-Path $helperPath) {
            . $helperPath
        }
    }

    It 'returns an inspectable schedule window for a force minute' {
        $window = Get-TimePolicyWindow -Minute 760

        $window.Label | Should -Be 'LunchQuiet'
        $window.Config | Should -Be 'Quiet_mode.json'
        $window.Force | Should -BeTrue
        $window.Start | Should -Be 760
        $window.End | Should -Be 840
    }

    It 'derives quiet exit points from the schedule table' {
        (Test-IsQuietExitPointMinute -Minute 479) | Should -BeFalse
        (Test-IsQuietExitPointMinute -Minute 480) | Should -BeTrue
        (Test-IsQuietExitPointMinute -Minute 481) | Should -BeFalse
        (Test-IsQuietExitPointMinute -Minute 839) | Should -BeFalse
        (Test-IsQuietExitPointMinute -Minute 840) | Should -BeTrue
        (Test-IsQuietExitPointMinute -Minute 841) | Should -BeFalse
    }
}
