Describe 'FanControl time policy' {
    BeforeAll {
        $repoRoot = Split-Path -Parent $PSScriptRoot
        $helperPath = Join-Path $repoRoot 'scripts\current\time_policy.ps1'

        if (Test-Path $helperPath) {
            . $helperPath
        }
    }

    It 'has a shared time policy helper' {
        (Test-Path $helperPath) | Should -BeTrue
    }

    It 'maps minute-of-day boundaries to the expected config' {
        $cases = @(
            @{ Minute = 0; Expected = 'Quiet_mode.json' }
            @{ Minute = 479; Expected = 'Quiet_mode.json' }
            @{ Minute = 480; Expected = 'Game.json' }
            @{ Minute = 759; Expected = 'Game.json' }
            @{ Minute = 760; Expected = 'Quiet_mode.json' }
            @{ Minute = 839; Expected = 'Quiet_mode.json' }
            @{ Minute = 840; Expected = 'Game.json' }
            @{ Minute = 1259; Expected = 'Game.json' }
            @{ Minute = 1260; Expected = 'Quiet_mode.json' }
            @{ Minute = 1439; Expected = 'Quiet_mode.json' }
        )

        foreach ($case in $cases) {
            (Get-ConfigNameForMinute -Minute $case.Minute) | Should -Be $case.Expected
        }
    }

    It 'treats only exact force-point minutes as force points' {
        (Test-IsForcePointMinute -Minute 759) | Should -BeFalse
        (Test-IsForcePointMinute -Minute 760) | Should -BeTrue
        (Test-IsForcePointMinute -Minute 761) | Should -BeFalse
        (Test-IsForcePointMinute -Minute 1259) | Should -BeFalse
        (Test-IsForcePointMinute -Minute 1260) | Should -BeTrue
        (Test-IsForcePointMinute -Minute 1261) | Should -BeFalse
    }
}
