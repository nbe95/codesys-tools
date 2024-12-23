Remove-Item -Recurse -Path "$PSScriptRoot\tmp" -ErrorAction SilentlyContinue
New-Item -Type Directory -Path "$PSScriptRoot\tmp" | Out-Null

$Files = Get-ChildItem -Path "$PSScriptRoot\input" -Filter "*.exp" -Recurse
$Data = $Files | Sort-Object | ForEach-Object {
    @{ File = $_.FullName }
}

$Container = New-PesterContainer -Path "$PSScriptRoot\formatter.tests.ps1" -Data $Data
Invoke-Pester -Container $Container -Output Detailed
