param (
    [Parameter(Mandatory)] [string] $File
)

BeforeAll {
    $Root = Resolve-Path -Relative "$PSScriptRoot\..\..\"
    $Expected = Get-Content -Path ($File -Replace "\\tmp\\", "\\expected\\") -Raw
}

Describe "File - <File>" {
    It "Run and check formatter result" {
        PowerShell -File "$Root\format-code.ps1" $File

        $Result = Get-Content -Path $File -Raw
        $Result | Should -BeExactly $Expected
    }
}
