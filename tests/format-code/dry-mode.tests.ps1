BeforeAll {
    # Use first input file
    $File = @(Get-ChildItem -Path "$PSScriptRoot\input" -Filter "*.exp" -Recurse | ForEach-Object { $_.FullName }) | Select-Object -First 1

    $Cmd = Resolve-Path -Relative "$PSScriptRoot\..\..\format-code.ps1"
    $TmpFile = $File -Replace "\\input\\", "\tmp\"
    $Expected = Get-Content -Path $File -Raw
}

Describe "Test file - <File>" {
    BeforeEach {
        Copy-Item -Path $File -Destination $TmpFile
    }

    It "Run and check formatter result" {
        PowerShell $Cmd $TmpFile -Dry | Out-Host

        $Result = Get-Content -Path $TmpFile -Raw
        $Result | Should -BeExactly $Expected
    }
}
