param (
    [Parameter(Mandatory)] [string] $File
)

BeforeAll {
    $Cmd = Resolve-Path -Relative "$PSScriptRoot\..\..\format-code.ps1"
    $TmpFile = $File -Replace "\\input\\", "\tmp\"
    $ExpectedFile = $File -Replace "\\input\\", "\expected\"

    $Expected = Get-Content -Path $ExpectedFile -Raw
}

Describe "Test file - <File>" {
    BeforeEach {
        Copy-Item -Path $File -Destination $TmpFile
    }

    It "Formatter result" {
        PowerShell $Cmd $TmpFile | Out-Host

        $Result = Get-Content -Path $TmpFile -Raw
        $Result | Should -BeExactly $Expected
    }
}
