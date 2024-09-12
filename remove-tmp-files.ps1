param(
    [string[]] $Target = @($pwd),
    [switch] $Recursive = $false
)

# Find ABB files in target directories
$ProjectFiles = Get-ChildItem -Path $Target -File -Recurse:$Recursive | Where-Object { $_.Name -match ".+\.project(?:archive)?$" }
$ProjectDirs = $ProjectFiles | ForEach-Object { $_.DirectoryName } | Get-Unique

foreach ($ProjectDir in $ProjectDirs) {

    # Find temporary files in each projectdirectory
    $TmpFiles = Get-ChildItem -Path $ProjectDir | Where-Object { $_.Name -match "^(?:DEFAULT\.DFR|.+\.(?:opt|backup|lock|~u))$" }
    if ($TmpFiles) {
        Write-Host $ProjectDir -ForegroundColor "White"

        # Try to delete each file
        foreach ($TmpFile in $TmpFiles) {
            Write-Host "`t${TmpFile}"
            Remove-Item -Path (Join-Path $ProjectDir $TmpFile)
        }
    }
}
