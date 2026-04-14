$pesterModule = Get-Module -ListAvailable Pester |
    Where-Object { $_.Version.Major -eq 5 } |
    Sort-Object Version -Descending |
    Select-Object -First 1

if (-not $pesterModule) {
    $documentsDir = [Environment]::GetFolderPath('MyDocuments')
    $candidatePaths = @(
        (Join-Path $documentsDir 'PowerShell\Modules\Pester'),
        (Join-Path $documentsDir 'WindowsPowerShell\Modules\Pester')
    )

    $pesterModule = $candidatePaths |
        Where-Object { Test-Path $_ } |
        ForEach-Object {
            Get-ChildItem $_ -Directory -ErrorAction SilentlyContinue
        } |
        Sort-Object { [version]$_.Name } -Descending |
        ForEach-Object {
            $manifestPath = Join-Path $_.FullName 'Pester.psd1'
            if (Test-Path $manifestPath) {
                [PSCustomObject]@{
                    Version = [version]$_.Name
                    Path = $manifestPath
                }
            }
        } |
        Where-Object { $_.Version.Major -eq 5 } |
        Select-Object -First 1
}

if (-not $pesterModule) {
    throw 'Pester 5.x is required to run this test suite.'
}

Import-Module $pesterModule.Path -Force -ErrorAction Stop

$configuration = [PesterConfiguration]::Default
$configuration.Run.Path = $PSScriptRoot
$configuration.Run.PassThru = $true
$configuration.Output.Verbosity = 'Detailed'

$result = Invoke-Pester -Configuration $configuration

if ($result.FailedCount -gt 0) {
    exit 1
}

exit 0
