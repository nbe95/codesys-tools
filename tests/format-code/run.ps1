Remove-Item -Recurse -Force "$PSScriptRoot\tmp"
Copy-Item -Recurse -Path "$PSScriptRoot\input" -Destination "$PSScriptRoot\tmp"

$Files = Get-ChildItem -Path "$PSScriptRoot\tmp" -Filter "*.exp" -Recurse
$Data = $Files | ForEach-Object {
    @{ File = $_.FullName }
}

$Container = New-PesterContainer -Path "./formatter.tests.ps1" -Data $Data
Invoke-Pester -Container $Container -Output Detailed
