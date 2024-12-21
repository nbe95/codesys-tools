param (
    [Parameter(Mandatory)] [string] $File
)

BeforeAll {
    $Cmd = Resolve-Path -Relative "$PSScriptRoot\..\..\format-code.ps1"
    $TmpFile = $File -Replace "\\input\\", "\tmp\"
    $ExpectedFile = $File -Replace "\\input\\", "\expected\"

    $Original = Get-Content -Path $File -Raw
    $Expected = Get-Content -Path $ExpectedFile -Raw
}

Describe "Test file - <File>" {
    BeforeEach {
        Copy-Item -Path $File -Destination $TmpFile
    }

    It "Run and check formatter result" {
        PowerShell $Cmd $TmpFile | Out-Host

        $Result = Get-Content -Path $TmpFile -Raw
        $Result | Should -BeExactly $Expected
    }

    It "Don't touch anything when running in dry mode" {
        PowerShell $Cmd $TmpFile -Dry | Out-Host

        $Result = Get-Content -Path $TmpFile -Raw
        $Result | Should -BeExactly $Original
    }
}
