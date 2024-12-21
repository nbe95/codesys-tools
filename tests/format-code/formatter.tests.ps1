param (
    [Parameter(Mandatory)] [string] $File
)

BeforeAll {
    $Root = Resolve-Path -Relative "$PSScriptRoot\..\..\"
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
        Invoke-Expression "$Root\format-code.ps1 $TmpFile"

        $Result = Get-Content -Path $TmpFile -Raw
        $Result | Should -BeExactly $Expected
    }

    It "Don't touch anything when running in dry mode" {
        Invoke-Expression "$Root\format-code.ps1 $TmpFile -Dry"

        $Result = Get-Content -Path $TmpFile -Raw
        $Result | Should -BeExactly $Original
    }
}
