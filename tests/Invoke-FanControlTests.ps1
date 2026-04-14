$pesterModule = Get-Module -ListAvailable Pester |
    Where-Object { $_.Version.Major -lt 5 } |
    Sort-Object Version -Descending |
    Select-Object -First 1

if (-not $pesterModule) {
    throw 'Pester 4.x is required to run this test suite.'
}

Import-Module $pesterModule.Path -Force -ErrorAction Stop

$result = Invoke-Pester -Path $PSScriptRoot -PassThru

if ($result.FailedCount -gt 0) {
    exit 1
}

exit 0
