$repoRoot = Split-Path -Parent $PSScriptRoot
$scriptPath = Join-Path $repoRoot 'scripts\current\fix_startup_logon.ps1'
$content = Get-Content $scriptPath -Raw

Describe 'fix_startup_logon.ps1 static configuration' {
    It 'uses a logon trigger instead of a boot trigger' {
        $content | Should Match 'New-ScheduledTaskTrigger -AtLogOn'
        $content | Should Not Match 'BootTrigger'
    }

    It 'keeps the startup delay at 30 seconds' {
        $content | Should Match 'PT30S'
    }

    It 'registers the live runtime auto_switch path' {
        $content | Should Match 'C:\\FanControl_Auto\\auto_switch\.ps1'
    }
}
