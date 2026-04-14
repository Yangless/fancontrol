$ErrorActionPreference = "Stop"

$scriptsRoot = Split-Path -Parent $PSScriptRoot
$switchPath = Join-Path $scriptsRoot "current\\switch.ps1"

if (-not (Test-Path $switchPath)) {
    Write-Error "switch.ps1 not found: $switchPath"
}

$content = Get-Content $switchPath -Raw
$branchMatch = [regex]::Match(
    $content,
    'if \(\$Mode -eq "auto"\) \{(?s:(.*?))^\}',
    [System.Text.RegularExpressions.RegexOptions]::Multiline
)

if (-not $branchMatch.Success) {
    Write-Error "Could not locate the auto mode branch in switch.ps1"
}

$autoBranch = $branchMatch.Groups[1].Value

if ($autoBranch -match '& "C:\\FanControl_Auto\\auto_switch\.ps1" -Force') {
    Write-Host "FAIL: auto mode still invokes auto_switch.ps1 with -Force." -ForegroundColor Red
    Write-Host "Expected: auto mode should clear override and calibrate to the current time period." -ForegroundColor Yellow
    exit 1
}

if ($autoBranch -notmatch '& "C:\\FanControl_Auto\\auto_switch\.ps1"(?:\s|$)') {
    Write-Host "FAIL: auto mode does not invoke auto_switch.ps1 at all." -ForegroundColor Red
    exit 1
}

Write-Host "PASS: auto mode calibrates without the force-quiet path." -ForegroundColor Green
exit 0
