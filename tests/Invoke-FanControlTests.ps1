Import-Module Pester -ErrorAction Stop

$result = Invoke-Pester -Path $PSScriptRoot -PassThru

if ($result.FailedCount -gt 0) {
    exit 1
}

exit 0
