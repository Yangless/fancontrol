$ErrorActionPreference = "Stop"

$scriptsRoot = Split-Path -Parent $PSScriptRoot
$helperPath = Join-Path $scriptsRoot "current\\auto_switch_recovery.ps1"

if (-not (Test-Path $helperPath)) {
    Write-Host "FAIL: helper file not found: $helperPath" -ForegroundColor Red
    exit 1
}

. $helperPath

if (-not (Get-Command Invoke-ConfigSwitchWithRetry -ErrorAction SilentlyContinue)) {
    Write-Host "FAIL: Invoke-ConfigSwitchWithRetry is not defined." -ForegroundColor Red
    exit 1
}

$script:runCalls = 0
$script:verifyCalls = 0
$coldStartResult = Invoke-ConfigSwitchWithRetry `
    -ProcessWasRunning:$false `
    -RunSwitchCommand {
        $script:runCalls++
    } `
    -VerifySwitch {
        $script:verifyCalls++
        return ($script:verifyCalls -ge 2)
    }

if (-not $coldStartResult) {
    Write-Host "FAIL: cold-start retry path did not eventually verify." -ForegroundColor Red
    exit 1
}

if ($script:runCalls -ne 2 -or $script:verifyCalls -ne 2) {
    Write-Host "FAIL: cold-start retry path expected 2 switch attempts and 2 verifications, got run=$script:runCalls verify=$script:verifyCalls." -ForegroundColor Red
    exit 1
}

$script:runCalls = 0
$script:verifyCalls = 0
$warmStartResult = Invoke-ConfigSwitchWithRetry `
    -ProcessWasRunning:$true `
    -RunSwitchCommand {
        $script:runCalls++
    } `
    -VerifySwitch {
        $script:verifyCalls++
        return $false
    }

if ($warmStartResult) {
    Write-Host "FAIL: warm-start path should not report success when verification fails." -ForegroundColor Red
    exit 1
}

if ($script:runCalls -ne 1 -or $script:verifyCalls -ne 1) {
    Write-Host "FAIL: warm-start path should not retry, got run=$script:runCalls verify=$script:verifyCalls." -ForegroundColor Red
    exit 1
}

Write-Host "PASS: cold-start retry helper behaves as expected." -ForegroundColor Green
exit 0
